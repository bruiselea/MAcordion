import Foundation
import Combine

/// Physical model of the accordion bellows (air tank)
class BellowsModel: ObservableObject {
    /// Current air pressure in the bellows, from 0.0 (empty) to 1.0 (full)
    @Published var pressure: Double = 0.5
    
    /// Maximum capacity of the bellows
    let maxPressure: Double = 1.0
    
    /// How much pressure is added per unit of hinge velocity
    let fillRate: Double = 0.015
    
    /// How much pressure is consumed per active note per second
    let drainRatePerNote: Double = 0.08
    
    /// How much pressure naturally decays over time (leaks)
    let naturalLeakRate: Double = 0.02
    
    /// Rapid air release rate when the air valve (spacebar) is pressed
    let airValveReleaseRate: Double = 0.8
    
    /// Is the air valve currently open?
    @Published var isAirValveOpen: Bool = false
    
    private var lastUpdateTime: Date = Date()
    
    init() {
        print("BellowsModel: Initialized")
    }
    
    /// Update the internal pressure based on current state
    /// - Parameters:
    ///   - hingeVelocity: The raw angular velocity from the hinge sensor
    ///   - activeNoteCount: The number of notes currently sounding
    func update(hingeVelocity: Double, activeNoteCount: Int) {
        let now = Date()
        let deltaTime = now.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = now
        
        // Prevent huge jumps if app was paused
        guard deltaTime < 0.5 else { return }
        
        var newPressure = pressure
        
        // 1. Add pressure based on hinge movement (pumping the bellows)
        // Even small movements can add pressure if the valve is closed
        let addedPressure = hingeVelocity * fillRate * deltaTime
        newPressure += addedPressure
        
        // 2. Remove pressure due to sounding notes (air escaping through reeds)
        if activeNoteCount > 0 {
            let drainedPressure = Double(activeNoteCount) * drainRatePerNote * deltaTime
            newPressure -= drainedPressure
        } else {
            // Natural slow leak if no notes are played
            newPressure -= naturalLeakRate * deltaTime
        }
        
        // 3. Air valve effect (rapidly releasing or filling air without sound)
        if isAirValveOpen {
            // If we are moving the bellows while the valve is open, 
            // pressure normalizes very quickly towards 0.5 (neutral)
            let diffToNeutral = 0.5 - newPressure
            newPressure += diffToNeutral * airValveReleaseRate * deltaTime
        }
        
        // Clamp to valid range
        self.pressure = max(0.0, min(maxPressure, newPressure))
    }
    
    /// Calculate the effective "expression" or volume based on pressure
    /// - Returns: A value from 0.0 to 1.0 representing how loud it should be
    func currentExpression() -> Double {
        // If the air valve is open, most air escapes through the valve, not the reeds.
        // It drastically reduces volume, but is not an instant mute.
        let valveMultiplier: Double = isAirValveOpen ? 0.2 : 1.0
        
        // If there's no pressure, there's no sound
        if pressure <= 0.05 {
            return 0.0
        }
        
        // Pressure translates to expression/volume.
        // We use a slight curve to make it feel more natural.
        let normalizedPressure = (pressure - 0.05) / 0.95
        return pow(normalizedPressure, 0.7) * valveMultiplier
    }
}
