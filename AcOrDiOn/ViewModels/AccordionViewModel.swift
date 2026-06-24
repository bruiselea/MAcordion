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
    
    // Track keys that are currently physically pressed down, mapped to the
    // MIDI note they triggered at press time. Storing the actual note (not
    // recomputing on release) prevents stuck notes when the octave changes
    // while a key is still held.
    private var pressedKeyToNote: [UInt16: UInt8] = [:]
    
    // Derived UI State
    @Published var activeNoteNames: [String] = []
    
    // Timers
    private var updateTimer: Timer?
    private var hasStarted = false
    private var keyboardOnlyAudioPrimed = false

    // CC11 (expression) smoothing — abrupt drops cause audible clicks/pops as
    // the sampler's amplitude steps. We slew downward changes; attacks remain
    // instant so quick bellows accents stay snappy.
    private var lastMidiVelocity: UInt8 = 0
    private let maxVelocityDropPerFrame: Int = 6  // ≈ 180 units/sec at 30Hz

    // Hysteresis on "bellows stopped" detection — ignore momentary zero
    // crossings during natural bellows reversals.
    private var silenceAccumulator: TimeInterval = 0
    private let silenceReleaseThreshold: TimeInterval = 0.25

    init() {
        print("AccordionViewModel: Initialized")
    }

    deinit {
        stop()
    }

    // MARK: - Lifecycle

    /// Whether hinge sensor is available (keyboard-only mode if false)
    var isKeyboardOnlyMode: Bool {
        return !hingeMonitor.isSensorAvailable
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        print("AccordionViewModel: Starting")

        // Sensor detection runs off the main thread; we begin in keyboard-only
        // mode immediately and switch over if/when a working Python is found.
        hingeMonitor.detectAsync { [weak self] available in
            guard let self = self else { return }
            if available {
                print("AccordionViewModel: Hinge sensor detected — switching to bellows mode")
                self.hingeMonitor.startMonitoring()
            } else {
                print("AccordionViewModel: Keyboard-only mode (no hinge sensor)")
            }
        }

        // Main update loop (30Hz)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.update()
        }
    }
    
    func stop() {
        guard hasStarted else { return }
        hasStarted = false
        print("AccordionViewModel: Stopping")
        updateTimer?.invalidate()
        updateTimer = nil
        hingeMonitor.stopMonitoring()
        audioEngine.stop()
    }
    
    // MARK: - Core Update Loop
    
    private func update() {
        if isKeyboardOnlyMode {
            // Keyboard-only mode: fixed pressure and velocity. Push the static
            // CC11/filter values only once instead of spamming them at 30Hz.
            if !keyboardOnlyAudioPrimed {
                appState.pressure = 0.8
                appState.velocity = 100
                audioEngine.updateVelocity(100)
                audioEngine.updateFilter(pressure: 0.8)
                keyboardOnlyAudioPrimed = true
            }
            return
        } else {
            keyboardOnlyAudioPrimed = false
        }
        
        // --- Hinge sensor mode below ---
        
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
            finalVelocity *= pow(pressureFactor, 0.5) 
        }
        
        let targetVelocity = Int(min(127.0, max(0.0, finalVelocity)))
        let previous = Int(lastMidiVelocity)
        // Slew-limit downward changes only; upward (attack) is instant.
        let smoothedVelocity = targetVelocity < previous
            ? max(targetVelocity, previous - maxVelocityDropPerFrame)
            : targetVelocity
        let midiVelocity = UInt8(smoothedVelocity)
        lastMidiVelocity = midiVelocity

        // Apply parameters to audio engine
        audioEngine.updateVelocity(midiVelocity)
        audioEngine.updateFilter(pressure: appState.pressure)

        // --- Note Release Logic on Hinge Stop ---
        // A real accordion stops making sound when the bellows stop moving.
        // Use hysteresis so that natural bellows reversals (where velocity
        // momentarily crosses zero) don't truncate sustained notes.
        if midiVelocity == 0 {
            silenceAccumulator += 1.0 / 30.0
        } else {
            silenceAccumulator = 0
        }

        if silenceAccumulator >= silenceReleaseThreshold && !appState.isSustainOn {
            let activeMidiNotes = appState.activeNotes
            let heldNotes = Set(pressedKeyToNote.values)
            var notesRemoved = false
            for note in activeMidiNotes where !heldNotes.contains(note) {
                audioEngine.noteOff(note)
                appState.activeNotes.remove(note)
                notesRemoved = true
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
                let heldNotes = Set(pressedKeyToNote.values)
                for note in activeMidiNotes where !heldNotes.contains(note) {
                    audioEngine.noteOff(note)
                    appState.activeNotes.remove(note)
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
        if let midiNote = keyCodeToMidiNote(keyCode) {
            let octaveOffset = (appState.currentOctave - 4) * 12
            let note = UInt8(max(0, min(127, Int(midiNote) + octaveOffset)))
            let midiVelocity: UInt8 = isKeyboardOnlyMode ? 100 : UInt8(bellowsModel.currentExpression() * 127)

            pressedKeyToNote[keyCode] = note
            audioEngine.noteOn(note, velocity: max(midiVelocity, 1))  // Always at least velocity 1
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

        // Note release — use the note recorded at press time so that an
        // octave change while the key is held doesn't leave a stuck note.
        guard let note = pressedKeyToNote.removeValue(forKey: keyCode) else { return }

        if !appState.isSustainOn {
            audioEngine.noteOff(note)
            appState.activeNotes.remove(note)
        }
        updateActiveNoteNames()
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
