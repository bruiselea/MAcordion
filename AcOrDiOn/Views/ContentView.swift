import SwiftUI
import AppKit

public enum BellowsMode {
    case hinge
    case breath
    case shisha

    fileprivate func makeSource() -> BellowsSource {
        switch self {
        case .hinge: return HingeMonitor()
        case .breath: return BreathMonitor()
        case .shisha: return ShishaMonitor()
        }
    }

    fileprivate var bellowsLabel: String {
        switch self {
        case .hinge:
            return L10n.string("bellows.hinge", fallback: "Hinge / Bellows")
        case .breath:
            return L10n.string("bellows.breath", fallback: "Breath / Bellows")
        case .shisha:
            return L10n.string("bellows.shisha", fallback: "Shisha / Bellows")
        }
    }

    fileprivate var onboardingBody: String {
        switch self {
        case .hinge:
            return L10n.string(
                "onboarding.hinge.body",
                fallback: "Open and close your MacBook display to stretch the on-screen bellows. The speed of the movement controls expression."
            )
        case .breath:
            return L10n.string(
                "onboarding.breath.body",
                fallback: "Blow gently toward the microphone to move air through the instrument and shape the expression."
            )
        case .shisha:
            return L10n.string(
                "onboarding.shisha.body",
                fallback: "Draw or blow through the connected pressure sensor to move the bellows and shape the expression."
            )
        }
    }
}

public struct ContentView: View {
    private let mode: BellowsMode
    @StateObject private var viewModel: AccordionViewModel
    @EnvironmentObject private var keyboardHandler: KeyboardHandler
    @AppStorage("hasSeenHowToPlay") private var hasSeenHowToPlay = false

    public init(mode: BellowsMode = .hinge) {
        self.mode = mode
        _viewModel = StateObject(wrappedValue: AccordionViewModel(bellowsSource: mode.makeSource()))
    }

    public var body: some View {
        ZStack {
            StudioPalette.background
                .ignoresSafeArea()

            GeometryReader { geometry in
                VStack(spacing: 0) {
                    StudioHeader(
                        onHelp: {
                            withAnimation(.easeOut(duration: 0.18)) {
                                hasSeenHowToPlay = false
                            }
                        }
                    )

                    Divider()
                        .overlay(StudioPalette.separator)

                    HStack(spacing: 26) {
                        PerformanceControls(
                            sustainOn: viewModel.appState.isSustainOn,
                            airValveOpen: viewModel.appState.isAirValveOpen,
                            octave: viewModel.appState.currentOctave,
                            onSustain: { viewModel.handleKeyDown(48) },
                            onAirValve: { isOpen in
                                if isOpen {
                                    viewModel.handleKeyDown(49)
                                } else {
                                    viewModel.handleKeyUp(49)
                                }
                            },
                            onOctaveDown: { viewModel.handleKeyDown(6) },
                            onOctaveUp: { viewModel.handleKeyDown(7) }
                        )
                        .frame(width: min(230, max(205, geometry.size.width * 0.18)))

                        VerticalBellowsView(
                            mode: mode,
                            angle: displayAngle,
                            pressure: viewModel.appState.pressure
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        AirPressureMeter(level: displayExpression)
                            .frame(width: 72)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 20)
                    .frame(maxHeight: .infinity)

                    PianoKeyboardView(
                        activeNotes: viewModel.appState.activeNotes,
                        octave: viewModel.appState.currentOctave,
                        onKeyDown: viewModel.handleKeyDown,
                        onKeyUp: viewModel.handleKeyUp
                    )
                    .frame(height: min(250, max(190, geometry.size.height * 0.29)))
                    .padding(.horizontal, 22)
                    .padding(.bottom, 18)
                }
            }
            .blur(radius: hasSeenHowToPlay ? 0 : 8)

            if !hasSeenHowToPlay {
                StudioPalette.background.opacity(0.78)
                    .ignoresSafeArea()

                HowToPlayView(bodyText: mode.onboardingBody) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        hasSeenHowToPlay = true
                    }
                }
                .transition(.scale(scale: 0.98).combined(with: .opacity))
            }
        }
        .onAppear(perform: setup)
        .onDisappear(perform: cleanup)
    }

    private var displayAngle: Double {
        if mode == .hinge {
            return viewModel.appState.currentAngle
        }
        return 30 + viewModel.appState.pressure * 110
    }

    private var displayExpression: Double {
        if viewModel.isKeyboardOnlyMode {
            return viewModel.appState.activeNotes.isEmpty ? 0 : 0.72
        }
        return max(Double(viewModel.appState.velocity) / 127, viewModel.appState.pressure * 0.25)
    }

    private func setup() {
        viewModel.start()
        keyboardHandler.onKeyDown = viewModel.handleKeyDown
        keyboardHandler.onKeyUp = viewModel.handleKeyUp
    }

    private func cleanup() {
        viewModel.stop()
    }
}

