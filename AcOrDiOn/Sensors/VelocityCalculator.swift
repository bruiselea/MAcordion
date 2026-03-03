import Foundation

/// Calculates MIDI velocity from hinge angular velocity
class VelocityCalculator {
    // Thresholds for velocity mapping (degrees per second)
    private let minVelocityThreshold: Double = 1.0   // Smooth start
    private let maxVelocityThreshold: Double = 120.0 // Requires much faster, larger movements to reach max volume
    
    // MIDI velocity ranges
    private let minVelocity: Int = 20
    private let maxVelocity: Int = 127
    
    // Smoothing
    private var smoothedVelocity: Double = 0
    private let smoothingFactor: Double = 0.4 // Slightly faster response
    
    /// Calculate MIDI velocity (0-127) from angular velocity (degrees/second)
    func calculateVelocity(from angularVelocity: Double) -> Int {
        // Apply smoothing
        smoothedVelocity = smoothedVelocity * (1 - smoothingFactor) + angularVelocity * smoothingFactor
        
        // Map angular velocity to MIDI velocity using an accordion-like non-linear curve
        let velocity: Int
        
        if smoothedVelocity < minVelocityThreshold {
            // Almost stationary - rapid fade out to 0
            velocity = max(0, Int(Double(minVelocity) * (smoothedVelocity / minVelocityThreshold)))
        } else {
            // Normalize movement speed between 0.0 and 1.0
            let normalizedSpeed = min(1.0, (smoothedVelocity - minVelocityThreshold) / (maxVelocityThreshold - minVelocityThreshold))
            
            // Apply an exponential curve (pow 1.2). This keeps the volume lower at slow-to-medium
            // speeds, requiring a genuinely fast and large movement to hit the maximum MIDI velocity.
            let curve = pow(normalizedSpeed, 1.2)
            
            velocity = minVelocity + Int(curve * Double(maxVelocity - minVelocity))
        }
        
        return min(maxVelocity, max(0, velocity))
    }
    
    /// Check if hinge is moving enough to produce sound
    func isActive(angularVelocity: Double) -> Bool {
        return angularVelocity >= minVelocityThreshold
    }
    
    func reset() {
        smoothedVelocity = 0
    }
}
