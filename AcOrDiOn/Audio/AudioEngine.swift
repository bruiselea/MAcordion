import Foundation
import AVFoundation
import AudioToolbox

/// Audio engine for playing accordion sounds.
///
/// Uses a self-contained additive synth (two detuned sawtooth oscillators
/// per voice with an AR envelope) routed through a low-pass filter. This
/// avoids depending on macOS's `gs_instruments.dls` General MIDI bank,
/// which has been removed from recent macOS versions and was causing
/// silent playback on those systems.
class AudioEngine: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var eqFilter: AVAudioUnitEQ?

    @Published var isReady: Bool = false

    // MARK: - Synth State

    private struct Voice {
        var note: UInt8
        var velocity: Float        // 0…1, scaled from MIDI velocity
        var freq1: Float
        var freq2: Float           // detuned for chorus/beating
        var phase1: Float = 0
        var phase2: Float = 0
        var envelope: Float = 0    // current amplitude 0…1
        var isReleasing: Bool = false
        var sustainedAfterKeyUp: Bool = false
    }

    private var voices: [UInt8: Voice] = [:]
    private var expressionLevel: Float = 1.0
    private var sustainPedalDown: Bool = false
    private let stateLock = NSLock()

    private var sampleRate: Float = 44100

    // Envelope rates per second (higher = faster).
    private let attackPerSec: Float = 35    // ~28ms 0→1
    private let releasePerSec: Float = 9    // ~110ms 1→0
    private let masterGain: Float = 0.26    // headroom for polyphony

    init() {
        setupAudioEngine()
    }

    deinit {
        stop()
    }

    private func setupAudioEngine() {
        print("AudioEngine: Setting up additive synth")

        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }

        let mainMixer = engine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)
        sampleRate = Float(outputFormat.sampleRate)

        // Low-pass filter, frequency driven by bellows pressure.
        eqFilter = AVAudioUnitEQ(numberOfBands: 1)
        guard let eq = eqFilter else { return }
        let band = eq.bands[0]
        band.filterType = .lowPass
        band.frequency = 20000
        band.bandwidth = 1.0
        band.bypass = false
        eq.globalGain = 12.0

        // Custom render block — generates audio entirely in-process.
        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, abl -> OSStatus in
            guard let self = self else { return noErr }
            return self.renderAudio(frameCount: frameCount, abl: abl)
        }
        guard let source = sourceNode else { return }

        engine.attach(source)
        engine.attach(eq)
        engine.connect(source, to: eq, format: outputFormat)
        engine.connect(eq, to: mainMixer, format: outputFormat)
        mainMixer.outputVolume = 1.0

        do {
            try engine.start()
            isReady = true
            print("AudioEngine: Ready (sample rate \(sampleRate))")
        } catch {
            print("AudioEngine: Error starting engine: \(error)")
        }
    }

    // MARK: - Audio Render

    private func renderAudio(frameCount: AVAudioFrameCount, abl: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        // Snapshot voice state under lock; render off-lock to minimise contention.
        stateLock.lock()
        var voiceList = Array(voices.values)
        let expression = expressionLevel
        stateLock.unlock()

        let ablPointer = UnsafeMutableAudioBufferListPointer(abl)
        let frames = Int(frameCount)
        let sr = sampleRate
        let attackInc = attackPerSec / sr
        let releaseInc = releasePerSec / sr
        let twoPi: Float = 2.0 * .pi

        // Render mono mix into first buffer, then copy to others (stereo).
        guard let firstBuffer = ablPointer.first,
              let firstPtr = firstBuffer.mData?.assumingMemoryBound(to: Float.self) else {
            return noErr
        }

        for f in 0..<frames {
            var sample: Float = 0

            for i in 0..<voiceList.count {
                var v = voiceList[i]

                // Envelope update
                if v.isReleasing {
                    v.envelope = max(0, v.envelope - releaseInc)
                } else {
                    v.envelope = min(1.0, v.envelope + attackInc)
                }

                if v.envelope > 0.0001 {
                    // Two detuned sawtooth oscillators for accordion-like beating.
                    let saw1 = (v.phase1 / .pi) - 1.0
                    let saw2 = (v.phase2 / .pi) - 1.0
                    sample += (saw1 + saw2) * 0.5 * v.envelope * v.velocity
                }

                v.phase1 += twoPi * v.freq1 / sr
                if v.phase1 >= twoPi { v.phase1 -= twoPi }
                v.phase2 += twoPi * v.freq2 / sr
                if v.phase2 >= twoPi { v.phase2 -= twoPi }

                voiceList[i] = v
            }

            firstPtr[f] = sample * expression * masterGain
        }

        // Copy to additional channels (e.g. stereo right).
        for ch in 1..<ablPointer.count {
            let buf = ablPointer[ch]
            if let dst = buf.mData?.assumingMemoryBound(to: Float.self) {
                memcpy(dst, firstPtr, frames * MemoryLayout<Float>.size)
            }
        }

        // Commit updated phases/envelopes; drop dead voices.
        //
        // Only adopt the render-owned fields (phase + envelope) from the
        // snapshot. Control flags (isReleasing, velocity, sustain) may have
        // been changed on the main thread while we were rendering off-lock —
        // writing back the whole stale snapshot would clobber a concurrent
        // noteOn/noteOff and leave a note stuck (the "sometimes residual
        // sound" bug).
        stateLock.lock()
        for v in voiceList {
            guard var current = voices[v.note] else { continue }
            current.phase1 = v.phase1
            current.phase2 = v.phase2
            current.envelope = v.envelope
            if current.isReleasing && current.envelope <= 0.0001 {
                voices.removeValue(forKey: v.note)
            } else {
                voices[v.note] = current
            }
        }
        stateLock.unlock()

        return noErr
    }

    // MARK: - MIDI-like API

    /// Start playing a note
    func noteOn(_ note: UInt8, velocity: UInt8) {
        guard isReady else { return }
        let freq = AudioEngine.midiToFrequency(note)
        let velScaled = Float(max(velocity, 1)) / 127.0

        stateLock.lock()
        var voice = voices[note] ?? Voice(
            note: note,
            velocity: velScaled,
            freq1: freq * 0.9985,    // -2.6 cents
            freq2: freq * 1.0015     // +2.6 cents
        )
        voice.velocity = velScaled
        voice.isReleasing = false
        voice.sustainedAfterKeyUp = false
        voices[note] = voice
        stateLock.unlock()
    }

    /// Stop playing a note
    func noteOff(_ note: UInt8) {
        guard isReady else { return }
        stateLock.lock()
        if var v = voices[note] {
            if sustainPedalDown {
                v.sustainedAfterKeyUp = true
            } else {
                v.isReleasing = true
            }
            voices[note] = v
        }
        stateLock.unlock()
    }

    /// Update expression (CC11) for all active notes
    func updateVelocity(_ velocity: UInt8) {
        let level = Float(velocity) / 127.0
        stateLock.lock()
        expressionLevel = level
        stateLock.unlock()
    }

    /// Update filter cutoff frequency based on bellows pressure (0…1)
    func updateFilter(pressure: Double) {
        guard let eq = eqFilter else { return }
        let minFreq: Double = 400.0
        let maxFreq: Double = 10000.0
        let logMin = log(minFreq)
        let logMax = log(maxFreq)
        let targetLog = logMin + (logMax - logMin) * pressure
        eq.bands[0].frequency = Float(exp(targetLog))
    }

    /// Stop all notes
    func allNotesOff() {
        stateLock.lock()
        for (note, var v) in voices {
            v.isReleasing = true
            voices[note] = v
        }
        stateLock.unlock()
    }

    /// Sustain pedal (CC64)
    func setSustain(_ on: Bool) {
        stateLock.lock()
        sustainPedalDown = on
        if !on {
            for (note, var v) in voices where v.sustainedAfterKeyUp {
                v.isReleasing = true
                v.sustainedAfterKeyUp = false
                voices[note] = v
            }
        }
        stateLock.unlock()
    }

    func stop() {
        allNotesOff()
        audioEngine?.stop()
    }

    /// Get currently active (non-released) notes
    func getActiveNotes() -> Set<UInt8> {
        stateLock.lock()
        let notes = Set(voices.compactMap { $0.value.isReleasing ? nil : $0.key })
        stateLock.unlock()
        return notes
    }

    // MARK: - Helpers

    private static func midiToFrequency(_ note: UInt8) -> Float {
        return 440.0 * pow(2.0, (Float(note) - 69.0) / 12.0)
    }
}
