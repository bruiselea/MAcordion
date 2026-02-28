import Foundation

/// Calculates MIDI velocity from hinge angular velocity
class VelocityCalculator {
    // Thresholds for velocity mapping (degrees per second)
    private let minVelocityThreshold: Double = 2.0   // Below this = no sound change
    private let slowThreshold: Double = 5.0          // Slow movement
    private let normalThreshold: Double = 15.0       // Normal movement
    private let fastThreshold: Double = 30.0         // Fast movement
    
    // MIDI velocity ranges
    private let minVelocity: Int = 20
    private let maxVelocity: Int = 127
    
    // Smoothing
    private var smoothedVelocity: Double = 0
    private let smoothingFactor: Double = 0.3
    
    /// Calculate MIDI velocity (0-127) from angular velocity (degrees/second)
    func calculateVelocity(from angularVelocity: Double) -> Int {
        // Apply smoothing
        smoothedVelocity = smoothedVelocity * (1 - smoothingFactor) + angularVelocity * smoothingFactor
        
        // Map angular velocity to MIDI velocity
        let velocity: Int
        
        if smoothedVelocity < minVelocityThreshold {
            // Almost stationary - fade out
            velocity = max(0, Int(Double(minVelocity) * (smoothedVelocity / minVelocityThreshold)))
        } else if smoothedVelocity < slowThreshold {
            // Slow movement: 20-50
            let t = (smoothedVelocity - minVelocityThreshold) / (slowThreshold - minVelocityThreshold)
            velocity = minVelocity + Int(t * 30)
        } else if smoothedVelocity < normalThreshold {
            // Normal movement: 50-90
            let t = (smoothedVelocity - slowThreshold) / (normalThreshold - slowThreshold)
            velocity = 50 + Int(t * 40)
        } else if smoothedVelocity < fastThreshold {
            // Fast movement: 90-120
            let t = (smoothedVelocity - normalThreshold) / (fastThreshold - normalThreshold)
            velocity = 90 + Int(t * 30)
        } else {
            // Very fast: cap at 127
            velocity = maxVelocity
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
