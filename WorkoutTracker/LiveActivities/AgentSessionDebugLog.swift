import Foundation

/// Debug-mode NDJSON logger (session `7c09f3`). Prefers Simulator host home so the widget extension can reach the workspace log file.
enum AgentSessionDebugLog {
    private static let sessionId = "7c09f3"

    private static var logFileURL: URL {
        if let override = ProcessInfo.processInfo.environment["AGENT_DEBUG_LOG_PATH"], override.isEmpty == false {
            return URL(fileURLWithPath: override)
        }
        if let hostHome = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"], hostHome.isEmpty == false {
            return URL(fileURLWithPath: "\(hostHome)/workout_tracker/.cursor/debug-\(sessionId).log")
        }
        return URL(fileURLWithPath: "/Users/cam/workout_tracker/.cursor/debug-\(sessionId).log")
    }

    nonisolated static func append(
        hypothesisId: String,
        location: String,
        message: String,
        data: [String: Any] = [:],
        runId: String = "pre"
    ) {
        let payload: [String: Any] = [
            "sessionId": sessionId,
            "runId": runId,
            "hypothesisId": hypothesisId,
            "location": location,
            "message": message,
            "data": data,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              var line = String(data: jsonData, encoding: .utf8) else { return }
        line.append("\n")
        guard let bytes = line.data(using: .utf8) else { return }

        let url = logFileURL
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                try? handle.seekToEnd()
                try? handle.write(contentsOf: bytes)
            }
        } else {
            try? bytes.write(to: url)
        }
    }
}
