import Foundation

/// Shared by the macOS app and its bundled CLI so both address the same data.
/// Development is a separate build configuration, never a runtime preference.
enum AppIdentity {
  #if UDAIMANIA_DEVELOPMENT
    static let isDevelopment = true
    static let displayName = "Udaimania"
    static let bundleIdentifier = "com.udaimania.Dayflow.dev"
    static let storageDirectoryName = "Dayflow Dev"
    static let urlScheme = "dayflow-dev"
    static let agentServerName = "dayflow-dev"
    static let apiKeyServicePrefix = "com.udaimania.Dayflow.dev.apikeys"
    static let authService = "com.udaimania.Dayflow.dev.auth"
  #else
    static let isDevelopment = false
    static let displayName = "Udaimania"
    static let bundleIdentifier = "com.udaimania.app"
    static let storageDirectoryName = "Udaimania"
    static let urlScheme = "udaimania"
    static let agentServerName = "udaimania"
    static let apiKeyServicePrefix = "com.udaimania.app.apikeys"
    static let authService = "com.udaimania.app.auth"
  #endif

  // Stable identifiers and storage preserve settings from the original development build.
  static var recognizedAppNames: [String] {
    isDevelopment ? [displayName, "Dayflow Dev"] : [displayName]
  }

  static var applicationSupportDirectory: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(storageDirectoryName, isDirectory: true)
  }

  static var terminalLinkPath: String { "/usr/local/bin/udaimania" }
}
