import Foundation

/// Monitors the MacBook hinge angle sensor.
/// Falls back to "keyboard-only" mode if the sensor is not available.
class HingeMonitor: ObservableObject {
    @Published var currentAngle: Double = 90.0
    @Published var angularVelocity: Double = 0
    @Published var isSensorAvailable: Bool = false
    
    private var timer: Timer?
    private var lastAngle: Double = 90.0
    private var lastTimestamp: Date = Date()
    private var isUpdating = false
    
    /// Try multiple common Python paths
    private let pythonPaths = [
        "/usr/bin/python3",
        "/usr/local/bin/python3",
        "/opt/homebrew/bin/python3",
        "/usr/local/Caskroom/miniconda/base/bin/python3"
    ]
    
    private var activePythonPath: String?
    
    init() {
        print("HingeMonitor: Initialized")
        detectPython()
    }
    
    deinit {
        stopMonitoring()
    }
    
    /// Find a working Python with pybooklid installed
    private func detectPython() {
        for path in pythonPaths {
            if FileManager.default.fileExists(atPath: path) {
                // Check if pybooklid is available
                let task = Process()
                task.executableURL = URL(fileURLWithPath: path)
                task.arguments = ["-c", "from pybooklid import read_lid_angle; print(read_lid_angle())"]
                task.standardOutput = FileHandle.nullDevice
                task.standardError = FileHandle.nullDevice
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    if task.terminationStatus == 0 {
                        activePythonPath = path
                        isSensorAvailable = true
                        print("HingeMonitor: Found working Python at \(path)")
                        return
                    }
                } catch {
                    continue
                }
            }
        }
        
        print("HingeMonitor: No hinge sensor available — running in keyboard-only mode")
        isSensorAvailable = false
    }
    
    func startMonitoring() {
        guard isSensorAvailable, let _ = activePythonPath else {
            print("HingeMonitor: Skipping — keyboard-only mode active")
            return
        }
        
        print("HingeMonitor: Starting monitoring at 5Hz")
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.readAngleAsync()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        print("HingeMonitor: Stopped")
    }
    
    private func readAngleAsync() {
        guard !isUpdating else { return }
        isUpdating = true
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.readAngleSingleShot()
            self?.isUpdating = false
        }
    }
    
    private func readAngleSingleShot() {
        guard let pythonPath = activePythonPath else { return }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: pythonPath)
        task.arguments = ["-c", "from pybooklid import read_lid_angle; print(read_lid_angle())"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8),
               let angle = Double(output.trimmingCharacters(in: .whitespacesAndNewlines)) {
                self.updateAngle(angle)
            }
        } catch {
            print("HingeMonitor: Error reading angle: \(error)")
        }
    }
    
    private func updateAngle(_ newAngle: Double) {
        let now = Date()
        let deltaTime = now.timeIntervalSince(lastTimestamp)
        
        guard deltaTime > 0.05 else { return }
        
        let deltaAngle = abs(newAngle - lastAngle)
        let velocity = deltaAngle / deltaTime
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentAngle = newAngle
            self.angularVelocity = self.angularVelocity * 0.6 + velocity * 0.4
        }
        
        lastAngle = newAngle
        lastTimestamp = now
    }
}