public struct DiagnosticsSettingsView: View {
    private let mode: BellowsMode
    @ObservedObject private var diagnostics = DiagnosticsStore.shared

    public init(mode: BellowsMode) {
        self.mode = mode
    }

    public var body: some View {
        Form {
            Section(L10n.string("settings.sensor", fallback: "Sensor")) {
                LabeledContent(
                    L10n.string("settings.source", fallback: "Source"),
                    value: sourceName
                )
                LabeledContent(L10n.string("settings.status", fallback: "Status")) {
                    Label(
                        diagnostics.isConnected
                            ? L10n.string("settings.connected", fallback: "Connected")
                            : L10n.string("settings.unavailable", fallback: "Unavailable"),
                        systemImage: diagnostics.isConnected
                            ? "checkmark.circle.fill"
                            : "exclamationmark.circle"
                    )
                    .foregroundStyle(
                        diagnostics.isConnected
                            ? StudioPalette.connected
                            : StudioPalette.secondaryText
                    )
                }

                if mode == .hinge {
                    LabeledContent(
                        L10n.string("settings.hingeAngle", fallback: "Hinge angle"),
                        value: "\(Int(diagnostics.angle.rounded()))°"
                    )
                }

                LabeledContent(
                    L10n.string("settings.airPressure", fallback: "Air pressure"),
                    value: "\(Int(min(1, max(0, diagnostics.pressure)) * 100))%"
                )
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420, height: 260)
    }

    private var sourceName: String {
        switch mode {
        case .hinge:
            return L10n.string(
                "settings.source.hinge",
                fallback: "MacBook hinge sensor"
            )
        case .breath:
            return L10n.string(
                "settings.source.breath",
                fallback: "Built-in microphone"
            )
        case .shisha:
            return L10n.string(
                "settings.source.shisha",
                fallback: "Shisha pressure sensor"
            )
        }
    }
}

// MARK: - Header

private struct StudioHeader: View {
    let onHelp: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: "waveform.path")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(StudioPalette.accent)
                    .frame(width: 34, height: 34)
                    .background(StudioPalette.surfaceRaised, in: RoundedRectangle(cornerRadius: 9))

                Text("MAcordion")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(StudioPalette.primaryText)
            }

            Spacer()

            Button(action: onHelp) {
                Label(
                    L10n.string("header.help", fallback: "Help"),
                    systemImage: "questionmark.circle"
                )
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(StudioPalette.secondaryText)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .accessibilityHint(
                L10n.string(
                    "header.help.hint",
                    fallback: "Shows keyboard controls and playing instructions"
                )
            )
        }
        .padding(.horizontal, 28)
        .frame(height: 68)
        .background(StudioPalette.header)
    }
}

// MARK: - Controls

private struct PerformanceControls: View {
    let sustainOn: Bool
    let airValveOpen: Bool
    let octave: Int
    let onSustain: () -> Void
    let onAirValve: (Bool) -> Void
    let onOctaveDown: () -> Void
    let onOctaveUp: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ToggleControl(
                title: L10n.string("control.sustain", fallback: "Sustain"),
                shortcut: "Tab",
                systemImage: "waveform",
                isActive: sustainOn,
                action: onSustain
            )

            Divider().overlay(StudioPalette.separator)

            MomentaryControl(
                title: L10n.string("control.airValve", fallback: "Air Valve"),
                shortcut: L10n.string("control.holdSpace", fallback: "Hold Space"),
                systemImage: "wind",
                isActive: airValveOpen,
                onPressedChange: onAirValve
            )

            Divider()
                .overlay(StudioPalette.separator)
                .padding(.vertical, 18)

