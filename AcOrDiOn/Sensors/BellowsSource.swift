import Foundation

/// Abstract source of "bellows motion" for the accordion engine.
///
/// The Hinge version of MAcordion derives this from the MacBook lid sensor;
/// the Breath version derives it from microphone amplitude. Both feed the
/// same VelocityCalculator scale (deg/sec equivalent) so the rest of the
/// audio pipeline does not need to know which physical source produced it.
public protocol BellowsSource: AnyObject {
    /// Current bellows speed, in the same units VelocityCalculator expects
    /// (roughly 0–250, calibrated against HingeMonitor's deg/sec).
    var bellowsVelocity: Double { get }

    /// If a source produces a clean 0–1 normalised pressure/intensity signal
    /// (e.g. shisha differential pressure sensor), it can publish that here
    /// and the ViewModel will use it directly as expression/volume, bypassing
    /// the simulated bellows pressure model. Sources without a direct signal
    /// return nil (default) and the BellowsModel pipeline is used instead.
    var directExpression: Double? { get }

    /// Whether the physical source is usable. False puts the app in
    /// keyboard-only mode (fixed pressure/velocity).
    var isSensorAvailable: Bool { get }

    /// Run any required out-of-band detection (e.g. probing for Python,
    /// asking for mic permission). Invokes `completion` on the main thread.
    func detectAsync(completion: @escaping (Bool) -> Void)

    /// Begin streaming data into `bellowsVelocity`.
    func startMonitoring()

    /// Stop streaming and release resources.
    func stopMonitoring()
}

public extension BellowsSource {
    var directExpression: Double? { nil }
}
