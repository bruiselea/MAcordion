import Foundation
import AVFoundation

/// Records MIDI events for playback/export
class MIDIRecorder: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var recordedEvents: [MIDIEvent] = []
    
    private var startTime: Date?
    
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