            VStack(spacing: 12) {
                Text(L10n.string("control.octave", fallback: "Octave"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(StudioPalette.secondaryText)

                HStack(spacing: 18) {
                    RoundIconButton(
                        systemImage: "minus",
                        accessibilityLabel: L10n.string(
                            "control.octaveDown",
                            fallback: "Octave down"
                        ),
                        action: onOctaveDown
                    )
                    .disabled(octave <= 0)

                    Text("C\(octave)")
                        .font(.system(size: 31, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(StudioPalette.primaryText)
                        .frame(minWidth: 52)

                    RoundIconButton(
                        systemImage: "plus",
                        accessibilityLabel: L10n.string(
                            "control.octaveUp",
                            fallback: "Octave up"
                        ),
                        action: onOctaveUp
                    )
                    .disabled(octave >= 8)
                }

                Text("Z / X")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(StudioPalette.tertiaryText)
            }
            .padding(.bottom, 6)
        }
        .padding(16)
        .background(StudioPalette.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(StudioPalette.separator, lineWidth: 1)
        }
    }
}

private struct ToggleControl: View {
    let title: String
    let shortcut: String
    let systemImage: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isActive ? StudioPalette.accent : StudioPalette.secondaryText)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(StudioPalette.primaryText)
                    Text(shortcut)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(StudioPalette.tertiaryText)
                }

                Spacer()

                StateSwitch(isActive: isActive)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
        .accessibilityValue(
            isActive
                ? L10n.string("state.on", fallback: "On")
                : L10n.string("state.off", fallback: "Off")
        )
    }
}

private struct MomentaryControl: View {
    let title: String
    let shortcut: String
    let systemImage: String
    let isActive: Bool
    let onPressedChange: (Bool) -> Void
    @State private var pointerIsDown = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isActive ? StudioPalette.accent : StudioPalette.secondaryText)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(StudioPalette.primaryText)
                Text(shortcut)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(StudioPalette.tertiaryText)
            }

            Spacer()

            StateSwitch(isActive: isActive)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 13)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !pointerIsDown else { return }
                    pointerIsDown = true
                    onPressedChange(true)
                }
                .onEnded { _ in
                    pointerIsDown = false
                    onPressedChange(false)
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(
            isActive
                ? L10n.string("state.open", fallback: "Open")
                : L10n.string("state.closed", fallback: "Closed")
        )
        .accessibilityHint(
            L10n.string(
                "control.airValve.hint",
                fallback: "Press and hold to open"
            )
        )
    }
}

private struct StateSwitch: View {
    let isActive: Bool

