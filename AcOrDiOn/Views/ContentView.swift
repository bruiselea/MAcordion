import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var keyboardHandler: KeyboardHandler
    @ObservedObject var keyboardHandlerDirect: KeyboardHandler
    
    @StateObject private var hingeMonitor = HingeMonitor()
    @StateObject private var audioEngine = AudioEngine()
    @StateObject private var midiRecorder = MIDIRecorder()
    
    @State private var noteMapper = NoteMapper()
    @State private var velocityCalculator = VelocityCalculator()
    @State private var activeNoteNames: [String] = []
    
    init(keyboardHandler: KeyboardHandler) {
        self.keyboardHandlerDirect = keyboardHandler
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("🪗 AcOrDiOn")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Always show keyboard active since we use global monitor
                Text("✓ キーボード入力OK - A,S,D,F,G,H,J,K,Lで演奏")
                    .foregroundColor(.green)
                    .padding(8)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
                
                HingeAngleView(angle: hingeMonitor.currentAngle, velocity: appState.velocity)
                
                ActiveNotesView(noteNames: activeNoteNames)
                
                OctaveView(octave: appState.currentOctave)
                
                HStack(spacing: 20) {
                    StatusPill(label: "Sustain", isActive: appState.isSustainOn, activeColor: .orange)
                    
                    Button(action: toggleRecording) {
                        HStack {
                            Circle().fill(midiRecorder.isRecording ? Color.red : Color.gray).frame(width: 12, height: 12)
                            Text(midiRecorder.isRecording ? "録音中..." : "録音").foregroundColor(.white)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Color.white.opacity(0.1)).cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
                
                KeyboardHintView()
                
                Spacer()
            }
            .padding(40)
        }
        .onAppear(perform: setup)
        .onDisappear(perform: cleanup)
    }
    
    private func setup() {
        print("ContentView: setup")
        hingeMonitor.startMonitoring()
        
        // Connect keyboard handler
        keyboardHandlerDirect.onKeyDown = { [self] keyCode in
            handleKeyDown(keyCode)
        }
        keyboardHandlerDirect.onKeyUp = { [self] keyCode in
            handleKeyUp(keyCode)
        }
        
        // Hinge update timer
        Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { _ in
            appState.currentAngle = hingeMonitor.currentAngle
            let velocity = velocityCalculator.calculateVelocity(from: hingeMonitor.angularVelocity)
            appState.velocity = velocity
            audioEngine.updateVelocity(UInt8(velocity))
        }
        
        print("ContentView: Audio engine ready: \(audioEngine.isReady)")
    }
    
    private func cleanup() {
        hingeMonitor.stopMonitoring()
        audioEngine.stop()
    }
    
    private func handleKeyDown(_ keyCode: UInt16) {
        print("ContentView: handleKeyDown \(keyCode)")
        
        // Control keys
        switch keyCode {
        case 6: // Z
            if appState.currentOctave > 0 { appState.currentOctave -= 1 }
            return
        case 7: // X
            if appState.currentOctave < 8 { appState.currentOctave += 1 }
            return
        case 48: // Tab
            appState.isSustainOn.toggle()
            audioEngine.setSustain(appState.isSustainOn)
            return
        default:
            break
        }
        
        // Note keys
        if let midiNote = keyCodeToMidiNote(keyCode) {
            let octaveOffset = (appState.currentOctave - 4) * 12
            let note = UInt8(max(0, min(127, Int(midiNote) + octaveOffset)))
            let velocity = UInt8(max(40, velocityCalculator.calculateVelocity(from: hingeMonitor.angularVelocity)))
            
            print("ContentView: Playing note \(note) velocity \(velocity)")
            audioEngine.noteOn(note, velocity: velocity)
            appState.activeNotes.insert(note)
            updateActiveNoteNames()
        }
    }
    
    private func handleKeyUp(_ keyCode: UInt16) {
        if let midiNote = keyCodeToMidiNote(keyCode) {
            let octaveOffset = (appState.currentOctave - 4) * 12
            let note = UInt8(max(0, min(127, Int(midiNote) + octaveOffset)))
            
            if !appState.isSustainOn {
                audioEngine.noteOff(note)
            }
            appState.activeNotes.remove(note)
            updateActiveNoteNames()
        }
    }
    
    private func keyCodeToMidiNote(_ keyCode: UInt16) -> UInt8? {
        let mapping: [UInt16: UInt8] = [
            0: 60, 1: 62, 2: 64, 3: 65, 5: 67, 4: 69, 38: 71, 40: 72, 37: 74, 41: 76,
            13: 61, 14: 63, 17: 66, 16: 68, 32: 70, 31: 73, 35: 75
        ]
        return mapping[keyCode]
    }
    
    private func updateActiveNoteNames() {
        activeNoteNames = appState.activeNotes.sorted().map { noteMapper.noteName(for: $0) }
    }
    
    private func toggleRecording() {
        if midiRecorder.isRecording {
            midiRecorder.stopRecording()
            appState.isRecording = false
            if let url = midiRecorder.exportToJSON() {
                NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
            }
        } else {
            midiRecorder.startRecording()
            appState.isRecording = true
        }
    }
}

