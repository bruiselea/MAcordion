import Foundation
import AVFoundation
import AudioToolbox

/// Audio engine for playing accordion sounds
class AudioEngine: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var sampler: AVAudioUnitSampler?
    private var eqFilter: AVAudioUnitEQ?
    
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
        eqFilter = AVAudioUnitEQ(numberOfBands: 1)
        
        guard let engine = audioEngine, let sampler = sampler, let eq = eqFilter else {
            print("AudioEngine: Failed to create audio engine components")
            return
        }
        
        // Setup Lowpass filter
        let filterParams = eq.bands[0]
        filterParams.filterType = .lowPass
        filterParams.frequency = 20000.0 // Start wide open
        filterParams.bandwidth = 1.0     // 1 octave
        filterParams.bypass = false
        
        // Boost overall volume significantly (+24dB on the EQ side)
        eq.globalGain = 24.0
        
        engine.attach(sampler)
        engine.attach(eq)
        
        // Connect nodes: Sampler -> EQ -> MainMixer
        engine.connect(sampler, to: eq, format: nil)
        engine.connect(eq, to: engine.mainMixerNode, format: nil)
        
        // Also boost the final output mixer volume (default is 1.0)
        engine.mainMixerNode.outputVolume = 2.0
        
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
            
            // Test sound removed for release
            
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
    
    /// Update filter cutoff frequency based on bellows pressure
    /// - Parameter pressure: 0.0 to 1.0
    func updateFilter(pressure: Double) {
        guard let eqFilter = eqFilter else { return }
        
        // Map pressure to frequency (Logarithmic scale works best for audio)
        // 0.0 pressure = 400Hz (very muffled)
        // 1.0 pressure = 8000+ Hz (bright and reedy)
        let minFreq: Double = 400.0
        let maxFreq: Double = 10000.0
        
        // Logarithmic interpolation
        let logMin = log(minFreq)
        let logMax = log(maxFreq)
        let targetLog = logMin + (logMax - logMin) * pressure
        let currentFreq = exp(targetLog)
        
        eqFilter.bands[0].frequency = Float(currentFreq)
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
