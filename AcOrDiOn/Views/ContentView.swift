import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var viewModel = AccordionViewModel()
    @ObservedObject var keyboardHandlerDirect: KeyboardHandler
    
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
                
                HingeAngleView(angle: viewModel.appState.currentAngle, pressure: viewModel.appState.pressure)
                
                ActiveNotesView(noteNames: viewModel.activeNoteNames)
                
                OctaveView(octave: viewModel.appState.currentOctave)
                
                HStack(spacing: 20) {
                    StatusPill(label: "Sustain", isActive: viewModel.appState.isSustainOn, activeColor: .orange)
                    StatusPill(label: "Air Valve", isActive: viewModel.appState.isAirValveOpen, activeColor: .cyan)
                    
                    Button(action: toggleRecording) {
                        HStack {
                            Circle().fill(viewModel.appState.isRecording ? Color.red : Color.gray).frame(width: 12, height: 12)
                            Text(viewModel.appState.isRecording ? "録音中..." : "録音").foregroundColor(.white)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Color.white.opacity(0.1)).cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        if viewModel.midiRecorder.isPlaying {
                            viewModel.midiRecorder.stopPlayback()
                        } else {
                            viewModel.midiRecorder.startPlayback(audioEngine: viewModel.audioEngine, loop: true)
                        }
                    }) {
                        HStack {
                            Image(systemName: "repeat")
                                .foregroundColor(viewModel.midiRecorder.isPlaying ? .green : .gray)
                            Text(viewModel.midiRecorder.isPlaying ? "ループ停止" : "ループ再生").foregroundColor(.white)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Color.white.opacity(0.1)).cornerRadius(20)
                    }
                    .disabled(viewModel.midiRecorder.recordedEvents.isEmpty)
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
        viewModel.start()
        
        // Connect keyboard handler directly to the ViewModel
        keyboardHandlerDirect.onKeyDown = { keyCode in
            viewModel.handleKeyDown(keyCode)
        }
        keyboardHandlerDirect.onKeyUp = { keyCode in
            viewModel.handleKeyUp(keyCode)
        }
    }
    
    private func cleanup() {
        viewModel.stop()
    }
    
    private func toggleRecording() {
        if let url = viewModel.toggleRecording() {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
        }
    }
}

// MARK: - Subviews
// (Unchanged)

struct HingeAngleView: View {
    let angle: Double
    let pressure: Double
    
    var body: some View {
        ZStack {
            Circle().trim(from: 0.25, to: 0.75).stroke(Color.white.opacity(0.2), lineWidth: 8).frame(width: 200, height: 200).rotationEffect(.degrees(180))
            Circle().trim(from: 0.25, to: 0.25 + (angle / 360.0) * 0.5)
                .stroke(LinearGradient(colors: [.blue, .purple, .pink], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 200, height: 200).rotationEffect(.degrees(180))
            VStack {
                Text("\(Int(angle))°").font(.system(size: 48, weight: .bold, design: .monospaced)).foregroundColor(.white)
                
                // Pressure Bar
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 10)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.green, .yellow, .red], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 100 * CGFloat(pressure), height: 10)
                        .frame(width: 100, alignment: .leading)
                }
                .padding(.top, 4)
                Text("Pressure").font(.system(size: 10)).foregroundColor(.gray)
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
            Text(" Space: 空気抜き  Enter: ループ再生/停止").font(.system(.caption, design: .monospaced)).foregroundColor(.cyan)
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