// MARK: - Subviews

struct HingeAngleView: View {
    let angle: Double
    let velocity: Int
    
    var body: some View {
        ZStack {
            Circle().trim(from: 0.25, to: 0.75).stroke(Color.white.opacity(0.2), lineWidth: 8).frame(width: 200, height: 200).rotationEffect(.degrees(180))
            Circle().trim(from: 0.25, to: 0.25 + (angle / 360.0) * 0.5)
                .stroke(LinearGradient(colors: [.blue, .purple, .pink], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 200, height: 200).rotationEffect(.degrees(180))
            VStack {
                Text("\(Int(angle))°").font(.system(size: 48, weight: .bold, design: .monospaced)).foregroundColor(.white)
                HStack(spacing: 2) {
                    ForEach(0..<10, id: \.self) { i in
                        Rectangle().fill(i < velocity / 13 ? Color(hue: 0.3 - Double(i) / 10.0 * 0.3, saturation: 0.8, brightness: 0.9) : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 20).cornerRadius(2)
                    }
                }
            }
        }
    }
}

struct ActiveNotesView: View {
    let noteNames: [String]
    var body: some View {
        HStack(spacing: 8) {
            if noteNames.isEmpty {
                Text("キーを押して演奏").foregroundColor(.gray)
            } else {
                ForEach(noteNames, id: \.self) { name in
                    Text(name).font(.system(size: 24, weight: .bold, design: .monospaced)).foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6).background(Color.blue.opacity(0.6)).cornerRadius(8)
                }
            }
        }.frame(height: 50)
    }
}

struct OctaveView: View {
    let octave: Int
    var body: some View {
        HStack(spacing: 4) {
            Text("オクターブ:").foregroundColor(.gray)
            ForEach(0..<9, id: \.self) { i in Circle().fill(i == octave ? Color.cyan : Color.gray.opacity(0.3)).frame(width: 12, height: 12) }
            Text("C\(octave)").font(.system(.body, design: .monospaced)).foregroundColor(.white)
        }
    }
}

struct StatusPill: View {
    let label: String; let isActive: Bool; let activeColor: Color
    var body: some View {
        HStack {
            Circle().fill(isActive ? activeColor : Color.gray).frame(width: 8, height: 8)
            Text(label).foregroundColor(isActive ? .white : .gray)
        }.padding(.horizontal, 16).padding(.vertical, 8).background(Color.white.opacity(isActive ? 0.2 : 0.05)).cornerRadius(16)
    }
}

struct KeyboardHintView: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("黒鍵: W E   T Y U   O P").font(.system(.caption, design: .monospaced))
            Text("白鍵: A S D F G H J K L ;").font(.system(.caption, design: .monospaced))
            Text("Z/X: オクターブ↓/↑  Tab: サスティン").font(.system(.caption, design: .monospaced))
        }.foregroundColor(.gray).padding().background(Color.white.opacity(0.05)).cornerRadius(8)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0; Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