    var body: some View {
        ZStack(alignment: isActive ? .trailing : .leading) {
            Capsule()
                .fill(isActive ? StudioPalette.accent : StudioPalette.controlTrack)
                .frame(width: 46, height: 26)

            Circle()
                .fill(StudioPalette.switchThumb)
                .frame(width: 20, height: 20)
                .padding(3)
        }
        .overlay {
            Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .animation(.easeOut(duration: 0.14), value: isActive)
    }
}

private struct RoundIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(StudioPalette.primaryText)
                .frame(width: 38, height: 38)
                .background(StudioPalette.surfaceRaised, in: Circle())
                .overlay {
                    Circle().stroke(StudioPalette.separator, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Bellows

private struct VerticalBellowsView: View {
    let mode: BellowsMode
    let angle: Double
    let pressure: Double

    private var clampedAngle: Double {
        min(140, max(30, angle))
    }

    private var normalizedAngle: Double {
        (clampedAngle - 30) / 110
    }

    var body: some View {
        GeometryReader { geometry in
            let availableHeight = max(180, geometry.size.height)
            let bellowsHeight = min(
                availableHeight,
                155 + CGFloat(normalizedAngle) * max(0, availableHeight - 155)
            )

            VStack {
                Spacer(minLength: 0)

                BellowsBody(pressure: pressure)
                    .frame(height: bellowsHeight)
                    // The physical hinge is already a live control signal.
                    // Render its linear height mapping without interpolation.
                    .transaction { transaction in
                        transaction.animation = nil
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(mode.bellowsLabel)
        .accessibilityValue(
            L10n.format(
                "accessibility.angle",
                fallback: "%d degrees",
                Int(clampedAngle.rounded())
            )
        )
    }
}

private struct BellowsBody: View {
    let pressure: Double
    private let foldCount = 14

    var body: some View {
        GeometryReader { geometry in
            let plateHeight: CGFloat = 31
            let accentHeight: CGFloat = 5
            let foldsHeight = max(
                60,
                geometry.size.height - plateHeight * 2 - accentHeight * 2
            )
            let foldHeight = foldsHeight / CGFloat(foldCount)

            VStack(spacing: 0) {
                BellowsEndPlate()
                    .frame(height: plateHeight)

                StudioPalette.accent
                    .opacity(0.7 + min(1, pressure) * 0.3)
                    .frame(height: accentHeight)
                    .padding(.horizontal, 13)

                VStack(spacing: -1) {
                    ForEach(0..<foldCount, id: \.self) { index in
                        BellowsFoldShape(inset: index.isMultiple(of: 2) ? 6 : 13)
                            .fill(
                                LinearGradient(
                                    colors: index.isMultiple(of: 2)
                                        ? [Color(hex: "2C3035"), Color(hex: "0D0F11")]
                                        : [Color(hex: "101215"), Color(hex: "25292D")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay {
                                BellowsFoldShape(inset: index.isMultiple(of: 2) ? 6 : 13)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 0.7)
                            }
                            .frame(height: foldHeight + 1)
                    }
                }
                .frame(height: foldsHeight)

                StudioPalette.accent
                    .opacity(0.7 + min(1, pressure) * 0.3)
                    .frame(height: accentHeight)
                    .padding(.horizontal, 13)

                BellowsEndPlate()
                    .frame(height: plateHeight)
            }
            .shadow(color: Color.black.opacity(0.38), radius: 14, y: 8)
        }
    }
}

private struct BellowsEndPlate: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(StudioPalette.surfaceRaised)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.13), lineWidth: 1)
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.horizontal, 8)
                    .padding(.top, 3)
            }
    }
}

private struct BellowsFoldShape: Shape {
    let inset: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: inset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY))
        path.addLine(to: CGPoint(x: inset, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct AirPressureMeter: View {
    let level: Double

    private var clampedLevel: Double {
        min(1, max(0, level))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(StudioPalette.controlTrack)

                Capsule()
                    .fill(StudioPalette.accent)
                    .frame(height: max(8, geometry.size.height * CGFloat(clampedLevel)))
            }
            .frame(width: 25)
            .overlay {
                Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 22)
        }
        .background(StudioPalette.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(StudioPalette.separator, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            L10n.string("settings.airPressure", fallback: "Air pressure")
        )
        .accessibilityValue(
            L10n.format(
                "accessibility.pressure",
                fallback: "%d percent",
                Int(clampedLevel * 100)
            )
        )
    }
}

// MARK: - Piano

private struct PianoKeySpec: Identifiable {
    let keyCode: UInt16
    let keyLabel: String
    let noteLabel: String
    let semitoneOffset: Int
    let boundary: CGFloat?

    var id: UInt16 { keyCode }
}

private struct PianoKeyboardView: View {
    let activeNotes: Set<UInt8>
    let octave: Int
    let onKeyDown: (UInt16) -> Void
    let onKeyUp: (UInt16) -> Void

    private let whiteKeys = [
        PianoKeySpec(keyCode: 0, keyLabel: "A", noteLabel: "C", semitoneOffset: 0, boundary: nil),
        PianoKeySpec(keyCode: 1, keyLabel: "S", noteLabel: "D", semitoneOffset: 2, boundary: nil),
        PianoKeySpec(keyCode: 2, keyLabel: "D", noteLabel: "E", semitoneOffset: 4, boundary: nil),
        PianoKeySpec(keyCode: 3, keyLabel: "F", noteLabel: "F", semitoneOffset: 5, boundary: nil),
        PianoKeySpec(keyCode: 5, keyLabel: "G", noteLabel: "G", semitoneOffset: 7, boundary: nil),
        PianoKeySpec(keyCode: 4, keyLabel: "H", noteLabel: "A", semitoneOffset: 9, boundary: nil),
        PianoKeySpec(keyCode: 38, keyLabel: "J", noteLabel: "B", semitoneOffset: 11, boundary: nil),
        PianoKeySpec(keyCode: 40, keyLabel: "K", noteLabel: "C", semitoneOffset: 12, boundary: nil),
        PianoKeySpec(keyCode: 37, keyLabel: "L", noteLabel: "D", semitoneOffset: 14, boundary: nil),
        PianoKeySpec(keyCode: 41, keyLabel: ";", noteLabel: "E", semitoneOffset: 16, boundary: nil)
    ]

    private let blackKeys = [
        PianoKeySpec(keyCode: 13, keyLabel: "W", noteLabel: "C♯", semitoneOffset: 1, boundary: 1),
        PianoKeySpec(keyCode: 14, keyLabel: "E", noteLabel: "D♯", semitoneOffset: 3, boundary: 2),
        PianoKeySpec(keyCode: 17, keyLabel: "T", noteLabel: "F♯", semitoneOffset: 6, boundary: 4),
        PianoKeySpec(keyCode: 16, keyLabel: "Y", noteLabel: "G♯", semitoneOffset: 8, boundary: 5),
        PianoKeySpec(keyCode: 32, keyLabel: "U", noteLabel: "A♯", semitoneOffset: 10, boundary: 6),
        PianoKeySpec(keyCode: 31, keyLabel: "O", noteLabel: "C♯", semitoneOffset: 13, boundary: 8),
        PianoKeySpec(keyCode: 35, keyLabel: "P", noteLabel: "D♯", semitoneOffset: 15, boundary: 9)
    ]

    var body: some View {
        GeometryReader { geometry in
            let whiteWidth = geometry.size.width / CGFloat(whiteKeys.count)
            let blackWidth = min(58, whiteWidth * 0.56)
            let whiteHeight = geometry.size.height
            let blackHeight = geometry.size.height * 0.62

            ZStack(alignment: .topLeading) {
                HStack(spacing: 2) {
                    ForEach(whiteKeys) { key in
                        PlayablePianoKey(
                            spec: key,
                            isBlack: false,
                            isActive: isActive(key),
                            onKeyDown: onKeyDown,
                            onKeyUp: onKeyUp
                        )
                        .frame(width: whiteWidth - 1.8, height: whiteHeight)
                    }
                }

                ForEach(blackKeys) { key in
                    if let boundary = key.boundary {
                        PlayablePianoKey(
                            spec: key,
                            isBlack: true,
                            isActive: isActive(key),
                            onKeyDown: onKeyDown,
                            onKeyUp: onKeyUp
                        )
                        .frame(width: blackWidth, height: blackHeight)
                        .offset(x: boundary * whiteWidth - blackWidth / 2)
                        .zIndex(2)
                    }
                }
            }
            .background(StudioPalette.keyboardBed)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.35), radius: 12, y: 6)
        }
    }

