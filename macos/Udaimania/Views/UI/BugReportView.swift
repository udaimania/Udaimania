import AppKit
import SwiftUI

/// Support for this fork. Diagnostics are copied only on request, never uploaded.
struct BugReportView: View {
  @Environment(\.udaimaniaTheme) private var theme
  @State private var didCopyDebugLogs = false
  @State private var isCopyingDebugLogs = false

  var body: some View {
    VStack(spacing: 24) {
      Text("Udaimania")
        .font(.custom("InstrumentSerif-Regular", size: 40))
        .foregroundColor(theme.textPrimary)
      Text("Support and feedback")
        .font(.custom("Figtree", size: 20).weight(.semibold))
        .foregroundColor(theme.textPrimary)
      Text("Find source code and development notes in the Udaimania GitHub repository.")
        .font(.custom("Figtree", size: 16))
        .foregroundColor(theme.textSecondary)
        .multilineTextAlignment(.center)
      Link("View project", destination: URL(string: "https://github.com/udaimania/Udaimania")!)
      Button(action: copyDebugLogs) {
        Text(didCopyDebugLogs ? "Copied!" : (isCopyingDebugLogs ? "Preparing…" : "Copy debug logs"))
      }
      .disabled(isCopyingDebugLogs)
      Text("Copies diagnostics to your clipboard for review and sharing.")
        .font(.custom("Figtree", size: 13))
        .foregroundColor(theme.textSecondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(48)
  }

  private func copyDebugLogs() {
    guard !isCopyingDebugLogs else { return }
    isCopyingDebugLogs = true
    Task.detached(priority: .userInitiated) {
      let snapshot = DebugLogSnapshot.makeCurrent()
      await MainActor.run {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snapshot.text, forType: .string)
        didCopyDebugLogs = true
        isCopyingDebugLogs = false
      }
    }
  }
}

#Preview {
  BugReportView()
}
