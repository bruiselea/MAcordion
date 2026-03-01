import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var viewModel = AccordionViewModel()
    @EnvironmentObject var keyboardHandler: KeyboardHandler
    
    var body: some View {
        ZStack {
            // Elegant burgundy/leather-like background
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "4A0E17"), Color(hex: "1A0508")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Subtle wood/leather texture overlay
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            
            VStack(spacing: 25) {
                // Header with classic serif typography and gold accent
                Text("🪗 AcOrDiOn")
                    .font(.system(size: 56, weight: .bold, design: .serif))
                    .foregroundColor(Color(hex: "F3E5AB")) // Ivory/Gold
                    .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 4)
                    .padding(.top, 10)
                
                // Keyboard status indicator
                Text("✓ Keyboard Active - Play with A,S,D,F,G,H,J,K,L")
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundColor(Color(hex: "FFF7D6"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "D4AF37").opacity(0.5), lineWidth: 1)
                    )
                
                HStack(alignment: .top, spacing: 40) {
                    // Left Side: Controls & Registers (Accordion Bass Side)
                    VStack(spacing: 25) {
                        Text("REGISTERS")
                            .font(.system(size: 12, weight: .black, design: .serif))
                            .foregroundColor(Color(hex: "D4AF37"))
                            .tracking(2)
                        
                        VStack(spacing: 15) {
                            RegisterButton(label: "SUSTAIN", isActive: viewModel.appState.isSustainOn)
                            RegisterButton(label: "AIR VALVE", isActive: viewModel.appState.isAirValveOpen)
                            
                            Divider().background(Color(hex: "D4AF37").opacity(0.3)).padding(.vertical, 5)
                            
                            Button(action: toggleRecording) {
                                RegisterButtonStyle(
                                    label: viewModel.appState.isRecording ? "REC..." : "RECORD",
                                    isActive: viewModel.appState.isRecording,
                                    activeColor: Color(hex: "C41E3A") // Crimson
                                )
                            }.buttonStyle(.plain)
                            
                            Button(action: {
                                if viewModel.midiRecorder.isPlaying {
                                    viewModel.midiRecorder.stopPlayback()
                                } else {
                                    viewModel.midiRecorder.startPlayback(audioEngine: viewModel.audioEngine, loop: true)
                                }
                            }) {
                                RegisterButtonStyle(
                                    label: viewModel.appState.isRecording ? "PLAYING" : "LOOP",
                                    isActive: viewModel.midiRecorder.isPlaying,
                                    activeColor: Color(hex: "50C878") // Emerald
                                )
                            }
                            .disabled(viewModel.midiRecorder.recordedEvents.isEmpty)
                            .buttonStyle(.plain)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LinearGradient(colors: [Color(hex: "2A080C"), Color.black], startPoint: .top, endPoint: .bottom))
                                .shadow(color: .black.opacity(0.6), radius: 10, x: 0, y: 10)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "D4AF37").opacity(0.3), lineWidth: 1)
                        )
                        
                        OctaveView(octave: viewModel.appState.currentOctave)
                    }
                    
                    // Center: Bellows Visualizer
                    VStack {
                        Text("BELLOWS")
                            .font(.system(size: 12, weight: .black, design: .serif))
                            .foregroundColor(Color(hex: "D4AF37"))
                            .tracking(2)
                            .padding(.bottom, 10)
                        
                        HingeAngleView(angle: viewModel.appState.currentAngle, pressure: viewModel.appState.pressure)
                    }
                }
                
                Spacer()
                
                // Bottom: Piano Keys (Treble Side)
                VStack(spacing: 15) {
                    PianoKeysView(activeNotes: viewModel.appState.activeNotes)
                    KeyboardHintView()
                }
            }
            .padding(40)
        }
        .onAppear(perform: setup)
        .onDisappear(perform: cleanup)
    }
    
    private func setup() {
        print("ContentView: setup")
        viewModel.start()
        
        // Connect keyboard handler from environment to the ViewModel
        keyboardHandler.onKeyDown = { keyCode in
            viewModel.handleKeyDown(keyCode)
        }
        keyboardHandler.onKeyUp = { keyCode in
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

struct HingeAngleView: View {
    let angle: Double
    let pressure: Double
    
    var body: some View {
        ZStack {
            // Elegant brass ring background
            Circle()
                .trim(from: 0.25, to: 0.75)
                .stroke(Color(hex: "D4AF37").opacity(0.2), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(180))
            
            // Active bellows opening arc (Crimson/Gold gradient)
            Circle()
                .trim(from: 0.25, to: 0.25 + (angle / 360.0) * 0.5)
                .stroke(
                    LinearGradient(colors: [Color(hex: "8b0000"), Color(hex: "D4AF37"), Color(hex: "FFF7D6")], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(180))
                .shadow(color: Color(hex: "D4AF37").opacity(0.5), radius: 8, x: 0, y: 0)
            
            VStack(spacing: 0) {
                Text("\(Int(angle))°")
                    .font(.system(size: 52, weight: .light, design: .serif))
                    .foregroundColor(Color(hex: "FFF7D6"))
                    .shadow(color: .black, radius: 2, x: 0, y: 2)
                
                // Bellows Pressure indicator (looks like an air gauge)
                VStack(spacing: 4) {
                    ZStack(alignment: .leading) {
                        // Background slot
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 120, height: 8)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(hex: "D4AF37").opacity(0.4), lineWidth: 0.5))
                        
                        // Fill
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: [Color.green.opacity(0.8), Color.yellow, Color.red], startPoint: .leading, endPoint: .trailing))
                            .frame(width: 120 * CGFloat(pressure), height: 8)
                            .shadow(color: .black, radius: 2)
                    }
                    Text("AIR TANK")
                        .font(.system(size: 9, weight: .bold, design: .serif))
                        .foregroundColor(Color(hex: "D4AF37").opacity(0.8))
                        .tracking(1)
                }
                .padding(.top, 10)
            }
        }
    }
}

