import Foundation

/// Debug-mode NDJSON logger that appends to the required log path.
/// NOTE: Do not log PII (no exact coordinates, no user names).
enum DebugFileLogger {
    static let logPath = "/Users/hamads/Documents/moatheny/.cursor/debug.log"
    static let sessionId = "debug-session"
    
    static func log(runId: String, hypothesisId: String, location: String, message: String, data: [String: Any] = [:]) {
        #if DEBUG
        // #region agent log
        let payload: [String: Any] = [
            "sessionId": sessionId,
            "runId": runId,
            "hypothesisId": hypothesisId,
            "location": location,
            "message": message,
            "data": data,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        
        guard let json = try? JSONSerialization.data(withJSONObject: payload, options: []),
              var line = String(data: json, encoding: .utf8) else { return }
        line.append("\n")
        
        do {
            if !FileManager.default.fileExists(atPath: logPath) {
                FileManager.default.createFile(atPath: logPath, contents: nil)
            }
            let fh = try FileHandle(forWritingTo: URL(fileURLWithPath: logPath))
            try fh.seekToEnd()
            if let data = line.data(using: .utf8) {
                try fh.write(contentsOf: data)
            }
            try fh.close()
        } catch {
            // swallow
        }
        // #endregion agent log
        #endif
    }
}

