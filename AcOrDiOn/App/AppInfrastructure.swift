import SwiftUI
import AppKit

/// AppKit delegate that installs the global key event monitors and forces
/// the app into the foreground. Both Hinge and Breath entry points reuse
/// this delegate as-is — none of it is bellows-source specific.
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public override init() { super.init() }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)  // Dock icon + keyboard focus
        NSApp.activate(ignoringOtherApps: true)

        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            NotificationCenter.default.post(name: .keyDown, object: event)
            return nil
        }
        NSEvent.addLocalMonitorForEvents(matching: [.keyUp]) { event in
            NotificationCenter.default.post(name: .keyUp, object: event)
            return nil
        }
        print("AppDelegate: Key monitors installed")
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

extension Notification.Name {
    static let keyDown = Notification.Name("keyDown")
    static let keyUp = Notification.Name("keyUp")
}

/// Live diagnostics kept out of the performance surface. The native Settings
/// scene observes this store so connection and sensor details remain available
/// without competing with the instrument UI.
public final class DiagnosticsStore: ObservableObject {
    public static let shared = DiagnosticsStore()

    @Published public private(set) var isConnected = false
    @Published public private(set) var angle: Double = 90
    @Published public private(set) var pressure: Double = 0

    private init() {}

    func updateConnection(_ isConnected: Bool) {
        self.isConnected = isConnected
    }

    func updateAngle(_ angle: Double) {
        self.angle = angle
    }

    func updatePressure(_ pressure: Double) {
        self.pressure = pressure
    }
}

/// Bridges the global NSEvent key monitors to SwiftUI's environment.
/// Held as a `@StateObject` in each entry-point App.
public final class KeyboardHandler: ObservableObject {
    @Published public var pressedKeys: Set<UInt16> = []
    @Published public var isActive = true

    public var onKeyDown: ((UInt16) -> Void)?
    public var onKeyUp: ((UInt16) -> Void)?

    public init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyDown), name: .keyDown, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyUp), name: .keyUp, object: nil)
        print("KeyboardHandler: Initialized")
    }

    @objc private func handleKeyDown(_ notification: Notification) {
        guard let event = notification.object as? NSEvent else { return }
        guard !event.isARepeat else { return }
        let keyCode = event.keyCode
        if !pressedKeys.contains(keyCode) {
            pressedKeys.insert(keyCode)
            onKeyDown?(keyCode)
        }
    }

    @objc private func handleKeyUp(_ notification: Notification) {
        guard let event = notification.object as? NSEvent else { return }
        let keyCode = event.keyCode
        pressedKeys.remove(keyCode)
        onKeyUp?(keyCode)
    }
}

/// UI-facing app state. Stays internal — only ContentView/AccordionViewModel
/// read it inside the library.
class AppState: ObservableObject {
    @Published var currentAngle: Double = 90
    @Published var velocity: Int = 0
    @Published var currentOctave: Int = 4
    @Published var activeNotes: Set<UInt8> = []
    @Published var isRecording: Bool = false
    @Published var isSustainOn: Bool = false
    @Published var pressure: Double = 0.5
    @Published var isAirValveOpen: Bool = false
}
