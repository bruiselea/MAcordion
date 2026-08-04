import Foundation
import Darwin

/// Reads puff events from the USB-C-to-Shisha sensor (ESP32-C3 + MPXV7002DP)
/// over USB-CDC serial and translates them into bellows velocity.
///
/// Protocol (one event per line, from firmware/esp32c3/shisha_sensor.ino):
///   READY
///   CAL <baseline_mv>
///   PUFF_START <intensity 0-100> <INHALE|BLOW>
///   PUFF_LVL   <intensity 0-100> <INHALE|BLOW>     (~ every 50ms)
///   PUFF_END   <INHALE|BLOW>
///   DBG <mv> <delta>                               (debug only)
///
/// Intensity (0–100) is mapped linearly into the same deg/sec-equivalent
/// scale that VelocityCalculator expects (~0–220). Direction (INHALE vs
/// BLOW) is ignored — like a real accordion, both push and pull through
/// the reeds produce sound.
final class ShishaMonitor: ObservableObject, BellowsSource {
    @Published private(set) var publishedVelocity: Double = 0
    /// 0–1 normalised intensity, published for ViewModel's directExpression path.
    @Published private(set) var publishedExpression: Double = 0
    @Published var isSensorAvailable: Bool = false

    var bellowsVelocity: Double { publishedVelocity }
    var directExpression: Double? { publishedExpression }

    private var fileDescriptor: Int32 = -1
    private let readQueue = DispatchQueue(label: "shisha.read", qos: .userInteractive)
    private var readingActive = false
    private var lineBuffer = ""
    private var hasStartedDetection = false
    private var resolvedPort: String?

    /// 100 (max puff intensity from firmware) maps to ~220, which is the
    /// same ceiling HingeMonitor produces when the lid is pumped vigorously.
    /// That keeps the VelocityCalculator curve and the AudioEngine envelope
    /// calibration unchanged across all three bellows sources.
    private let intensityGain: Double = 2.2

    // Diagnostic file logger — print() in a SwiftUI/AppKit app gets fully
    // buffered when stdout isn't a TTY, so we tee important events to a
    // file we can tail externally.
    private static let debugLogPath = "/tmp/macordion_shisha_debug.log"
    private static let debugLogHandle: FileHandle? = {
        FileManager.default.createFile(atPath: debugLogPath, contents: nil)
        return FileHandle(forWritingAtPath: debugLogPath)
    }()
    private static func dbg(_ s: String) {
        guard let h = debugLogHandle, let data = "\(Date()) \(s)\n".data(using: .utf8) else { return }
        try? h.write(contentsOf: data)
    }
    private var puffLogCounter = 0

    init() {
        Self.dbg("ShishaMonitor: Initialized")
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - BellowsSource

    func detectAsync(completion: @escaping (Bool) -> Void) {
        guard !hasStartedDetection else { return }
        hasStartedDetection = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let port = self.locatePort()
            DispatchQueue.main.async {
                self.resolvedPort = port
                self.isSensorAvailable = (port != nil)
                if let port = port {
                    Self.dbg("ShishaMonitor: Detected device at \(port)")
                } else {
                    Self.dbg("ShishaMonitor: No shisha device found — keyboard-only mode")
                }
                completion(self.isSensorAvailable)
            }
        }
    }

    func startMonitoring() {
        guard fileDescriptor < 0, let port = resolvedPort else {
            Self.dbg("ShishaMonitor: startMonitoring skipped (fd=\(fileDescriptor), port=\(resolvedPort ?? "nil"))")
            return
        }
        guard openSerial(path: port) else {
            DispatchQueue.main.async { self.isSensorAvailable = false }
            return
        }
        attachReadSource()
        Self.dbg("ShishaMonitor: Streaming from \(port)")
    }

    func stopMonitoring() {
        readingActive = false
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
        lineBuffer = ""
        DispatchQueue.main.async { [weak self] in
            self?.publishedVelocity = 0
            self?.publishedExpression = 0
        }
        Self.dbg("ShishaMonitor: Stopped")
    }

    // MARK: - Port discovery