// Visual representation of standard piano keys
struct PianoKeysView: View {
    let activeNotes: Set<UInt8>
    
    // Simple 1-octave representation for visuals based on C major starting 60 (C4)
    let whiteKeys: [UInt8] = [60, 62, 64, 65, 67, 69, 71, 72, 74, 76]
    
    // Position represents the index of the white key it follows.
    // e.g., 1.0 means it's right after white key index 0 (C), centered between 0 and 1.
    let blackKeys: [UInt8: CGFloat] = [
        61: 1.0, 63: 2.0, 
        66: 4.0, 68: 5.0, 70: 6.0, 
        73: 8.0, 75: 9.0
    ]
    
    let keyWidth: CGFloat = 40
    let keyHeight: CGFloat = 140
    let keySpacing: CGFloat = 1
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background board
            let totalWidth = CGFloat(whiteKeys.count) * keyWidth + CGFloat(whiteKeys.count - 1) * keySpacing + 10
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "1A0508"))
                .shadow(color: .black, radius: 10, x: 0, y: 5)
                .frame(width: totalWidth, height: keyHeight + 10)
            
            // White keys
            HStack(spacing: keySpacing) {
                ForEach(whiteKeys, id: \.self) { note in
                    let isPressed = isNoteActive(note)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isPressed ? Color(hex: "E0D4C3") : Color(hex: "FDFBEE")) // Ivory
                        .frame(width: keyWidth, height: keyHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(isPressed ? 0.0 : 0.4), radius: isPressed ? 0 : 2, x: 0, y: isPressed ? 0 : 2)
                        .offset(y: isPressed ? 4 : 0)
                }
            }
            .padding(5)
            
            // Black Keys
            ForEach(Array(blackKeys.keys), id: \.self) { note in
                if let position = blackKeys[note] {
                    let isPressed = isNoteActive(note)
                    // The center of the boundary between white key (position-1) and white key (position)
                    let leftOffset = 5.0 + position * (keyWidth + keySpacing) - (keySpacing / 2.0)
                    let blackKeyWidth = keyWidth * 0.65
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isPressed ? Color.black : Color(hex: "222222"))
                        .frame(width: blackKeyWidth, height: keyHeight * 0.6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3).stroke(Color.black, lineWidth: 1)
                        )
                        .shadow(color: .black, radius: isPressed ? 0 : 4, x: 0, y: isPressed ? 0 : 4)
                        .offset(x: leftOffset - (blackKeyWidth / 2.0), y: 5 + (isPressed ? 3 : 0))
                }
            }
        }
    }
    
    private func isNoteActive(_ note: UInt8) -> Bool {
        // We do modulo 12 math so playing ANY 'C' lights up the 'C' key visually
        let noteClass = note % 12
        return activeNotes.contains(where: { $0 % 12 == noteClass })
    }
}

