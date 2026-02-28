import Foundation
import AVFoundation
import AudioToolbox

/// Audio engine for playing accordion sounds
class AudioEngine: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var sampler: AVAudioUnitSampler?
    
    @Published var isReady: Bool = false
    
    // Active notes with their velocities
    private var activeNotes: [UInt8: UInt8] = [:]  // note -> velocity
    
    // Accordion MIDI program (General MIDI: 21 = Accordion)
    private let accordionProgram: UInt8 = 21
    
    init() {
        setupAudioEngine()
    }
    
    deinit {
        stop()
    }
    
    private func setupAudioEngine() {
        print("AudioEngine: Setting up...")
        
        audioEngine = AVAudioEngine()
        sampler = AVAudioUnitSampler()
        
        guard let engine = audioEngine, let sampler = sampler else {
            print("AudioEngine: Failed to create audio engine")
            return
        }
        
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        
        do {
            try engine.start()
            print("AudioEngine: Engine started")
            
            // Try multiple SoundFont/DLS paths
            let soundBankPaths = [
                "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls",
                "/Library/Audio/Sounds/Banks/gs_instruments.dls",
                "/System/Library/Sounds/gs_instruments.dls"
            ]
            
            var loaded = false
            for path in soundBankPaths {
                if FileManager.default.fileExists(atPath: path) {
                    print("AudioEngine: Trying to load \(path)")
                    do {
                        try sampler.loadSoundBankInstrument(
                            at: URL(fileURLWithPath: path),
                            program: accordionProgram,
                            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                            bankLSB: UInt8(kAUSampler_DefaultBankLSB)
                        )
                        print("AudioEngine: Loaded sound bank from \(path)")
                        loaded = true
                        break
                    } catch {
                        print("AudioEngine: Failed to load \(path): \(error)")
                    }
                }
            }
            
            if !loaded {
                // Fallback: try loading default preset
                print("AudioEngine: Using default sampler preset")
            }
            
            isReady = true
            print("AudioEngine: Ready! isReady = \(isReady)")
            
            // Test sound
            print("AudioEngine: Playing test note...")
            sampler.startNote(60, withVelocity: 100, onChannel: 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                sampler.stopNote(60, onChannel: 0)
                print("AudioEngine: Test note stopped")
            }
            
        } catch {
            print("AudioEngine: Error starting engine: \(error)")
        }
    }
    
    /// Start playing a note
    func noteOn(_ note: UInt8, velocity: UInt8) {
        print("AudioEngine: noteOn(\(note), velocity: \(velocity)), isReady: \(isReady)")
        guard let sampler = sampler, isReady else {
            print("AudioEngine: Cannot play - sampler nil or not ready")
            return
        }
        
        activeNotes[note] = velocity
        sampler.startNote(note, withVelocity: velocity, onChannel: 0)
        print("AudioEngine: Started note \(note)")
    }
    
    /// Stop playing a note
    func noteOff(_ note: UInt8) {
        guard let sampler = sampler, isReady else { return }
        
        activeNotes.removeValue(forKey: note)
        sampler.stopNote(note, onChannel: 0)
    }
    
    /// Update velocity for all active notes (bellows effect)
    func updateVelocity(_ velocity: UInt8) {
        guard let sampler = sampler, isReady else { return }
        
        // Use MIDI expression (CC 11) to control volume dynamically
        sampler.sendController(11, withValue: velocity, onChannel: 0)
    }
    
    /// Stop all notes
    func allNotesOff() {
        guard let sampler = sampler else { return }
        
        for note in activeNotes.keys {
            sampler.stopNote(note, onChannel: 0)
        }
        activeNotes.removeAll()
    }
    
    /// Set sustain pedal
    func setSustain(_ on: Bool) {
        guard let sampler = sampler else { return }
        sampler.sendController(64, withValue: on ? 127 : 0, onChannel: 0)
    }
    
    func stop() {
        allNotesOff()
        audioEngine?.stop()
    }
    
    /// Get currently active notes
    func getActiveNotes() -> Set<UInt8> {
        return Set(activeNotes.keys)
    }
}
