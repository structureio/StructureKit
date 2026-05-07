import Foundation

public enum STKLogLevel: String {
  case debug = "DEBUG"
  case info = "INFO"
  case warning = "WARNING"
  case error = "ERROR"
}

public struct STKLogger {

    /// The global log handler. The host app can override this to route logs
    /// to their own systems (e.g., OSLog, Datadog, Sentry).
    public static var handler: ((STKLogLevel, String, String, Int) -> Void) = { level, message, file, line in
        // Default behavior: just print to console
        let fileName = URL(string: file)?.lastPathComponent
        print("[\(level.rawValue)] [StructureKit] \(fileName):\(line) - \(message)")
    }

    // MARK: - Internal Convenience Methods

    internal static func debug(_ message: String, file: String = #file, line: Int = #line) {
        handler(.debug, message, file, line)
    }

    internal static func warning(_ message: String, file: String = #file, line: Int = #line) {
        handler(.warning, message, file, line)
    }

    internal static func error(_ message: String, file: String = #file, line: Int = #line) {
        handler(.error, message, file, line)
    }
}
