//
//  SplashWindow.swift
//  Udaimania
//
//  Splash screen window controller
//

import AppKit
import SwiftUI

class SplashWindow: NSWindow {
  var onClose: (() -> Void)?

  init(onClose: @escaping () -> Void) {
    self.onClose = onClose

    super.init(
      contentRect: NSRect(x: 0, y: 0, width: 250, height: 250),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )

    // Configure window
    self.isOpaque = false
    self.backgroundColor = .clear
    self.level = .floating
    self.hasShadow = false
    self.isMovableByWindowBackground = false
    self.ignoresMouseEvents = true  // never block clicks if this borderless window lingers

    // Center window
    self.center()

    // Set content
    self.contentView = NSHostingView(rootView: SplashView())

    // Show window
    self.makeKeyAndOrderFront(nil)

    // Auto-close after delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
      self.fadeOut()
    }
  }

  private func fadeOut() {
    NSAnimationContext.runAnimationGroup(
      { context in
        context.duration = 0.15
        self.animator().alphaValue = 0
      },
      completionHandler: {
        self.close()
        self.onClose?()
      })
  }
}

struct SplashView: View {
  @State private var logoOpacity: Double = 0

  var body: some View {
    ZStack {
      Color.clear

      VStack(spacing: 12) {
        Image("UdaimaniaLogoMainApp")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 120, height: 120)
        Text("Udaimania")
          .font(.custom("InstrumentSerif-Regular", size: 34))
          .foregroundStyle(.white)
          .shadow(radius: 3)
      }
      .opacity(logoOpacity)
    }
    .frame(width: 250, height: 250)
    .onAppear {
      withAnimation(.easeIn(duration: 0.15)) {
        logoOpacity = 1.0
      }
    }
  }
}