    private func isActive(_ key: PianoKeySpec) -> Bool {
        let baseNote = 60 + (octave - 4) * 12
        let midiNote = UInt8(max(0, min(127, baseNote + key.semitoneOffset)))
        return activeNotes.contains(midiNote)
    }
}

private struct PlayablePianoKey: View {
    let spec: PianoKeySpec
    let isBlack: Bool
    let isActive: Bool
    let onKeyDown: (UInt16) -> Void
    let onKeyUp: (UInt16) -> Void
    @State private var pointerIsDown = false

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: isBlack ? 5 : 4)
                .fill(keyFill)
                .overlay {
                    RoundedRectangle(cornerRadius: isBlack ? 5 : 4)
                        .stroke(keyStroke, lineWidth: 1)
                }

            VStack(spacing: 3) {
                Text(spec.keyLabel)
                    .font(.system(size: isBlack ? 13 : 17, weight: .semibold, design: .monospaced))
                Text(spec.noteLabel)
                    .font(.system(size: isBlack ? 10 : 12, weight: .medium))
                    .opacity(0.62)
            }
            .foregroundStyle(isBlack ? Color.white : StudioPalette.keyLabel)
            .padding(.bottom, isBlack ? 11 : 14)
        }
        .offset(y: isActive || pointerIsDown ? 3 : 0)
        .shadow(
            color: Color.black.opacity(isBlack && !isActive ? 0.55 : 0.16),
            radius: isBlack ? 4 : 1,
            y: isBlack ? 4 : 1
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !pointerIsDown else { return }
                    pointerIsDown = true
                    onKeyDown(spec.keyCode)
                }
                .onEnded { _ in
                    pointerIsDown = false
                    onKeyUp(spec.keyCode)
                }
        )
        .animation(.easeOut(duration: 0.08), value: isActive)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            L10n.format(
                "accessibility.key",
                fallback: "%@, keyboard key %@",
                spec.noteLabel,
                spec.keyLabel
            )
        )
        .accessibilityValue(
            isActive
                ? L10n.string("state.playing", fallback: "Playing")
                : L10n.string("state.notPlaying", fallback: "Not playing")
        )
    }

    private var keyFill: Color {
        if isBlack {
            return isActive || pointerIsDown ? Color(hex: "33383D") : StudioPalette.blackKey
        }
        return isActive || pointerIsDown ? StudioPalette.activeWhiteKey : StudioPalette.whiteKey
    }

    private var keyStroke: Color {
        isBlack ? Color.black.opacity(0.8) : Color.black.opacity(0.28)
    }
}

