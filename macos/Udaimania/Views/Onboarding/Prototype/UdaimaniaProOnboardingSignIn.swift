//
//  UdaimaniaProOnboardingSignIn.swift
//  Udaimania
//
//  The Udaimania Pro email/code sign-in flow shown inside the onboarding
//  provider chooser, including referral-code and trial steps.
//

import SwiftUI

enum UdaimaniaProOnboardingStep {
  case email
  case code
  case referralCode
  case freeMonthActive
  case trialOffer
  case trialActive

  var analyticsName: String {
    switch self {
    case .email:
      return "email"
    case .code:
      return "code"
    case .referralCode:
      return "referral_code"
    case .freeMonthActive:
      return "free_month_active"
    case .trialOffer:
      return "trial_offer"
    case .trialActive:
      return "trial_active"
    }
  }
}

private struct UdaimaniaProReferralFieldShake: GeometryEffect {
  var travelDistance: CGFloat
  var shakes: CGFloat
  var animatableData: CGFloat

  func effectValue(size: CGSize) -> ProjectionTransform {
    let xOffset = travelDistance * sin(animatableData * .pi * shakes)
    return ProjectionTransform(CGAffineTransform(translationX: xOffset, y: 0))
  }
}

struct UdaimaniaProOnboardingSignInPanel: View {
  let flowID: String
  let flowVariant: String
  let layoutScale: CGFloat
  let textScale: CGFloat
  // Captured by the parent at click time, before it signs out the current session.
  let initialReferralCode: String
  let onBack: () -> Void
  let onComplete: () -> Void

  @ObservedObject private var authManager = UdaimaniaAuthManager.shared
  @State private var udaimaniaProStep: UdaimaniaProOnboardingStep = .email
  @State private var udaimaniaProEmail = ""
  @State private var udaimaniaProCode = ""
  @State private var udaimaniaProReferralCode = ""
  @State private var udaimaniaProReferralShakeTrigger: CGFloat = 0
  @State private var udaimaniaProVerificationEmail = ""

  private func scaled(_ value: CGFloat) -> CGFloat {
    value * layoutScale
  }

  private func scaledText(_ value: CGFloat) -> CGFloat {
    scaled(value) * textScale
  }

