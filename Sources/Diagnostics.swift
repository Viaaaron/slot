import Foundation

enum Diagnostics {
    private static let logHandle: FileHandle? = {
        let logsDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
        let logURL = logsDirectory.appendingPathComponent("Slot.log")
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: logURL) else { return nil }
        _ = try? handle.seekToEnd()
        return handle
    }()

    static func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        guard let data = "[\(timestamp)] \(message)\n".data(using: .utf8) else { return }
        logHandle?.write(data)
        try? logHandle?.synchronize()
    }
}
