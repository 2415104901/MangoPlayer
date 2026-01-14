import Foundation
import os.log

/// Simple logging utility for MangoPlayer
class MPLog {
    static var isEnabled = true

    private static let subsystem = "com.mangoplayer"
    private static let category = "Player"

    /// Log debug messages
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }

    /// Log info messages
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }

    /// Log warning messages
    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .default, file: file, function: function, line: line)
    }

    /// Log error messages
    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }

    private static func log(_ message: String, level: OSLogType, file: String, function: String, line: Int) {
        guard isEnabled else { return }

        let filename = (file as NSString).lastPathComponent
        let logMessage = "[\(filename):\(line)] \(function): \(message)"

        // Always print to console for flutter run visibility
        print(logMessage)

        let osLog = OSLog(subsystem: subsystem, category: category)
        os_log("%{public}@", log: osLog, type: level, logMessage)
    }
}

// Convenience shorthand
let Log = MPLog.self
