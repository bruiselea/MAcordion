import Foundation

/// Hinge-driven source of bellows motion for the accordion engine.
public protocol BellowsSource: AnyObject {
    /// Current bellows speed, in the same units VelocityCalculator expects
    /// (roughly 0–250, calibrated against HingeMonitor's deg/sec).
    var bellowsVelocity: Double { get }

    /// Whether the physical source is usable. False puts the app in
    /// keyboard-only mode (fixed pressure/velocity).
    var isSensorAvailable: Bool { get }

    /// Detect the built-in hinge sensor. Invokes `completion` on the main thread.
    func detectAsync(completion: @escaping (Bool) -> Void)

    /// Begin streaming data into `bellowsVelocity`.
    func startMonitoring()

    /// Stop streaming and release resources.
    func stopMonitoring()
}
