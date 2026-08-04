import Foundation

enum ResourceLocator {
    static func url(forResource name: String, withExtension extensionName: String) -> URL? {
        if let override = ProcessInfo.processInfo.environment["MACORDION_RESOURCE_DIR"] {
            let candidate = URL(fileURLWithPath: override, isDirectory: true)
                .appendingPathComponent(name)
                .appendingPathExtension(extensionName)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        if let bundled = Bundle.main.url(forResource: name, withExtension: extensionName) {
            return bundled
        }

        // Keeps `swift run ...` convenient when launched from the repository.
        let developmentResource = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        .appendingPathComponent("AcOrDiOn/Resources", isDirectory: true)
        .appendingPathComponent(name)
        .appendingPathExtension(extensionName)

        return FileManager.default.fileExists(atPath: developmentResource.path)
            ? developmentResource
            : nil
    }
}
