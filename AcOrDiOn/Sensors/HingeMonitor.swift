import Foundation
import IOKit.hid

/// Monitors the MacBook hinge angle sensor.
/// Falls back to "keyboard-only" mode if the sensor is not available.
///
/// Uses macOS's native IOHID API directly, so packaged builds do not depend on
/// Python, pybooklid, Homebrew, or a machine-specific interpreter path.
class HingeMonitor: ObservableObject, BellowsSource {
    @Published var currentAngle: Double = 90.0
    @Published var angularVelocity: Double = 0
    @Published var isSensorAvailable: Bool = false

    /// BellowsSource conformance — same value as `angularVelocity`, exposed
    /// under the source-neutral name so the ViewModel can read it without
    /// caring whether the source is a hinge or a microphone.
    var bellowsVelocity: Double { angularVelocity }

    /// Called once detection completes (whether sensor was found or not).
    var onDetectionComplete: ((Bool) -> Void)?

    private var hidManager: IOHIDManager?
    private var hidDevice: IOHIDDevice?
    private var pollingTimer: DispatchSourceTimer?

    // Rolling window of recent (timestamp, angle) samples. Velocity is derived
    // from the difference across the whole window rather than a single delta,
    // which smooths out the lid sensor's coarse angular quantization at 30Hz.
    private var angleHistory: [(time: Date, angle: Double)] = []
    // At 60Hz polling, a 130ms window still holds ~8 samples — enough to
    // suppress angular-quantization jitter while halving the perceived lag.
    private let velocityWindow: TimeInterval = 0.13

    // Hard deadzone: if the lid angle barely changed across the window, the
    // "velocity" we see is sensor quantisation noise. Below this it's forced
    // to zero so a stationary lid produces zero output, not a phantom hum.
    private let angleDeadzoneDegrees: Double = 1.5

    private var hasStartedDetection = false

    init() {
        print("HingeMonitor: Initialized")
    }

    deinit {
        stopMonitoring()
    }

    /// Detect the built-in lid-angle HID device off the main thread so app
    /// launch is never blocked by hardware discovery.
    func detectAsync(completion: @escaping (Bool) -> Void) {
        guard !hasStartedDetection else { return }
        hasStartedDetection = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // macOS may keep the HID device busy for a short time after a
            // previous app instance exits. Retry briefly so a quick relaunch
            // does not incorrectly fall back to keyboard-only mode.
            var connection: (manager: IOHIDManager, device: IOHIDDevice)?
            for _ in 0..<12 {
                connection = Self.connectToLidSensor()
                if connection != nil { break }
                Thread.sleep(forTimeInterval: 0.25)
            }

            DispatchQueue.main.async {
                self.hidManager = connection?.manager
                self.hidDevice = connection?.device
                self.isSensorAvailable = (connection != nil)
                if connection != nil {
                    print("HingeMonitor: Found native IOHID lid-angle sensor")
                } else {
                    print("HingeMonitor: No hinge sensor available — running in keyboard-only mode")
                }
                completion(self.isSensorAvailable)
            }
        }
    }

    private static func connectToLidSensor() -> (manager: IOHIDManager, device: IOHIDDevice)? {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        // Match the Sensor usage directly instead of pinning a product ID.
        // Apple has shipped the same lid-angle sensor usage behind different
        // internal product IDs, so the narrower match could fail after a
        // relaunch or on another supported MacBook model.
        let matching: [String: Any] = [
            kIOHIDDeviceUsagePageKey as String: 0x0020,
            kIOHIDDeviceUsageKey as String: 0x008A
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess,
              let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            return nil
        }

        for device in devices {
            guard IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
                continue
            }
            if readAngle(from: device) != nil {
                return (manager, device)
            }
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }

        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        return nil
    }

    private static func readAngle(from device: IOHIDDevice) -> Double? {
        var report = [UInt8](repeating: 0, count: 8)
        var reportLength = report.count
        let result = report.withUnsafeMutableBufferPointer { buffer in
            IOHIDDeviceGetReport(
                device,
                kIOHIDReportTypeFeature,
                CFIndex(1),
                buffer.baseAddress!,
                &reportLength
            )
        }
        guard result == kIOReturnSuccess, reportLength >= 3 else { return nil }
        let rawAngle = (UInt16(report[2]) << 8) | UInt16(report[1])
        return Double(rawAngle)
    }

    func startMonitoring() {
        guard isSensorAvailable, let device = hidDevice else {
            print("HingeMonitor: Skipping — keyboard-only mode active")
            return
        }
        guard pollingTimer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        timer.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in
            guard let self, let angle = Self.readAngle(from: device) else { return }
            self.updateAngle(angle)
        }
        timer.resume()
        pollingTimer = timer
        print("HingeMonitor: Started native IOHID polling")
    }

    func stopMonitoring() {
        pollingTimer?.cancel()
        pollingTimer = nil
        if let device = hidDevice {
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        if let manager = hidManager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        hidDevice = nil
        hidManager = nil
        angleHistory.removeAll()
        print("HingeMonitor: Stopped")
    }

    private func updateAngle(_ newAngle: Double) {
        let now = Date()

        // Append, then drop entries older than the velocity window.
        angleHistory.append((now, newAngle))
        let cutoff = now.addingTimeInterval(-velocityWindow)
        while let first = angleHistory.first, first.time < cutoff {
            angleHistory.removeFirst()
        }

        // Compute velocity across the window (oldest → newest). This is
        // resilient to lid-sensor angle quantization: even when individual
        // 33ms samples report 0° change, the cumulative drift over ~150ms
        // gives a meaningful, continuous speed estimate.
        let velocity: Double
        if let oldest = angleHistory.first {
            let dt = now.timeIntervalSince(oldest.time)
            let delta = abs(newAngle - oldest.angle)
            if dt > 0.0 && delta >= angleDeadzoneDegrees {
                velocity = delta / dt
            } else {
                // Below deadzone → treat as truly stationary, not just slow.
                velocity = 0
            }
        } else {
            velocity = 0
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentAngle = newAngle
            // EWMA — at 60Hz the time constant is roughly 1/(60*0.28) ≈ 60ms.
            self.angularVelocity = self.angularVelocity * 0.72 + velocity * 0.28
        }
    }
}
