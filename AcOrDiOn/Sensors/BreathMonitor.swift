import Foundation
import AVFoundation
import Combine

/// Microphone-driven bellows source. Treats your breath as the air pump,
/// so MAcordion behaves like a melodica/pianica instead of an accordion.
///
/// We tap the default input device, compute a smoothed RMS amplitude per
/// audio buffer, and map that into the same "deg/sec equivalent" scale
/// that `HingeMonitor.angularVelocity` lives in. That means the existing
/// `VelocityCalculator` thresholds (1–220) work without modification.
final class BreathMonitor: ObservableObject, BellowsSource {
    @Published var angularVelocity: Double = 0      // exposed for compatibility/UI
    @Published var isSensorAvailable: Bool = false

    var bellowsVelocity: Double { angularVelocity }

    private let inputEngine = AVAudioEngine()
    private var isTapInstalled = false
    private var hasStartedDetection = false

    // RMS → bellowsVelocity mapping.
    //
    // - `noiseFloor`: typical room noise sits around 0.002–0.01 RMS. Anything
    //   below this counts as silence, not "very gentle blowing".
    // - `gain`: scale so a firm blow (~RMS 0.18) maps to the high end of the
    //   VelocityCalculator range (~220).
    private let noiseFloor: Float = 0.012
    private let gain: Double = 1400

    // EWMA smoothing on the velocity stream. Mic RMS jumps frame-to-frame
    // even at constant breath; a light smoothing tames that without adding
    // perceptible lag.
    private let smoothingAlpha: Double = 0.35

    init() {
        print("BreathMonitor: Initialized")
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - BellowsSource

    func detectAsync(completion: @escaping (Bool) -> Void) {
        guard !hasStartedDetection else { return }
        hasStartedDetection = true

        // Mic permission is asked on first tap install. We optimistically
        // claim availability — if installation fails later, we flip back
        // to false and the ViewModel falls into keyboard-only mode.
        DispatchQueue.main.async {
            self.isSensorAvailable = true
            completion(true)
        }
    }

    func startMonitoring() {
        guard !isTapInstalled else { return }

        let input = inputEngine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            print("BreathMonitor: Input format unavailable — falling back to keyboard-only")
            DispatchQueue.main.async { self.isSensorAvailable = false }
            return
        }

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }
        isTapInstalled = true

        do {
            try inputEngine.start()
            print("BreathMonitor: Started microphone tap (sr \(format.sampleRate))")
        } catch {
            print("BreathMonitor: Failed to start input engine: \(error)")
            input.removeTap(onBus: 0)
            isTapInstalled = false
            DispatchQueue.main.async { self.isSensorAvailable = false }
        }
    }

    func stopMonitoring() {
        if isTapInstalled {
            inputEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        if inputEngine.isRunning {
            inputEngine.stop()
        }
        print("BreathMonitor: Stopped")
    }

    // MARK: - DSP

    private func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?.pointee else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        var sumSquares: Float = 0
        for i in 0..<frameLength {
            let s = channelData[i]
            sumSquares += s * s
        }
        let rms = sqrtf(sumSquares / Float(frameLength))

        // Subtract noise floor, clip to zero. Anything quieter than ambient
        // room noise becomes "no breath", which keeps the bellows from
        // humming when nothing is actually blowing.
        let aboveFloor = max(0, Double(rms - noiseFloor))
        let target = aboveFloor * gain

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.angularVelocity = self.angularVelocity * (1 - self.smoothingAlpha)
                + target * self.smoothingAlpha
        }
    }
}
