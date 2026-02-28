import AVFoundation
import Accelerate

/// Real-time accordion synthesizer using AVAudioSourceNode
class AccordionSynth: ObservableObject {
    static let shared = AccordionSynth()
    
    private let engine = AVAudioEngine()
    private var sourceNodes: [UInt8: AVAudioSourceNode] = [:]
    private var activeNotes: Set<UInt8> = []
    
    @Published var volume: Double = 0.5
    
    private let sampleRate: Double = 44100
    private var phases: [UInt8: Double] = [:]
    
    // Musette tuning (detuned reeds)
    private let detuneSharp = 1.006
    private let detuneFlat = 0.994
    
    private init() {
        setupEngine()
    }
    
    private func setupEngine() {
        let mainMixer = engine.mainMixerNode
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        
        engine.connect(mainMixer, to: engine.outputNode, format: format)
        
        do {
            try engine.start()
            print("AccordionSynth: Engine started")
        } catch {
            print("AccordionSynth: Failed to start engine: \(error)")
        }
    }
    
    func noteOn(_ note: UInt8) {
        guard !activeNotes.contains(note) else { return }
        activeNotes.insert(note)
        phases[note] = 0.0
        
        let frequency = midiToFrequency(note)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        
        let sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let vol = Float(self.volume)
            
            for frame in 0..<Int(frameCount) {
                let phase = self.phases[note] ?? 0
                
                // Generate accordion-like waveform
                var sample: Float = 0
                
                // Main reed with harmonics (sawtooth-like)
                for h in 1...8 {
                    let amp = Float(0.4 / Double(h))
                    sample += amp * sin(Float(phase * Double(h)))
                }
                
                // Detuned reeds for musette effect
                sample += 0.3 * sin(Float(phase * self.detuneSharp))
                sample += 0.3 * sin(Float(phase * self.detuneFlat))
                
                // Apply volume
                sample *= vol * 0.3
                
                // Write to both channels
                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = sample
                }
                
                // Update phase
                let phaseIncrement = 2.0 * .pi * frequency / self.sampleRate
                self.phases[note] = (phase + phaseIncrement).truncatingRemainder(dividingBy: 2.0 * .pi)
            }
            
            return noErr
        }
        
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        sourceNodes[note] = sourceNode
    }
    
    func noteOff(_ note: UInt8) {
        guard activeNotes.contains(note) else { return }
        activeNotes.remove(note)
        
        if let node = sourceNodes[note] {
            engine.disconnectNodeOutput(node)
            engine.detach(node)
            sourceNodes.removeValue(forKey: note)
        }
        phases.removeValue(forKey: note)
    }
    
    func allNotesOff() {
        for note in activeNotes {
            noteOff(note)
        }
    }
    
    func updateVolume(_ vol: Double) {
        volume = max(0.0, min(1.0, vol))
    }
    
    func stop() {
        allNotesOff()
        engine.stop()
    }
    
    private func midiToFrequency(_ note: UInt8) -> Double {
        return 440.0 * pow(2.0, (Double(note) - 69.0) / 12.0)
    }
}
