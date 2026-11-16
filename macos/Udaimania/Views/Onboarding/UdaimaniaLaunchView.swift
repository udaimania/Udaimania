import SwiftUI

/// A short native launch screen while the Udaimania visual redesign is in progress.
struct UdaimaniaLaunchView: View {
  let onComplete: () -> Void

  var body: some View {
    UdaimaniaBrandView()
      .task {
        do {
          try await Task.sleep(for: .milliseconds(700))
          onComplete()
        } catch {
          // A dismissed launch screen must not complete a second transition.
        }
      }
  }
}
