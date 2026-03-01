import SwiftUI
import AppKit

@main
struct AcOrDiOnApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var keyboardHandler = KeyboardHandler()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(keyboardHandler)
                .frame(minWidth: 600, minHeight: 400)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        
        // Set up global key event monitor (works even when other views have focus)
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            NotificationCenter.default.post(name: .keyDown, object: event)
            return nil  // Consume the event
        }
        
        NSEvent.addLocalMonitorForEvents(matching: [.keyUp]) { event in
            NotificationCenter.default.post(name: .keyUp, object: event)
            return nil
        }
        
        print("AppDelegate: Key monitors installed")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

extension Notification.Name {
    static let keyDown = Notification.Name("keyDown")
    static let keyUp = Notification.Name("keyUp")
}

class KeyboardHandler: ObservableObject {
    @Published var pressedKeys: Set<UInt16> = []
    @Published var isActive = true
    
    var onKeyDown: ((UInt16) -> Void)?
    var onKeyUp: ((UInt16) -> Void)?
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyDown), name: .keyDown, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyUp), name: .keyUp, object: nil)
        print("KeyboardHandler: Initialized")
    }
    
    @objc private func handleKeyDown(_ notification: Notification) {
        guard let event = notification.object as? NSEvent else { return }
        guard !event.isARepeat else { return }
        
        let keyCode = event.keyCode
        print("KeyboardHandler: Key DOWN \(keyCode)")
        
        if !pressedKeys.contains(keyCode) {
            pressedKeys.insert(keyCode)
            onKeyDown?(keyCode)
        }
    }
    
    @objc private func handleKeyUp(_ notification: Notification) {
        guard let event = notification.object as? NSEvent else { return }
        
        let keyCode = event.keyCode
        print("KeyboardHandler: Key UP \(keyCode)")
        
        pressedKeys.remove(keyCode)
        onKeyUp?(keyCode)
    }
}

class AppState: ObservableObject {
    @Published var currentAngle: Double = 0
    @Published var velocity: Int = 0
    @Published var currentOctave: Int = 4
    @Published var activeNotes: Set<UInt8> = []
    @Published var isRecording: Bool = false
    @Published var isSustainOn: Bool = false
    @Published var pressure: Double = 0.5   // Bellows pressure
    @Published var isAirValveOpen: Bool = false // Spacebar state
}