    private func locatePort() -> String? {
        // Manual override: `SHISHA_PORT=/dev/cu.usbmodemXXXX swift run …`
        if let env = ProcessInfo.processInfo.environment["SHISHA_PORT"],
           !env.isEmpty,
           FileManager.default.fileExists(atPath: env) {
            return env
        }

        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: "/dev") else {
            return nil
        }
        // ESP32-C3 native USB-CDC enumerates as /dev/cu.usbmodem* on macOS.
        // Prefer cu.* over tty.* (non-blocking call-out side).
        let cu = entries.filter { $0.hasPrefix("cu.usbmodem") }.sorted()
        if let first = cu.first { return "/dev/" + first }
        let tty = entries.filter { $0.hasPrefix("tty.usbmodem") }.sorted()
        if let first = tty.first { return "/dev/" + first }
        return nil
    }

    // MARK: - Serial I/O

    private func openSerial(path: String) -> Bool {
        // Plain blocking O_RDONLY — same I/O profile that `cat /dev/cu.usbmodem*`
        // uses successfully. Earlier attempts with O_NONBLOCK + cfmakeraw +
        // CLOCAL on this USB-CDC node never delivered any bytes to read(),
        // even while `cat` on the same node streamed PUFF events fine.
        let fd = open(path, O_RDONLY)
        guard fd >= 0 else {
            Self.dbg("ShishaMonitor: open(\(path)) failed errno=\(errno)")
            return false
        }
        fileDescriptor = fd
        return true
    }

    /// Blocking read loop on a dedicated background queue. Matches the I/O
    /// profile of `cat` — no termios, no NONBLOCK, no kqueue source — which
    /// is the only configuration that actually delivered bytes on this
    /// USB-CDC TTY. close() from stopMonitoring breaks the blocked read
    /// with EBADF, which we treat as a clean exit.
    private func attachReadSource() {
        readingActive = true
        readQueue.async { [weak self] in
            guard let self = self else { return }
            var buffer = [UInt8](repeating: 0, count: 1024)
            var bytesRead = 0
            var lastReportedBytes = 0
            Self.dbg("ShishaMonitor: read loop starting fd=\(self.fileDescriptor)")
            while self.readingActive {
                let fd = self.fileDescriptor
                if fd < 0 { break }
                let n = buffer.withUnsafeMutableBufferPointer { ptr -> Int in
                    read(fd, ptr.baseAddress, ptr.count)
                }
                if n > 0 {
                    bytesRead += n
                    if bytesRead - lastReportedBytes > 1024 {
                        Self.dbg("ShishaMonitor: \(bytesRead) total bytes read")
                        lastReportedBytes = bytesRead
                    }
                    // First few reads: dump raw bytes (hex + ascii) so we can
                    // see what we're actually getting before any line parsing.
                    if bytesRead < 256 {
                        let slice = buffer.prefix(min(n, 64))
                        let hex = slice.map { String(format: "%02x", $0) }.joined(separator: " ")
                        let ascii = String(bytes: slice, encoding: .ascii) ?? "<non-ascii>"
                        Self.dbg("read n=\(n) hex=\(hex) ascii=\(ascii.debugDescription)")
                    }
                    if let chunk = String(bytes: buffer.prefix(n), encoding: .utf8) {
                        self.consume(chunk: chunk)
                    } else {
                        Self.dbg("ShishaMonitor: UTF-8 decode failed for n=\(n) bytes — falling back to ASCII")
                        if let chunk = String(bytes: buffer.prefix(n), encoding: .ascii) {
                            self.consume(chunk: chunk)
                        }
                    }
                } else if n == 0 {
                    // Short read-EOF on a USB-CDC TTY does NOT necessarily
                    // mean the device is gone — Arduino-style firmware can
                    // briefly drop Serial when the host re-enumerates after
                    // DTR transitions, then come back. Flipping into
                    // keyboard-only mode here permanently strands us at
                    // velocity 100. Instead, just sleep, reopen, and
                    // continue. We keep isSensorAvailable=true so the
                    // direct-expression path stays active.
                    Self.dbg("ShishaMonitor: read returned 0 — attempting reopen")
                    close(self.fileDescriptor)
                    self.fileDescriptor = -1
                    usleep(200_000)  // 200ms back-off
                    if let port = self.resolvedPort, self.openSerial(path: port) {
                        Self.dbg("ShishaMonitor: reopened fd=\(self.fileDescriptor)")
                        DispatchQueue.main.async { [weak self] in
                            self?.publishedVelocity = 0
                            self?.publishedExpression = 0
                        }
                        continue
                    } else {
                        Self.dbg("ShishaMonitor: reopen failed — bailing read loop")
                        return
                    }
                } else {
                    // EBADF from a close() while we're blocked is the normal
                    // shutdown signal. Anything else is a real error.
                    if errno != EBADF && errno != EINTR {
                        Self.dbg("ShishaMonitor: read errno=\(errno)")
                    }
                    return
                }
            }
            Self.dbg("ShishaMonitor: read loop exiting (readingActive=false)")
        }
    }

    // MARK: - Parsing

    private var rawLineLogCount = 0

    private func consume(chunk: String) {
        lineBuffer.append(chunk)
        while let nl = lineBuffer.range(of: "\n") {
            let line = String(lineBuffer[..<nl.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            lineBuffer.removeSubrange(..<nl.upperBound)
            guard !line.isEmpty else { continue }
            if rawLineLogCount < 30 {
                Self.dbg("raw: \(line)")
                rawLineLogCount += 1
            }
            handle(line: line)
        }
    }

    private func handle(line: String) {
        let parts = line.split(separator: " ")
        guard let tagSub = parts.first else { return }
        let tag = String(tagSub)

        switch tag {
        case "PUFF_START", "PUFF_LVL":
            guard parts.count >= 2, let intensity = Double(parts[1]) else { return }
            let clamped = max(0, min(100, intensity))
            let target = clamped * intensityGain
            let expression = clamped / 100.0
            puffLogCounter += 1
            if puffLogCounter % 10 == 1 || tag == "PUFF_START" {
                Self.dbg("ShishaMonitor: \(tag) intensity=\(Int(clamped)) → vel=\(Int(target)) expr=\(String(format: "%.2f", expression))")
            }
            DispatchQueue.main.async { [weak self] in
                self?.publishedVelocity = target
                self?.publishedExpression = expression
            }

        case "PUFF_END":
            Self.dbg("ShishaMonitor: PUFF_END")
            DispatchQueue.main.async { [weak self] in
                self?.publishedVelocity = 0
                self?.publishedExpression = 0
            }

        case "READY", "CAL", "DBG":
            Self.dbg("ShishaMonitor: \(line)")

        default:
            break
        }
    }
}
