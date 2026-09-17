import Foundation
import Combine

/// Monitors MacBook hinge angle using pybooklid Python library
class HingeSensor: ObservableObject {
    static let shared = HingeSensor()
    
    @Published var currentAngle: Double = 90.0
    @Published var angularVelocity: Double = 0.0
    @Published var volume: Double = 0.5
    
    private var isRunning = false
    private var monitorThread: Thread?
    private var angleHistory: [Double] = Array(repeating: 90.0, count: 3)
    
    private let pythonPath = "/usr/local/Caskroom/miniconda/base/bin/python3"
    
    private init() {}
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        
        monitorThread = Thread { [weak self] in
            self?.monitorLoop()
        }
        monitorThread?.start()
    }
    
    func stop() {
        isRunning = false
        monitorThread = nil
    }
    
    private func monitorLoop() {
        while isRunning {
            if let angle = readAngle() {
                DispatchQueue.main.async { [weak self] in
                    self?.processAngle(angle)
                }
            }
            Thread.sleep(forTimeInterval: 0.015) // ~66Hz
        }
    }
    
    private func readAngle() -> Double? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = ["-c", "from pybooklid import read_lid_angle; print(read_lid_angle())"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let angle = Double(output) {
                return angle
            }
        } catch {
            // Silently fail
        }
        return nil
    }
    
    private func processAngle(_ rawAngle: Double) {
        // Smooth angle with more history
        angleHistory.removeFirst()
        angleHistory.append(rawAngle)
        let smoothed = angleHistory.reduce(0, +) / Double(angleHistory.count)
        
        // Calculate velocity - increased sensitivity for faster response
        let delta = abs(smoothed - currentAngle)
        let velocity = delta * 10.0  // Increased for faster response
        
        // Lighter velocity smoothing for faster response
        angularVelocity = angularVelocity * 0.5 + velocity * 0.5  // Changed from 0.75/0.25
        angularVelocity = min(30, angularVelocity)
        
        // NON-LINEAR mapping using sigmoid-like curve
        let normalizedVelocity = min(angularVelocity / 15.0, 1.0)  // Faster saturation
        
        // Sigmoid function with gentler curve for smoother feel
        let sigmoidInput = (normalizedVelocity - 0.5) * 3.0  // Reduced from 4.0 for smoother curve
        let sigmoidOutput = (tanh(sigmoidInput) + 1.0) / 2.0
        
        // Map to volume range (15% to 85%)
        let minVolume = 0.15
        let maxVolume = 0.85
        let targetVolume = minVolume + sigmoidOutput * (maxVolume - minVolume)
        
        // Lighter smoothing for faster response while maintaining smoothness
        volume = volume * 0.3 + targetVolume * 0.7  // Changed from 0.6/0.4
        volume = max(0.1, min(0.9, volume))
        
        currentAngle = smoothed
    }
}
