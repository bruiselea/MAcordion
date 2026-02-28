import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AccordionState
    @ObservedObject var hinge = HingeSensor.shared
    @ObservedObject var synth = AccordionSynth.shared
    @ObservedObject var keyboard = KeyboardMonitor.shared
    
    let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color(hex: "1a1a2e"), Color(hex: "16213e"), Color(hex: "0f3460")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Title
                Text("🪗 AcOrDiOn")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, .cyan.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: .cyan.opacity(0.5), radius: 10)
                
                // Mode selector
                HStack(spacing: 20) {
                    ForEach(0..<2, id: \.self) { mode in
                        Button(action: { state.mode = mode }) {
                            Text(AccordionState.modeNames[mode])
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(state.mode == mode ? .white : .gray)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(state.mode == mode ? Color.cyan.opacity(0.3) : Color.white.opacity(0.05))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Bellows visualizer
                BellowsView(volume: hinge.volume, angle: hinge.currentAngle)
                    .frame(height: 120)
                
                // Volume bar
                VolumeBar(volume: hinge.volume, velocity: hinge.angularVelocity)
                
                // Active notes display
                ActiveNotesView(notes: state.activeNotes, noteNames: noteNames)
                    .frame(height: 50)
                
                // Octave indicator
                OctaveIndicator(octave: state.octave)
                
                // Sustain indicator
                HStack {
                    Circle()
                        .fill(state.sustain ? Color.orange : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                    Text("Sustain (Tab)")
                        .foregroundColor(state.sustain ? .orange : .gray)
                }
                .font(.system(size: 14))
                
                Spacer()
                
                // Keyboard hints
                KeyboardHints(mode: state.mode)
            }
            .padding(30)
        }
        .onAppear(perform: setup)
        .onDisappear(perform: cleanup)
    }
    
    private func setup() {
        hinge.start()
        
        keyboard.onKeyDown = { keyCode in
            handleKeyDown(keyCode)
        }
        keyboard.onKeyUp = { keyCode in
            handleKeyUp(keyCode)
        }
        
        // Volume update timer
        Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
            synth.updateVolume(hinge.volume)
            state.volume = hinge.volume
            state.currentAngle = hinge.currentAngle
            state.angularVelocity = hinge.angularVelocity
        }
    }
    
    private func cleanup() {
        hinge.stop()
        synth.stop()
    }
    
    private func handleKeyDown(_ keyCode: UInt16) {
        print("ContentView: handleKeyDown called with keyCode: \(keyCode)")
        
        // Mode keys
        if keyCode == 18 { state.mode = 0; return } // 1
        if keyCode == 19 { state.mode = 1; return } // 2
        
        // Octave keys
        if keyCode == 33 { state.octave = max(2, state.octave - 1); return } // [
        if keyCode == 30 { state.octave = min(6, state.octave + 1); return } // ]
        
        // Sustain
        if keyCode == 48 { state.sustain.toggle(); return } // Tab
        
        // Note keys
        let keyMap = KeyMaps.getMap(mode: state.mode)
        if let noteOffset = keyMap[keyCode] {
            let midiNote = UInt8(clamping: 60 + (state.octave - 4) * 12 + noteOffset)
            print("ContentView: Playing note \(midiNote)")
            state.activeNotes.insert(midiNote)
            synth.noteOn(midiNote)
        }
    }
    
    private func handleKeyUp(_ keyCode: UInt16) {
        let keyMap = KeyMaps.getMap(mode: state.mode)
        if let noteOffset = keyMap[keyCode] {
            let midiNote = UInt8(clamping: 60 + (state.octave - 4) * 12 + noteOffset)
            if !state.sustain {
                state.activeNotes.remove(midiNote)
                synth.noteOff(midiNote)
            }
        }
    }
}

// MARK: - Bellows Visualizer

struct BellowsView: View {
    let volume: Double
    let angle: Double
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let foldCount = 8
            let baseSpacing = width / CGFloat(foldCount * 2)
            let expansion = CGFloat(volume) * baseSpacing * 0.8
            
            HStack(spacing: baseSpacing + expansion) {
                ForEach(0..<foldCount, id: \.self) { i in
                    BellowsFold(intensity: volume, index: i)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct BellowsFold: View {
    let intensity: Double
    let index: Int
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hue: 0.55 + intensity * 0.15, saturation: 0.7, brightness: 0.6 + intensity * 0.3),
                        Color(hue: 0.55, saturation: 0.5, brightness: 0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 20, height: 60 + CGFloat(intensity) * 40)
            .shadow(color: .cyan.opacity(intensity * 0.5), radius: 5)
    }
}

// MARK: - Volume Bar

struct VolumeBar: View {
    let volume: Double
    let velocity: Double
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 30)
                
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [.green, .yellow, .orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, CGFloat(volume) * 500), height: 30)
                
                Text("BELLOWS: \(Int(volume * 100))%")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(radius: 2)
                    .frame(maxWidth: .infinity)
            }
            .frame(width: 500)
            
            Text("Speed: \(String(format: "%.1f", velocity)) deg/s")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Active Notes

struct ActiveNotesView: View {
    let notes: Set<UInt8>
    let noteNames: [String]
    
    var body: some View {
        HStack(spacing: 8) {
            if notes.isEmpty {
                Text("Hold keys and move screen to play")
                    .foregroundColor(.gray)
            } else {
                ForEach(notes.sorted().prefix(8), id: \.self) { note in
                    let name = noteNames[Int(note) % 12]
                    let octave = Int(note) / 12 - 1
                    
                    Text("\(name)\(octave)")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.cyan.opacity(0.5))
                        )
                }
            }
        }
    }
}

// MARK: - Octave Indicator

struct OctaveIndicator: View {
    let octave: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Text("Octave: C\(octave)")
                .foregroundColor(.white)
            
            HStack(spacing: 6) {
                ForEach(2..<7, id: \.self) { o in
                    Circle()
                        .fill(o == octave ? Color.cyan : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }
            
            Text("[ / ]")
                .foregroundColor(.gray)
                .font(.system(size: 12))
        }
    }
}

// MARK: - Keyboard Hints

struct KeyboardHints: View {
    let mode: Int
    
    var body: some View {
        VStack(spacing: 4) {
            if mode == 0 {
                Text("White: A S D F G H J K L ;")
                Text("Black: W E   T Y U   O P")
            } else {
                Text("Row 1: Q W E R T Y U I O P")
                Text("Row 2: A S D F G H J K L ;")
                Text("Row 3: Z X C V B N M , . /")
            }
        }
        .font(.system(size: 12, design: .monospaced))
        .foregroundColor(.gray.opacity(0.7))
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(AccordionState())
}
