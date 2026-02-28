import Foundation
import Combine

/// Main ViewModel managing the accordion state and logic
class AccordionViewModel: ObservableObject {
    @Published var appState = AppState()
    
    // Core Engine Components
    let hingeMonitor = HingeMonitor()
    let audioEngine = AudioEngine()
    let midiRecorder = MIDIRecorder()
    let bellowsModel = BellowsModel()
    
    // Helpers
    private let noteMapper = NoteMapper()
    private let velocityCalculator = VelocityCalculator()
    
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
        let expressionNode = bellowsModel.currentExpression()
        let midiVelocity = UInt8(expressionNode * 127)
        
        // Apply parameters to audio engine
        audioEngine.updateVelocity(midiVelocity)
        audioEngine.updateFilter(pressure: appState.pressure)
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
            return
        case 49: // Space (Air Valve)
            appState.isAirValveOpen = true
            return
        case 36: // Enter (Looper Play/Stop)
            if midiRecorder.isPlaying {
                midiRecorder.stopPlayback()
            } else {
                midiRecorder.startPlayback(audioEngine: audioEngine, loop: true)
            }
            return
        default:
            break
        }
        
        // Note keys
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
        
        // Control keys where release doesn't matter much
        if keyCode == 36 { // Enter
            return
        }
        
        // Note release
        if let midiNote = keyCodeToMidiNote(keyCode) {
            let octaveOffset = (appState.currentOctave - 4) * 12
            let note = UInt8(max(0, min(127, Int(midiNote) + octaveOffset)))
            
            if !appState.isSustainOn {
                audioEngine.noteOff(note)
            }
            appState.activeNotes.remove(note)
            updateActiveNoteNames()
        }
    }
    
    // MARK: - Recoding
    
    func toggleRecording() -> URL? {
        if midiRecorder.isRecording {
            midiRecorder.stopRecording()
            appState.isRecording = false
            return midiRecorder.exportToJSON()
        } else {
            midiRecorder.startRecording()
            appState.isRecording = true
            return nil
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
