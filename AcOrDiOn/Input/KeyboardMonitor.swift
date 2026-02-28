import Foundation
import AppKit
import Combine

/// Monitors keyboard input for note playing
class KeyboardMonitor: ObservableObject {
    @Published var pressedKeys: Set<UInt16> = []
    
    private var localMonitor: Any?
    
    var onKeyDown: ((UInt16) -> Void)?
    var onKeyUp: ((UInt16) -> Void)?
    
    // Keys that we handle (consume)
    private let handledKeyCodes: Set<UInt16> = [
        // White keys: A S D F G H J K L ;
        0, 1, 2, 3, 5, 4, 38, 40, 37, 41,
        // Black keys: W E T Y U O P
        13, 14, 17, 16, 32, 31, 35,
        // Control keys: Z X Tab
        6, 7, 48
    ]
    
    init() {
        print("KeyboardMonitor: Initialized")
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        print("KeyboardMonitor: Starting monitoring")
        
        // Make sure the app is active
        NSApp.activate(ignoringOtherApps: true)
        
        // Monitor key events and consume them if they're music keys
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self = self else { return event }
            
            let shouldConsume = self.handleKeyEvent(event)
            
            // Return nil to consume the event (prevent it from going to other responders)
            // Return event to let it pass through
            return shouldConsume ? nil : event
        }
        
        print("KeyboardMonitor: Monitor registered")
    }
    
    func stopMonitoring() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    /// Handle key event, returns true if the event should be consumed
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        
        // Only handle keys we care about
        guard handledKeyCodes.contains(keyCode) else {
            return false
        }
        
        switch event.type {
        case .keyDown:
            // Ignore key repeat
            guard !event.isARepeat else { return true }
            
            if !pressedKeys.contains(keyCode) {
                pressedKeys.insert(keyCode)
                print("KeyboardMonitor: Key DOWN \(keyCode)")
                onKeyDown?(keyCode)
            }
            return true
            
        case .keyUp:
            if pressedKeys.contains(keyCode) {
                pressedKeys.remove(keyCode)
                print("KeyboardMonitor: Key UP \(keyCode)")
                onKeyUp?(keyCode)
            }
            return true
            
        default:
            return false
        }
    }
}
