import Foundation

/// Monitors the MacBook hinge angle sensor using periodic Python calls
/// Simplified version to prevent freezing
class HingeMonitor: ObservableObject {
    @Published var currentAngle: Double = 90.0  // Default angle
    @Published var angularVelocity: Double = 0
    
    private var timer: Timer?
    private var lastAngle: Double = 90.0
    private var lastTimestamp: Date = Date()
    private var isUpdating = false
    
    private let pythonPath = "/usr/local/Caskroom/miniconda/base/bin/python3"
    
    init() {
        print("HingeMonitor: Initialized")
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        print("HingeMonitor: Starting monitoring at 5Hz")
        
        // Poll at low frequency (5Hz) to prevent freezing
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
        // Prevent overlapping reads
        guard !isUpdating else { return }
        isUpdating = true
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.readAngleSingleShot()
            self?.isUpdating = false
        }
    }
    
    private func readAngleSingleShot() {
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
            // Smooth the velocity
            self.angularVelocity = self.angularVelocity * 0.6 + velocity * 0.4
        }
        
        lastAngle = newAngle
        lastTimestamp = now
    }
}