struct RegisterButton: View {
    let label: String
    let isActive: Bool
    
    var body: some View {
        RegisterButtonStyle(label: label, isActive: isActive, activeColor: Color(hex: "D4AF37"))
    }
}

struct RegisterButtonStyle: View {
    let label: String
    let isActive: Bool
    let activeColor: Color
    
    var body: some View {
        HStack {
            // The mechanical button
            Circle()
                .fill(isActive ? activeColor : Color(hex: "E0D4C3")) // Ivory when inactive
                .frame(width: 18, height: 18)
                .shadow(color: isActive ? activeColor.opacity(0.8) : .black.opacity(0.6), radius: isActive ? 4 : 2, x: 0, y: isActive ? 0 : 2)
                .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 1))
            
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .serif))
                .foregroundColor(isActive ? activeColor : Color(hex: "FFF7D6").opacity(0.6))
                .frame(width: 70, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}

struct OctaveView: View {
    let octave: Int
    var body: some View {
        VStack(spacing: 8) {
            Text("OCTAVE")
                .font(.system(size: 10, weight: .bold, design: .serif))
                .foregroundColor(Color(hex: "D4AF37"))
                .tracking(1)
            
            HStack(spacing: 6) {
                ForEach(2..<7, id: \.self) { i in 
                    Circle()
                        .fill(i == octave ? Color(hex: "D4AF37") : Color.black)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color(hex: "D4AF37").opacity(0.5), lineWidth: 1))
                        .shadow(color: i == octave ? Color(hex: "D4AF37") : .clear, radius: 3)
                }
            }
            Text("C\(octave)")
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(Color(hex: "FFF7D6"))
        }
        .padding(12)
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
}

struct KeyboardHintView: View {
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TREBLE KEYS").font(.system(size: 9, weight: .bold, design: .serif)).foregroundColor(Color(hex: "D4AF37"))
                Text("Black keys: W E   T Y U   O P").font(.system(.caption, design: .monospaced))
                Text("White keys: A S D F G H J K L ;").font(.system(.caption, design: .monospaced))
            }
            Divider().frame(height: 30).background(Color(hex: "D4AF37").opacity(0.3))
            VStack(alignment: .leading, spacing: 4) {
                Text("CONTROLS").font(.system(size: 9, weight: .bold, design: .serif)).foregroundColor(Color(hex: "D4AF37"))
                Text("Z / X: Octave Shift   Tab: Sustain").font(.system(.caption, design: .monospaced))
                Text("Space: Air Valve      Enter: Loop").font(.system(.caption, design: .monospaced))
            }
        }
        .foregroundColor(Color(hex: "FFF7D6").opacity(0.7))
        .padding(15)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "D4AF37").opacity(0.2), lineWidth: 1))
    }
}

// Extensions Removed since we used a pure SwiftUI clipping approach.

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
