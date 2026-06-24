import Foundation

/// Monitors the MacBook hinge angle sensor.
/// Falls back to "keyboard-only" mode if the sensor is not available.
///
/// Uses a long-running Python subprocess (`lid_angle_stream.py`) and reads
/// angles line-by-line from its stdout. Detection runs asynchronously so the
/// UI thread is never blocked at launch.
class HingeMonitor: ObservableObject {
    @Published var currentAngle: Double = 90.0
    @Published var angularVelocity: Double = 0
    @Published var isSensorAvailable: Bool = false

    /// Called once detection completes (whether sensor was found or not).
    var onDetectionComplete: ((Bool) -> Void)?

    private var streamProcess: Process?
    private var readSource: DispatchSourceRead?
    private var lineBuffer: String = ""

    // Rolling window of recent (timestamp, angle) samples. Velocity is derived
    // from the difference across the whole window rather than a single delta,
    // which smooths out the lid sensor's coarse angular quantization at 30Hz.
    private var angleHistory: [(time: Date, angle: Double)] = []
    // At 60Hz polling, a 130ms window still holds ~8 samples — enough to
    // suppress angular-quantization jitter while halving the perceived lag.
    private let velocityWindow: TimeInterval = 0.13

    /// Try multiple common Python paths
    private let pythonPaths = [
        "/usr/bin/python3",
        "/usr/local/bin/python3",
        "/opt/homebrew/bin/python3",
        "/usr/local/Caskroom/miniconda/base/bin/python3"
    ]

    private var activePythonPath: String?
    private var hasStartedDetection = false

    init() {
        print("HingeMonitor: Initialized")
    }

    deinit {
        stopMonitoring()
    }

    /// Find a working Python with pybooklid installed. Runs off the main thread
    /// so the app launch isn't blocked by subprocess startup.
    func detectAsync(completion: @escaping (Bool) -> Void) {
        guard !hasStartedDetection else { return }
        hasStartedDetection = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var foundPath: String?
            for path in self.pythonPaths {
                guard FileManager.default.fileExists(atPath: path) else { continue }
                if Self.pythonCanReadLidAngle(path: path) {
                    foundPath = path
                    break
                }
            }

            DispatchQueue.main.async {
                self.activePythonPath = foundPath
                self.isSensorAvailable = (foundPath != nil)
                if let path = foundPath {
                    print("HingeMonitor: Found working Python at \(path)")
                } else {
                    print("HingeMonitor: No hinge sensor available — running in keyboard-only mode")
                }
                completion(self.isSensorAvailable)
            }
        }
    }

    private static func pythonCanReadLidAngle(path: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = ["-c", "from pybooklid import read_lid_angle; print(read_lid_angle())"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    func startMonitoring() {
        guard isSensorAvailable, let pythonPath = activePythonPath else {
            print("HingeMonitor: Skipping — keyboard-only mode active")
            return
        }
        guard streamProcess == nil else { return }

        // Locate the streaming script. Prefer the bundled resource; if it's
        // missing (e.g. during development), fall back to an inline one-liner.
        let scriptArguments: [String]
        if let scriptURL = Bundle.main.url(forResource: "lid_angle_stream", withExtension: "py") {
            scriptArguments = [scriptURL.path]
        } else {
            print("HingeMonitor: lid_angle_stream.py not found in bundle — using inline fallback")
            let inline = """
            import sys, time
            from pybooklid import read_lid_angle
            sys.stdout.reconfigure(line_buffering=True)
            while True:
                try:
                    print(read_lid_angle(), flush=True)
                    time.sleep(1.0/60.0)
                except Exception as e:
                    print(f"ERROR:{e}", flush=True)
                    time.sleep(0.1)
            """
            scriptArguments = ["-c", inline]
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: pythonPath)
        task.arguments = scriptArguments

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            streamProcess = task
            print("HingeMonitor: Started streaming subprocess (\(task.processIdentifier))")
            attachReadSource(to: pipe.fileHandleForReading)
        } catch {
            print("HingeMonitor: Failed to start streaming subprocess: \(error)")
            streamProcess = nil
        }
    }

    func stopMonitoring() {
        readSource?.cancel()
        readSource = nil

        if let task = streamProcess, task.isRunning {
            task.terminate()
        }
        streamProcess = nil
        lineBuffer = ""
        angleHistory.removeAll()
        print("HingeMonitor: Stopped")
    }

    private func attachReadSource(to handle: FileHandle) {
        let fd = handle.fileDescriptor
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .global(qos: .userInteractive))
        source.setEventHandler { [weak self] in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            self?.consumeChunk(chunk)
        }
        source.setCancelHandler {
            try? handle.close()
        }
        source.resume()
        readSource = source
    }

    private func consumeChunk(_ chunk: String) {
        lineBuffer.append(chunk)
        while let newlineRange = lineBuffer.range(of: "\n") {
            let line = String(lineBuffer[..<newlineRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            lineBuffer.removeSubrange(..<newlineRange.upperBound)
            guard !line.isEmpty, !line.hasPrefix("ERROR"), let angle = Double(line) else { continue }
            updateAngle(angle)
        }
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
            if dt > 0.0 {
                velocity = abs(newAngle - oldest.angle) / dt
            } else {
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
