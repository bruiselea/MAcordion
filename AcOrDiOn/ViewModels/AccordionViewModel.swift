import Foundation
import Combine

/// Main ViewModel managing the accordion state and logic
class AccordionViewModel: ObservableObject {
    @Published var appState = AppState()
    
    // Core Engine Components
    let hingeMonitor = HingeMonitor()
    let audioEngine = AudioEngine()
    let bellowsModel = BellowsModel()
    
    // Helpers
    private let noteMapper = NoteMapper()
    private let velocityCalculator = VelocityCalculator()
    
    // Track keys that are currently physically pressed down
    private var physicallyPressedKeys: Set<UInt16> = []
    
    // Derived UI State
    @Published var activeNoteNames: [String] = []
    
    // Timers
    private var updateTimer: Timer?
    
    init() {
        print("AccordionViewModel: Initialized")
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Lifecycle
    
    func start() {
        print("AccordionViewModel: Starting")
        hingeMonitor.startMonitoring()
        
        // Main update loop (30Hz)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.update()
        }
    }
    
    func stop() {
        print("AccordionViewModel: Stopping")
        updateTimer?.invalidate()
        updateTimer = nil
        hingeMonitor.stopMonitoring()
        audioEngine.stop()
    }
    
    // MARK: - Core Update Loop
    
    private func update() {
        // Update raw sensor data to state
        appState.currentAngle = hingeMonitor.currentAngle
        
        let velocity = velocityCalculator.calculateVelocity(from: hingeMonitor.angularVelocity)
        appState.velocity = velocity
        
        // Update physical model based on sensor and user input
        bellowsModel.isAirValveOpen = appState.isAirValveOpen
        bellowsModel.update(hingeVelocity: Double(velocity), activeNoteCount: appState.activeNotes.count)
        
        // Export physical state back to UI
        appState.pressure = bellowsModel.pressure
        
        // Calculate final audio parameters
        // The user specifically wants volume to depend on the *amount of angle change* (velocity).
        // Sound should stop if the angle is not changing (velocity == 0).
        var finalVelocity = Double(velocity)
        
        // Air valve reduces volume drastically but is not an instant mute
        if appState.isAirValveOpen {
            finalVelocity *= 0.2
        }
        
        // Actual air pressure also limits the maximum possible volume
        if bellowsModel.pressure <= 0.05 {
            finalVelocity = 0
        } else {
            let pressureFactor = (bellowsModel.pressure - 0.05) / 0.95
            // Soft curve so it remains audible until pressure is quite low
            finalVelocity *= pow(pressureFactor, 0.5) 
        }
        
        let midiVelocity = UInt8(min(127.0, max(0.0, finalVelocity)))
        
        // Apply parameters to audio engine
        audioEngine.updateVelocity(midiVelocity)
        audioEngine.updateFilter(pressure: appState.pressure)
        
        // --- Note Release Logic on Hinge Stop ---
        // A real accordion stops making sound immediately when the bellows stop moving.
        // If our velocity dropped to 0, and sustain is OFF, we should release all notes
        // that are not physically held down, and even if they are held down, 
        // the 0 velocity will silence them anyway. 
        if midiVelocity == 0 && !appState.isSustainOn {
            let activeMidiNotes = appState.activeNotes
            var notesRemoved = false
            for note in activeMidiNotes {
                // If the key is not physically held, release it entirely from the engine
                let isHeld = physicallyPressedKeys.contains(where: { 
                    if let mapped = keyCodeToMidiNote($0) {
                        let octaveOffset = (appState.currentOctave - 4) * 12
                        let fullNote = UInt8(max(0, min(127, Int(mapped) + octaveOffset)))
                        return fullNote == note
                    }
                    return false
                })
                
                if !isHeld {
                    audioEngine.noteOff(note)
                    appState.activeNotes.remove(note)
                    notesRemoved = true
                }
            }
            if notesRemoved {
                updateActiveNoteNames()
            }
        }
    }
    
    // MARK: - Key Handling
    
    func handleKeyDown(_ keyCode: UInt16) {
        // Control keys
        switch keyCode {
        case 6: // Z (Octave down)
            if appState.currentOctave > 0 { appState.currentOctave -= 1 }
            return
        case 7: // X (Octave up)
            if appState.currentOctave < 8 { appState.currentOctave += 1 }
            return
        case 48: // Tab (Sustain)
            appState.isSustainOn.toggle()
            audioEngine.setSustain(appState.isSustainOn)
            
            // If sustain was just turned off, we need to release any notes 
            // that are ringing but whose keys are no longer physically held down.
            if !appState.isSustainOn {
                let activeMidiNotes = appState.activeNotes
                for note in activeMidiNotes {
                    // Check if this MIDI note corresponds to any currently held key
                    let isHeld = physicallyPressedKeys.contains(where: { keyCodeToMidiNote($0) == note })
                    if !isHeld {
                        audioEngine.noteOff(note)
                        appState.activeNotes.remove(note)
                    }
                }
                updateActiveNoteNames()
            }
            return
        case 49: // Space (Air Valve)
            appState.isAirValveOpen = true
            return
        default:
            break
        }
        
        // Note keys
        physicallyPressedKeys.insert(keyCode)
        
        if let midiNote = keyCodeToMidiNote(keyCode) {
            let octaveOffset = (appState.currentOctave - 4) * 12
            let note = UInt8(max(0, min(127, Int(midiNote) + octaveOffset)))
            let midiVelocity = UInt8(bellowsModel.currentExpression() * 127)
            
            audioEngine.noteOn(note, velocity: midiVelocity)
            appState.activeNotes.insert(note)
            updateActiveNoteNames()
        }
    }
    
    func handleKeyUp(_ keyCode: UInt16) {
        // Air valve release
        if keyCode == 49 { // Space
            appState.isAirValveOpen = false
            return
        }
        
        // Note release
        physicallyPressedKeys.remove(keyCode)
        
        if let midiNote = keyCodeToMidiNote(keyCode) {
            let octaveOffset = (appState.currentOctave - 4) * 12
            let note = UInt8(max(0, min(127, Int(midiNote) + octaveOffset)))
            
            if !appState.isSustainOn {
                audioEngine.noteOff(note)
                appState.activeNotes.remove(note)
            }
            updateActiveNoteNames()
        }
    }
    
    // MARK: - Private Helpers
    
    private func keyCodeToMidiNote(_ keyCode: UInt16) -> UInt8? {
        let mapping: [UInt16: UInt8] = [
            0: 60, 1: 62, 2: 64, 3: 65, 5: 67, 4: 69, 38: 71, 40: 72, 37: 74, 41: 76,
            13: 61, 14: 63, 17: 66, 16: 68, 32: 70, 31: 73, 35: 75
        ]
        return mapping[keyCode]
    }
    
    private func updateActiveNoteNames() {
        activeNoteNames = appState.activeNotes.sorted().map { noteMapper.noteName(for: $0) }
    }
}