// MARK: - Onboarding

private struct HowToPlayView: View {
    let bodyText: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.string("onboarding.title", fallback: "Play MAcordion"))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(StudioPalette.primaryText)
                    Text(
                        L10n.string(
                            "onboarding.subtitle",
                            fallback: "Your Mac is the instrument."
                        )
                    )
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(StudioPalette.secondaryText)
                }

                Spacer()

                Image(systemName: "waveform.path")
                    .font(.system(size: 31, weight: .semibold))
                    .foregroundStyle(StudioPalette.accent)
            }

            Text(bodyText)
                .font(.system(size: 15))
                .foregroundStyle(StudioPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                InstructionRow(
                    icon: "pianokeys",
                    title: L10n.string("onboarding.playNotes", fallback: "Play notes"),
                    detail: "A–; and W–P"
                )
                Divider().overlay(StudioPalette.separator)
                InstructionRow(
                    icon: "arrow.up.and.down",
                    title: L10n.string(
                        "onboarding.changeOctave",
                        fallback: "Change octave"
                    ),
                    detail: "Z / X"
                )
                Divider().overlay(StudioPalette.separator)
                InstructionRow(
                    icon: "wind",
                    title: L10n.string(
                        "onboarding.openAirValve",
                        fallback: "Open air valve"
                    ),
                    detail: L10n.string("control.holdSpace", fallback: "Hold Space")
                )
                Divider().overlay(StudioPalette.separator)
                InstructionRow(
                    icon: "waveform",
                    title: L10n.string(
                        "onboarding.toggleSustain",
                        fallback: "Toggle sustain"
                    ),
                    detail: "Tab"
                )
            }
            .background(StudioPalette.background, in: RoundedRectangle(cornerRadius: 12))

            Button(action: onDismiss) {
                Text(L10n.string("onboarding.start", fallback: "Start Playing"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(StudioPalette.accent, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(26)
        .frame(width: 460)
        .background(StudioPalette.surfaceRaised, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.5), radius: 30, y: 18)
    }
}

private struct InstructionRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(StudioPalette.accent)
                .frame(width: 25)

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(StudioPalette.primaryText)

            Spacer()

            Text(detail)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(StudioPalette.tertiaryText)
        }
        .padding(.horizontal, 14)
        .frame(height: 45)
    }
}

// MARK: - Palette

private enum StudioPalette {
    static let background = Color(hex: "101214")
    static let header = Color(hex: "15181B")
    static let surface = Color(hex: "1A1D20")
    static let surfaceRaised = Color(hex: "22262A")
    static let separator = Color.white.opacity(0.10)
    static let primaryText = Color(hex: "F4F3EF")
    static let secondaryText = Color(hex: "C4C6C8")
    static let tertiaryText = Color(hex: "858A8E")
    static let accent = Color(hex: "F05A3C")
    static let connected = Color(hex: "55C873")
    static let muted = Color(hex: "7A8084")
    static let controlTrack = Color(hex: "34393D")
    static let switchThumb = Color(hex: "F0EFEB")
    static let keyboardBed = Color(hex: "080A0C")
    static let whiteKey = Color(hex: "F0EEE7")
    static let activeWhiteKey = Color(hex: "D8D5CC")
    static let blackKey = Color(hex: "171A1D")
    static let keyLabel = Color(hex: "202326")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