  var body: some View {
    VStack(alignment: .leading, spacing: scaled(18)) {
      HStack(alignment: .center, spacing: scaled(14)) {
        Image("UdaimaniaLogo")
          .resizable()
          .renderingMode(.original)
          .interpolation(.high)
          .antialiased(true)
          .scaledToFit()
          .frame(width: scaled(40), height: scaled(40))

        VStack(alignment: .leading, spacing: scaled(4)) {
          Text("Sign up / Sign in to Udaimania")
            .font(.custom("Figtree", size: scaledText(20)))
            .fontWeight(.semibold)
            .foregroundColor(Color(hex: "492304"))

          if let subtitle = udaimaniaProSubtitle {
            Text(subtitle)
              .font(.custom("Figtree", size: scaledText(13)))
              .foregroundColor(Color(hex: "89380E").opacity(0.75))
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        Spacer()

        Button {
          onBack()
        } label: {
          Text("Back")
            .font(.custom("Figtree", size: scaledText(13)))
            .fontWeight(.semibold)
            .foregroundColor(Color(hex: "492304"))
            .padding(.horizontal, scaled(14))
            .padding(.vertical, scaled(8))
            .background(Color.white.opacity(0.45))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color(hex: "E4D3C2"), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
      }

      switch udaimaniaProStep {
      case .email:
        udaimaniaProEmailForm
      case .code:
        udaimaniaProCodeForm
      case .referralCode:
        udaimaniaProReferralCodeForm
      case .freeMonthActive:
        udaimaniaProRewardActiveForm
      case .trialOffer:
        udaimaniaProTrialOfferForm
      case .trialActive:
        udaimaniaProTrialActiveForm
      }

      if let statusMessage = udaimaniaProStatusMessage {
        Text(statusMessage.text)
          .font(.custom("Figtree", size: scaledText(13)))
          .foregroundColor(statusMessage.isError ? Color(hex: "B42318") : Color(hex: "89380E"))
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(.horizontal, scaled(28))
    .padding(.vertical, scaled(24))
    .frame(maxWidth: scaled(620))
    .background(Color.white.opacity(0.42))
    .cornerRadius(6)
    .overlay(
      RoundedRectangle(cornerRadius: 6)
        .stroke(Color(hex: "E4D3C2"), lineWidth: 1)
    )
    .shadow(color: Color(hex: "AF7246").opacity(0.15), radius: 8, x: 0, y: 2)
    .onAppear {
      udaimaniaProReferralCode = initialReferralCode
      trackUdaimaniaProStepViewed(udaimaniaProStep)
    }
    .onChange(of: udaimaniaProStep) { oldStep, newStep in
      guard oldStep != newStep else { return }
      trackUdaimaniaProStepViewed(newStep)
    }
  }

  private var udaimaniaProEmailForm: some View {
    VStack(alignment: .leading, spacing: scaled(14)) {
      VStack(alignment: .leading, spacing: scaled(6)) {
        Text("Email")
          .font(.custom("Figtree", size: scaledText(13)))
          .fontWeight(.semibold)
          .foregroundColor(Color(hex: "492304"))

        udaimaniaProTextField("you@example.com", text: $udaimaniaProEmail)
          .onSubmit(sendUdaimaniaProCode)
      }

      HStack {
        Spacer()
        udaimaniaProPrimaryButton(
          title: authManager.isBusy
            ? String(localized: "Sending...") : String(localized: "Send sign-in code"),
          enabled: canSendUdaimaniaProCode,
          action: sendUdaimaniaProCode
        )
      }
    }
  }

  private var udaimaniaProCodeForm: some View {
    VStack(alignment: .leading, spacing: scaled(14)) {
      VStack(alignment: .leading, spacing: scaled(6)) {
        Text("Code sent to \(udaimaniaProVerificationTarget)")
          .font(.custom("Figtree", size: scaledText(13)))
          .fontWeight(.semibold)
          .foregroundColor(Color(hex: "492304"))

        udaimaniaProTextField("123456", text: $udaimaniaProCode)
          .onChange(of: udaimaniaProCode) { _, newValue in
            let normalized = String(newValue.filter(\.isNumber).prefix(6))
            if normalized != newValue {
              udaimaniaProCode = normalized
            }
          }
          .onSubmit(verifyUdaimaniaProCode)
      }

      HStack(spacing: scaled(10)) {
        udaimaniaProSecondaryButton(
          title: String(localized: "Different email"),
          action: showUdaimaniaProEmailStep
        )

        udaimaniaProSecondaryButton(
          title: authManager.isBusy
            ? String(localized: "Sending...") : String(localized: "Resend code"),
          enabled: !authManager.isBusy,
          action: resendUdaimaniaProCode
        )

        Spacer()

        udaimaniaProPrimaryButton(
          title: authManager.isBusy
            ? String(localized: "Checking...") : String(localized: "Continue"),
          enabled: canVerifyUdaimaniaProCode,
          action: verifyUdaimaniaProCode
        )
      }
    }
  }

  private var udaimaniaProReferralCodeForm: some View {
    VStack(alignment: .leading, spacing: scaled(14)) {
      VStack(alignment: .leading, spacing: scaled(6)) {
        Text("Do you have a referral code?")
          .font(.custom("Figtree", size: scaledText(13)))
          .fontWeight(.semibold)
          .foregroundColor(Color(hex: "492304"))

        Text(
          "If someone gave you a code, enter it here. Don't worry if you don't have a code, we'll gift you a free week of Udaimania Pro!"
        )
        .font(.custom("Figtree", size: scaledText(13)))
        .foregroundColor(Color(hex: "89380E").opacity(0.75))
        .fixedSize(horizontal: false, vertical: true)
      }

      udaimaniaProReferralField

      HStack(spacing: scaled(10)) {
        udaimaniaProPrimaryButton(
          title: authManager.isBusy
            ? String(localized: "Applying...") : String(localized: "Apply code"),
          enabled: canApplyUdaimaniaProReferralCode,
          action: applyUdaimaniaProReferralCode
        )

        udaimaniaProSecondaryButton(
          title: String(localized: "I don't have a code"),
          enabled: !authManager.isBusy,
          action: showUdaimaniaProTrialOffer
        )
      }
    }
  }

  private var udaimaniaProRewardActiveForm: some View {
    VStack(alignment: .center, spacing: scaled(16)) {
      ReferralPassCard(message: String(localized: "Your free month of Udaimania Pro is ready."))

      VStack(spacing: scaled(6)) {
        Text("Congrats, enjoy a free month of Udaimania Pro on us!")
          .font(.custom("Figtree", size: scaledText(16)))
          .fontWeight(.semibold)
          .foregroundColor(Color(hex: "492304"))
          .multilineTextAlignment(.center)

        Text("Your referral reward is active on this account.")
          .font(.custom("Figtree", size: scaledText(13)))
          .foregroundColor(Color(hex: "89380E").opacity(0.75))
          .multilineTextAlignment(.center)
      }

      udaimaniaProPrimaryButton(
        title: String(localized: "Continue with Udaimania Pro"),
        enabled: !authManager.isBusy,
        action: continueWithUdaimaniaPro
      )
    }
    .frame(maxWidth: .infinity)
  }

  private var udaimaniaProTrialOfferForm: some View {
    VStack(alignment: .center, spacing: scaled(16)) {
      ReferralPassCard(message: String(localized: "7 days free. No credit card required."))

      VStack(spacing: scaled(6)) {
        Text("Try Udaimania Pro free for 7 days.")
          .font(.custom("Figtree", size: scaledText(16)))
          .fontWeight(.semibold)
          .foregroundColor(Color(hex: "492304"))
          .multilineTextAlignment(.center)

        Text(
          "We want you to be able to try Udaimania for free, no credit card and no strings attached!"
        )
        .font(.custom("Figtree", size: scaledText(13)))
        .foregroundColor(Color(hex: "89380E").opacity(0.75))
        .multilineTextAlignment(.center)
      }

      HStack(spacing: scaled(10)) {
        udaimaniaProPrimaryButton(
          title: authManager.isBusy
            ? String(localized: "Starting...") : String(localized: "Start free trial"),
          enabled: !authManager.isBusy,
          action: startUdaimaniaProTrial
        )

        udaimaniaProSecondaryButton(
          title: String(localized: "I have a code"),
          enabled: !authManager.isBusy,
          action: showUdaimaniaProReferralCodeStep
        )
      }
    }
    .frame(maxWidth: .infinity)
  }

  private var udaimaniaProTrialActiveForm: some View {
    VStack(alignment: .center, spacing: scaled(16)) {
      ReferralPassCard(message: String(localized: "7 days free. No credit card required."))

      VStack(spacing: scaled(6)) {
        Text("Your Udaimania Pro trial is active.")
          .font(.custom("Figtree", size: scaledText(16)))
          .fontWeight(.semibold)
          .foregroundColor(Color(hex: "492304"))
          .multilineTextAlignment(.center)

        Text("No credit card needed. You can set up billing later if Udaimania is useful.")
          .font(.custom("Figtree", size: scaledText(13)))
          .foregroundColor(Color(hex: "89380E").opacity(0.75))
          .multilineTextAlignment(.center)
      }

      udaimaniaProPrimaryButton(
        title: String(localized: "Continue with Udaimania Pro"),
        enabled: !authManager.isBusy,
        action: continueWithUdaimaniaPro
      )
    }
    .frame(maxWidth: .infinity)
  }

  private var udaimaniaProReferralField: some View {
    VStack(alignment: .leading, spacing: scaled(6)) {
      HStack(spacing: scaled(8)) {
        Text("Referral code")
          .font(.custom("Figtree", size: scaledText(13)))
          .fontWeight(.semibold)
          .foregroundColor(Color(hex: "492304"))

        Text("Optional")
          .font(.custom("Figtree", size: scaledText(12)))
          .foregroundColor(Color(hex: "89380E").opacity(0.62))
      }

      udaimaniaProTextField("ABC123", text: $udaimaniaProReferralCode)
        .modifier(
          UdaimaniaProReferralFieldShake(
            travelDistance: scaled(7),
            shakes: 5,
            animatableData: udaimaniaProReferralShakeTrigger
          )
        )
        .onChange(of: udaimaniaProReferralCode) { _, newValue in
          let normalized = normalizedReferralInput(newValue)
          if normalized != newValue {
            udaimaniaProReferralCode = normalized
          }
        }

      if !udaimaniaProReferralCode.isEmpty && !isUdaimaniaProReferralCodeValid {
        Text("Enter the 6-character code from your invite.")
          .font(.custom("Figtree", size: scaledText(12)))
          .foregroundColor(Color(hex: "B42318"))
      }
    }
  }

  private var udaimaniaProSubtitle: String? {
    switch udaimaniaProStep {
    case .email:
      return nil
    case .code:
      return String(localized: "Enter the code we sent to finish signing up/in.")
    case .referralCode:
      return nil
    case .freeMonthActive:
      return String(localized: "Your referral reward is ready.")
    case .trialOffer:
      return String(localized: "No referral code? Start with a free trial.")
    case .trialActive:
      return String(localized: "Your trial is ready.")
    }
  }

  private var udaimaniaProStatusMessage: (text: String, isError: Bool)? {
    if let errorText = authManager.errorText, !errorText.isEmpty {
      return (errorText, true)
    }

    let status = authManager.statusText.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedStatus = status.lowercased()
    guard !status.isEmpty, !normalizedStatus.hasPrefix(String(localized: "Signed out").lowercased())
    else {
      return nil
    }
    if shouldHideSignedInStatus,
      normalizedStatus.hasPrefix(String(localized: "Signed in.").lowercased())
    {
      return nil
    }

    return (status, false)
  }

  private var shouldHideSignedInStatus: Bool {
    udaimaniaProStep == .referralCode || udaimaniaProStep == .trialOffer
  }

  private func trackUdaimaniaProStepViewed(_ step: UdaimaniaProOnboardingStep) {
    OnboardingPrototypeAnalytics.trackUdaimaniaProStepViewed(
      step: step,
      flowID: flowID,
      flowVariant: flowVariant
    )
  }

  private func trackUdaimaniaProAPIOutcome(
    _ eventName: String,
    action: String,
    result: UdaimaniaAuthActionResult,
    step: UdaimaniaProOnboardingStep? = nil
  ) {
    OnboardingPrototypeAnalytics.trackUdaimaniaProAPIOutcome(
      eventName,
      action: action,
      result: result,
      step: step ?? udaimaniaProStep,
      flowID: flowID,
      flowVariant: flowVariant
    )
  }

  private var trimmedUdaimaniaProEmail: String {
    udaimaniaProEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  private var udaimaniaProVerificationTarget: String {
    udaimaniaProVerificationEmail.isEmpty ? trimmedUdaimaniaProEmail : udaimaniaProVerificationEmail
  }

  private var canSendUdaimaniaProCode: Bool {
    trimmedUdaimaniaProEmail.contains("@")
      && trimmedUdaimaniaProEmail.contains(".")
      && !trimmedUdaimaniaProEmail.contains(" ")
      && !authManager.isBusy
  }

  private var canVerifyUdaimaniaProCode: Bool {
    udaimaniaProCode.filter(\.isNumber).count == 6
      && !authManager.isBusy
  }

  private var canApplyUdaimaniaProReferralCode: Bool {
    udaimaniaProReferralCode.count == 6 && !authManager.isBusy
  }

  private var isUdaimaniaProReferralCodeValid: Bool {
    udaimaniaProReferralCode.isEmpty || udaimaniaProReferralCode.count == 6
  }

  private var normalizedUdaimaniaProReferralCode: String? {
    let normalized = normalizedReferralInput(udaimaniaProReferralCode)
    return normalized.isEmpty ? nil : normalized
  }

  private var isUdaimaniaProActive: Bool {
    authManager.entitlements.plan == "pro" && authManager.entitlements.status == "active"
  }

  private var hasActiveReferralReward: Bool {
    hasActiveReward(matching: { $0.rewardType == "recipient_claim" })
  }

  private var hasActiveTrialReward: Bool {
    hasActiveReward(matching: { $0.rewardType == "onboarding_trial" })
  }

  private func udaimaniaProTextField(_ placeholder: String, text: Binding<String>) -> some View {
    TextField(placeholder, text: text)
      .font(.custom("Figtree", size: scaledText(14)))
      .foregroundColor(Color(hex: "492304"))
      .textFieldStyle(.plain)
      .padding(.horizontal, scaled(12))
      .frame(height: scaled(42))
      .background(Color.white.opacity(0.72))
      .cornerRadius(6)
      .overlay(
        RoundedRectangle(cornerRadius: 6)
          .stroke(Color(hex: "E4D3C2"), lineWidth: 1)
      )
  }

  private func udaimaniaProPrimaryButton(
    title: String,
    enabled: Bool = true,
    action: @escaping () -> Void
  ) -> some View {
    UdaimaniaSurfaceButton(
      action: action,
      content: {
        Text(title)
          .font(.custom("Figtree", size: scaledText(13)))
          .fontWeight(.semibold)
          .lineLimit(1)
          .fixedSize(horizontal: true, vertical: false)
      },
      background: enabled ? Color(hex: "FF9F6F") : Color(hex: "FF9F6F").opacity(0.3),
      foreground: .white,
      borderColor: Color(hex: "F4C8B1"),
      cornerRadius: 200,
      horizontalPadding: 12,
      verticalPadding: 0,
      minWidth: scaled(150),
      fixedHeight: 36,
      showOverlayStroke: false,
      innerGlowColor: Color(hex: "FFDCCB").opacity(0.9)
    )
    .disabled(!enabled)
    .opacity(enabled ? 1 : 0.85)
  }

  private func udaimaniaProSecondaryButton(
    title: String,
    enabled: Bool = true,
    action: @escaping () -> Void
  ) -> some View {
    UdaimaniaSurfaceButton(
      action: action,
      content: {
        Text(title)
          .font(.custom("Figtree", size: scaledText(13)))
          .fontWeight(.semibold)
      },
      background: Color.white.opacity(0.64),
      foreground: Color(hex: "492304"),
      borderColor: Color(hex: "B6B6B6"),
      cornerRadius: 200,
      horizontalPadding: 12,
      verticalPadding: 0,
      minWidth: scaled(116),
      fixedHeight: 36,
      showShadow: false
    )
    .disabled(!enabled)
    .opacity(enabled ? 1 : 0.7)
  }

  private func sendUdaimaniaProCode() {
    guard canSendUdaimaniaProCode else { return }

    Task {
      let result = await authManager.sendCode(to: trimmedUdaimaniaProEmail)
      trackUdaimaniaProAPIOutcome(
        "dayflow_pro_auth_code_requested",
        action: "auth_code_request",
        result: result,
        step: .email
      )
      guard result.succeeded, authManager.canVerifyCode else { return }

      udaimaniaProVerificationEmail = authManager.pendingEmail ?? trimmedUdaimaniaProEmail
      udaimaniaProCode = ""
      withAnimation(.easeInOut(duration: 0.25)) {
        udaimaniaProStep = .code
      }
    }
  }

  private func verifyUdaimaniaProCode() {
    guard canVerifyUdaimaniaProCode else { return }

    Task {
      let result = await authManager.verifyCode(udaimaniaProCode, for: udaimaniaProVerificationTarget)
      trackUdaimaniaProAPIOutcome(
        "dayflow_pro_auth_code_verified",
        action: "auth_code_verify",
        result: result,
        step: .code
      )
      guard result.succeeded else { return }

      await authManager.refreshAccount()
      guard authManager.isSignedIn else { return }

      routeAfterUdaimaniaProSignIn()
    }
  }

  private func resendUdaimaniaProCode() {
    Task {
      await authManager.resendCode()
    }
  }

  private func showUdaimaniaProEmailStep() {
    authManager.useDifferentEmail()
    udaimaniaProCode = ""
    udaimaniaProVerificationEmail = ""
    withAnimation(.easeInOut(duration: 0.25)) {
      udaimaniaProStep = .email
    }
  }

  private func routeAfterUdaimaniaProSignIn() {
    if isUdaimaniaProActive && !hasActiveReferralReward && !hasActiveTrialReward {
      continueWithUdaimaniaPro()
      return
    }

    withAnimation(.easeInOut(duration: 0.25)) {
      if hasActiveReferralReward {
        udaimaniaProStep = .freeMonthActive
      } else if hasActiveTrialReward {
        udaimaniaProStep = .trialActive
      } else {
        udaimaniaProStep = .referralCode
      }
    }
  }

  private func applyUdaimaniaProReferralCode() {
    guard let referralCode = normalizedUdaimaniaProReferralCode else {
      trackUdaimaniaProAPIOutcome(
        "dayflow_pro_referral_code_submitted",
        action: "referral_code_submit",
        result: .localFailure(errorType: "missing_referral_code", endpoint: "/v1/referrals/claim"),
        step: .referralCode
      )
      shakeUdaimaniaProReferralField()
      return
    }

    Task {
      let result = await authManager.claimReferralCode(referralCode)
      trackUdaimaniaProAPIOutcome(
        "dayflow_pro_referral_code_submitted",
        action: "referral_code_submit",
        result: result,
        step: .referralCode
      )
      guard result.succeeded, authManager.errorText == nil else {
        shakeUdaimaniaProReferralField()
        return
      }

      await authManager.refreshAccount()
      guard authManager.errorText == nil else { return }

      if hasActiveReferralReward || isUdaimaniaProActive {
        withAnimation(.easeInOut(duration: 0.25)) {
          udaimaniaProStep = .freeMonthActive
        }
      }
    }
  }

  private func showUdaimaniaProTrialOffer() {
    withAnimation(.easeInOut(duration: 0.25)) {
      udaimaniaProStep = .trialOffer
    }
  }

  private func showUdaimaniaProReferralCodeStep() {
    withAnimation(.easeInOut(duration: 0.25)) {
      udaimaniaProStep = .referralCode
    }
  }

  private func shakeUdaimaniaProReferralField() {
    withAnimation(.linear(duration: 0.32)) {
      udaimaniaProReferralShakeTrigger += 1
    }
  }

  private func startUdaimaniaProTrial() {
    Task {
      let result = await authManager.startNoCardTrial()
      trackUdaimaniaProAPIOutcome(
        "dayflow_pro_trial_started",
        action: "trial_start",
        result: result,
        step: .trialOffer
      )
      guard result.succeeded, authManager.errorText == nil else { return }

      if hasActiveTrialReward || isUdaimaniaProActive {
        withAnimation(.easeInOut(duration: 0.25)) {
          udaimaniaProStep = .trialActive
        }
      }
    }
  }

  private func continueWithUdaimaniaPro() {
    OnboardingPrototypeAnalytics.trackUdaimaniaProSelected(
      flowID: flowID,
      flowVariant: flowVariant,
      selectionStage: "continued"
    )
    onComplete()
  }

  private func hasActiveReward(matching predicate: (UdaimaniaReferralReward) -> Bool) -> Bool {
    let activeStatuses = ["applied_internal", "pending_stripe", "applied_stripe"]
    return authManager.referralSummary?.rewards.contains { reward in
      predicate(reward) && activeStatuses.contains(reward.status)
    } ?? false
  }

  private func normalizedReferralInput(_ input: String) -> String {
    let allowed = CharacterSet.alphanumerics
    return
      input
      .uppercased()
      .unicodeScalars
      .filter { allowed.contains($0) }
      .prefix(6)
      .map(String.init)
      .joined()
  }
}
