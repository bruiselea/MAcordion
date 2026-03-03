import Foundation
import AVFoundation

/// Records MIDI events for playback/export
class MIDIRecorder: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var isPlaying: Bool = false
    @Published var recordedEvents: [MIDIEvent] = []
    
    // Playback loop configuration
    @Published var isLooping: Bool = false
    
    private var startTime: Date?
    private var playbackTimer: Timer?
    private var currentEventIndex: Int = 0
    
    struct MIDIEvent: Codable {
        let timestamp: TimeInterval  // seconds from start
        let type: EventType
        let note: UInt8
        let velocity: UInt8
        
        enum EventType: String, Codable {
            case noteOn
            case noteOff
        }
    }
    
    func startRecording() {
        recordedEvents.removeAll()
        startTime = Date()
        isRecording = true
    }
    
    func stopRecording() {
        isRecording = false
        startTime = nil
    }
    
    func recordNoteOn(_ note: UInt8, velocity: UInt8) {
        guard isRecording, let start = startTime else { return }
        
        let event = MIDIEvent(
            timestamp: Date().timeIntervalSince(start),
            type: .noteOn,
            note: note,
            velocity: velocity
        )
        recordedEvents.append(event)
    }
    
    func recordNoteOff(_ note: UInt8) {
        guard isRecording, let start = startTime else { return }
        
        let event = MIDIEvent(
            timestamp: Date().timeIntervalSince(start),
            type: .noteOff,
            note: note,
            velocity: 0
        )
        recordedEvents.append(event)
    }
    
    // MARK: - Playback
    
    func startPlayback(audioEngine: AudioEngine, loop: Bool = true) {
        guard !recordedEvents.isEmpty else { return }
        
        stopPlayback() // Reset any existing playback
        
        isPlaying = true
        isLooping = loop
        currentEventIndex = 0
        startTime = Date()
        
        // Start high-precision playback timer
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            self?.processPlayback(audioEngine: audioEngine)
        }
    }
    
    func stopPlayback() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func processPlayback(audioEngine: AudioEngine) {
        guard isPlaying, let start = startTime, !recordedEvents.isEmpty else { return }
        
        let currentTime = Date().timeIntervalSince(start)
        
        // Play events that should have occurred by now
        while currentEventIndex < recordedEvents.count && recordedEvents[currentEventIndex].timestamp <= currentTime {
            let event = recordedEvents[currentEventIndex]
            
            switch event.type {
            case .noteOn:
                audioEngine.noteOn(event.note, velocity: event.velocity)
            case .noteOff:
                audioEngine.noteOff(event.note)
            }
            
            currentEventIndex += 1
        }
        
        // Loop handling
        if currentEventIndex >= recordedEvents.count {
            if isLooping {
                // Restart play loop
                currentEventIndex = 0
                startTime = Date() 
                // Note: Better looping would subtract duration instead of resetting Date(), 
                // but this prevents drift on long running basic loops.
            } else {
                stopPlayback()
            }
        }
    }
    
    /// Export to simple JSON format
    func exportToJSON() -> URL? {
        guard !recordedEvents.isEmpty else { return nil }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(recordedEvents)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let filename = "accordion_\(dateFormatter.string(from: Date())).json"
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent(filename)
            
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Export error: \(error)")
            return nil
        }
    }
    
    /// Get recording duration
    var duration: TimeInterval {
        guard let lastEvent = recordedEvents.last else { return 0 }
        return lastEvent.timestamp
    }
}
