import Foundation
import AppKit

/// Maps keyboard keys to MIDI notes (GarageBand Musical Typing layout)
class NoteMapper {
    // Base octave (middle C = C4 = MIDI note 60)
    var currentOctave: Int = 4
    
    // GarageBand Musical Typing layout
    // White keys: A S D F G H J K L ; (C D E F G A B C D E)
    // Black keys: W E   T Y U   O P   (C# D#   F# G# A#   C# D#)
    
    private let whiteKeyMapping: [UInt16: Int] = [
        0:  0,   // A -> C
        1:  2,   // S -> D
        2:  4,   // D -> E
        3:  5,   // F -> F
        5:  7,   // G -> G
        4:  9,   // H -> A
        38: 11,  // J -> B
        40: 12,  // K -> C (next octave)
        37: 14,  // L -> D
        41: 16,  // ; -> E
    ]
    
    private let blackKeyMapping: [UInt16: Int] = [
        13: 1,   // W -> C#
        14: 3,   // E -> D#
        17: 6,   // T -> F#
        16: 8,   // Y -> G#
        32: 10,  // U -> A#
        31: 13,  // O -> C# (next octave)
        35: 15,  // P -> D#
    ]
    
    // Control keys
    static let octaveDownKey: UInt16 = 6   // Z
    static let octaveUpKey: UInt16 = 7     // X
    static let sustainKey: UInt16 = 48     // Tab
    
    /// Convert key code to MIDI note number
    func midiNote(for keyCode: UInt16) -> UInt8? {
        var semitone: Int?
        
        if let offset = whiteKeyMapping[keyCode] {
            semitone = offset
        } else if let offset = blackKeyMapping[keyCode] {
            semitone = offset
        }
        
        guard let semi = semitone else { return nil }
        
        // Calculate MIDI note: C4 = 60
        let baseNote = 60 + (currentOctave - 4) * 12
        let midiNote = baseNote + semi
        
        // Clamp to valid MIDI range
        guard midiNote >= 0 && midiNote <= 127 else { return nil }
        
        return UInt8(midiNote)
    }
    
    /// Check if key is a control key
    func isControlKey(_ keyCode: UInt16) -> Bool {
        return keyCode == NoteMapper.octaveDownKey ||
               keyCode == NoteMapper.octaveUpKey ||
               keyCode == NoteMapper.sustainKey
    }
    
    /// Handle control key
    func handleControlKey(_ keyCode: UInt16) -> ControlAction? {
        switch keyCode {
        case NoteMapper.octaveDownKey:
            if currentOctave > 0 {
                currentOctave -= 1
                return .octaveChanged(currentOctave)
            }
        case NoteMapper.octaveUpKey:
            if currentOctave < 8 {
                currentOctave += 1
                return .octaveChanged(currentOctave)
            }
        case NoteMapper.sustainKey:
            return .sustainToggle
        default:
            break
        }
        return nil
    }
    
    /// Get display name for a MIDI note
    func noteName(for midiNote: UInt8) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(midiNote) / 12 - 1
        let note = Int(midiNote) % 12
        return "\(noteNames[note])\(octave)"
    }
}

enum ControlAction {
    case octaveChanged(Int)
    case sustainToggle
}
