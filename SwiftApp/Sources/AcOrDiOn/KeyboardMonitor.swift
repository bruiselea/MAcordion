import AppKit
import Combine

/// Global keyboard monitor using NSEvent
class KeyboardMonitor: ObservableObject {
    static let shared = KeyboardMonitor()
    
    @Published var pressedKeys: Set<UInt16> = []
    
    var onKeyDown: ((UInt16) -> Void)?
    var onKeyUp: ((UInt16) -> Void)?
    
    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    
    private init() {}
    
    func startMonitoring() {
        print("KeyboardMonitor: Starting monitoring...")
        
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard !event.isARepeat else { return nil }
            print("KeyboardMonitor: Key DOWN - keyCode: \(event.keyCode)")
            self?.handleKeyDown(event.keyCode)
            return nil // Consume the event
        }
        
        keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            print("KeyboardMonitor: Key UP - keyCode: \(event.keyCode)")
            self?.handleKeyUp(event.keyCode)
            return nil
        }
        
        print("KeyboardMonitor: Monitors installed successfully")
    }
    
    func stopMonitoring() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = keyUpMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    private func handleKeyDown(_ keyCode: UInt16) {
        if !pressedKeys.contains(keyCode) {
            pressedKeys.insert(keyCode)
            onKeyDown?(keyCode)
        }
    }
    
    private func handleKeyUp(_ keyCode: UInt16) {
        pressedKeys.remove(keyCode)
        onKeyUp?(keyCode)
    }
}

/// Key mappings
struct KeyMaps {
    // Piano mode (GarageBand style)
    static let piano: [UInt16: Int] = [
        0: 0, 1: 2, 2: 4, 3: 5, 5: 7, 4: 9, 38: 11, 40: 12, 37: 14, 41: 16,  // A-;
        13: 1, 14: 3, 17: 6, 16: 8, 32: 10, 31: 13, 35: 15   // W E T Y U O P
    ]
    
    // Button accordion (B-System)
    static let button: [UInt16: Int] = [
        12: 0, 13: 1, 14: 2, 15: 3, 17: 4, 16: 5, 32: 6, 34: 7, 31: 8, 35: 9,  // Q-P
        0: 3, 1: 4, 2: 5, 3: 6, 5: 7, 4: 8, 38: 9, 40: 10, 37: 11, 41: 12,    // A-;
        6: 6, 7: 7, 8: 8, 9: 9, 11: 10, 45: 11, 46: 12, 43: 13, 47: 14, 44: 15 // Z-/
    ]
    
    static func getMap(mode: Int) -> [UInt16: Int] {
        return mode == 1 ? button : piano
    }
}
