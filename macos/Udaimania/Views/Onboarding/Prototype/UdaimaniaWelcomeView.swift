import SwiftUI

/// Uses native text so the fork never shows the upstream wordmark baked into media.
struct UdaimaniaBrandView: View {
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color(hex: "FFF4CF"), Color(hex: "FFE7D5"), Color(hex: "FFFBF4")],
        startPoint: .topLeading, endPoint: .bottomTrailing
      )
      VStack(spacing: 24) {
        Image("UdaimaniaLogoMainApp")
          .resizable()
          .scaledToFit()
          .frame(width: 120, height: 120)
          .accessibilityHidden(true)
        Text("Udaimania")
          .font(.custom("InstrumentSerif-Regular", size: 64))
          .foregroundStyle(Color(hex: "492304"))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ignoresSafeArea()
  }
}

struct UdaimaniaWelcomeView: View {
  let onContinue: () -> Void

  var body: some View {
    UdaimaniaBrandView()
      .overlay(alignment: .bottom) {
        VStack(spacing: 20) {
          Text("Your work, remembered.")
            .font(.custom("Figtree", size: 20))
            .foregroundStyle(Color(hex: "492304"))
          Button("Get started", action: onContinue)
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "A64A20"))
            .controlSize(.large)
        }
        .padding(.bottom, 64)
      }
  }
}

#Preview {
  UdaimaniaWelcomeView(onContinue: {})
}
