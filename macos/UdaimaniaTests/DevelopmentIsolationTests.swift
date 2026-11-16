import XCTest

@testable import Udaimania

final class DevelopmentIsolationTests: XCTestCase {
  func testBuildIdentityMatchesInstalledApp() throws {
    guard AppIdentity.isDevelopment else { throw XCTSkip("Development configuration only") }
    XCTAssertEqual(Bundle.main.bundleIdentifier, "com.udaimania.Dayflow.dev")
    XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, "Udaimania")
    XCTAssertEqual(AppIdentity.apiKeyServicePrefix, "com.udaimania.Dayflow.dev.apikeys")
    XCTAssertEqual(AppIdentity.authService, "com.udaimania.Dayflow.dev.auth")
    let types = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]])
    XCTAssertEqual(types.first?["CFBundleURLSchemes"] as? [String], ["dayflow-dev"])
  }

  func testForkCannotLoadTheUpstreamUpdater() {
    XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: "SUFeedURL"))
    XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey"))
    XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "SUEnableAutomaticChecks") as? Bool, false)
    XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "SUAutomaticallyUpdate") as? Bool, false)
  }

  func testStorageAndChatPromptsNeverSelectTheReleasedDatabase() throws {
    guard AppIdentity.isDevelopment else { throw XCTSkip("Development configuration only") }
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let expectedRoot = support.appendingPathComponent("Dayflow Dev", isDirectory: true)
    let expectedDatabase = expectedRoot.appendingPathComponent("chunks.sqlite").path
    XCTAssertEqual(AppIdentity.applicationSupportDirectory, expectedRoot)
    XCTAssertEqual(AgentBridgeServer.socketPath, expectedRoot.appendingPathComponent("agent.sock").path)
    XCTAssertEqual(ChatCLIConfigManager.shared.workingDirectory, expectedRoot.appendingPathComponent("chatcli", isDirectory: true))
    for prompt in [ChatPromptBuilder.codexSystemPrompt(), ChatPromptBuilder.claudeSystemPrompt()] {
      XCTAssertTrue(prompt.contains(expectedDatabase))
      XCTAssertFalse(prompt.contains("Application Support/Dayflow/chunks.sqlite"))
    }
  }

  @MainActor
  func testDevelopmentConnectionsCannotReplaceReleaseConnections() throws {
    guard AppIdentity.isDevelopment else { throw XCTSkip("Development configuration only") }
    XCTAssertEqual(AppIdentity.agentServerName, "dayflow-dev")
    XCTAssertEqual(AppIdentity.terminalLinkPath, "/usr/local/bin/udaimania")
    XCTAssertTrue(AgentClientRegistration.manualConfigSnippet.contains("\"dayflow-dev\""))

    var invokedCommands: [[String]] = []
    let registration = CodexMCPRegistration(
      cliPath: "/Applications/Udaimania.app/Contents/Helpers/udaimania",
      resolveExecutable: { URL(fileURLWithPath: "/tmp/codex") },
      runCommand: { _, arguments in
        invokedCommands.append(arguments)
        return .init(
          stdout: """
          {"transport":{"type":"stdio","command":"/Applications/Dayflow.app/Contents/Helpers/dayflow","args":["mcp"]}}
          """,
          stderr: "", exitCode: 0)
      }
    )
    if case .failed = registration.connect() {} else {
      XCTFail("A released helper must never be claimed by the development app")
    }
    XCTAssertEqual(invokedCommands, [["mcp", "get", "dayflow-dev", "--json"]])
  }
}
