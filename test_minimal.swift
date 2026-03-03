#!/usr/bin/env swift

// Minimal test for keyboard and audio
import AppKit
import AVFoundation
import AudioToolbox

// MARK: - Audio Test
print("=== Audio Test ===")

let engine = AVAudioEngine()
let sampler = AVAudioUnitSampler()

engine.attach(sampler)
engine.connect(sampler, to: engine.mainMixerNode, format: nil)

do {
    try engine.start()
    print("✓ Audio engine started")
    
    // Try to load sound bank
    let dlsPath = "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"
    if FileManager.default.fileExists(atPath: dlsPath) {
        try sampler.loadSoundBankInstrument(
            at: URL(fileURLWithPath: dlsPath),
            program: 0,  // Piano
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB)
        )
        print("✓ Sound bank loaded")
    } else {
        print("✗ Sound bank not found at \(dlsPath)")
    }
    
    // Play test note
    print("Playing C4 (MIDI note 60)...")
    sampler.startNote(60, withVelocity: 100, onChannel: 0)
    Thread.sleep(forTimeInterval: 1.0)
    sampler.stopNote(60, onChannel: 0)
    print("✓ Note played")
    
} catch {
    print("✗ Audio error: \(error)")
}

// MARK: - Keyboard Test
print("\n=== Keyboard Test ===")
print("Press any key within 5 seconds...")

class KeyHandler: NSObject {
    var keyPressed = false
    
    @objc func handleKeyDown(_ event: NSEvent) {
        print("✓ Key detected: keyCode=\(event.keyCode), char='\(event.characters ?? "")'")
        keyPressed = true
    }
}

let handler = KeyHandler()

// Need to run the app to receive events
let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)

let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
    handler.handleKeyDown(event)
    return nil  // Consume event
}

// Run for 5 seconds
let endTime = Date().addingTimeInterval(5)
while Date() < endTime && !handler.keyPressed {
    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
}

if let m = monitor {
    NSEvent.removeMonitor(m)
}

if !handler.keyPressed {
    print("✗ No key press detected")
}

print("\n=== Test Complete ===")
