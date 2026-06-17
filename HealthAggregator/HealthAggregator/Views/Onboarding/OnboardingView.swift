import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @Environment(AppState.self) var appState
    @State private var page = 0

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            TabView(selection: $page) {
                // Page 0 — Welcome
                OnboardingPage(
                    icon: "waveform.path.ecg.rectangle.fill",
                    iconColor: .accentGreen,
                    title: "All Your Health Data",
                    subtitle: "Apple Health, WHOOP, Renpho, MyFitnessPal, and Swim.com — unified in one beautiful dashboard.",
                    buttonLabel: "Get Started",
                    action: { withAnimation { page = 1 } }
                ).tag(0)

                // Page 1 — Sign in
                OnboardingSignInPage(
                    onSignedIn: { withAnimation { page = 2 } }
                ).tag(1)

                // Page 2 — Health access
                OnboardingPage(
                    icon: "heart.fill",
                    iconColor: .accentRed,
                    title: "Grant Health Access",
                    subtitle: "Health+ reads your steps, sleep, heart rate, nutrition, body composition, and workouts from Apple Health.",
                    buttonLabel: "Allow Health Access",
                    action: {
                        Task {
                            await appState.healthKitService.requestAuthorization()
                            withAnimation { page = 3 }
                        }
                    }
                ).tag(2)

                // Page 3 — Notifications
                OnboardingPage(
                    icon: "bell.badge.fill",
                    iconColor: .accentBlue,
                    title: "Stay Informed",
                    subtitle: "Get daily summaries, PR alerts, rest timer notifications, and your weekly recap.",
                    buttonLabel: "Enable Notifications",
                    action: {
                        Task {
                            await appState.notificationService.requestAuthorization()
                            withAnimation { page = 4 }
                        }
                    }
                ).tag(3)

                // Page 4 — WHOOP / finish
                OnboardingFinalPage {
                    appState.isOnboardingComplete = true
                }.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // Disable swipe — must use buttons to advance (prevents permission-skip)
            .allowsHitTesting(true)
            .animation(.easeInOut, value: page)
            .disabled(false)
            // Overlay to block swipe gestures while still allowing button taps
            .overlay(
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(DragGesture())   // absorbs horizontal swipes
            )

            // Page dots
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0..<5) { i in
                        Circle()
                            .fill(i == page ? Color.accentBlue : Color.textTertiary)
                            .frame(width: 8, height: 8)
                            .animation(.spring(response: 0.3), value: page)
                    }
                }
                .padding(.bottom, 50)
            }
        }
    }
}

// MARK: - Sign In Page

struct OnboardingSignInPage: View {
    @Environment(AppState.self) var appState
    let onSignedIn: () -> Void
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentPurple.opacity(0.15))
                    .frame(width: 120, height: 120)
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.accentPurple)
            }

            VStack(spacing: 16) {
                Text("Create Your Account")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Save your data and access it across your devices. Your health data stays private.")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }

            Spacer()

            VStack(spacing: 14) {
                // Sign in with Apple
                SignInWithAppleButton(.signUp) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success(let auth):
                        guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
                        appState.authService.userID = credential.user
                        appState.authService.isGuest = false
                        if let fullName = credential.fullName {
                            let name = [fullName.givenName, fullName.familyName]
                                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
                            if !name.isEmpty { appState.authService.displayName = name }
                        }
                        if let email = credential.email { appState.authService.email = email }
                        if appState.authService.displayName.isEmpty {
                            appState.authService.displayName = appState.authService.email.components(separatedBy: "@").first ?? "User"
                        }
                        appState.authService.isSignedIn = true
                        appState.authService.persistToDefaults()
                        onSignedIn()
                    case .failure:
                        break // user cancelled
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Continue without account
                Button {
                    appState.authService.continueAsGuest()
                    onSignedIn()
                } label: {
                    Text("Continue Without Account")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 130)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Generic page

struct OnboardingPage: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let buttonLabel: String
    let action: () -> Void
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 120, height: 120)
                Image(systemName: icon)
                    .font(.system(size: 52))
                    .foregroundStyle(iconColor)
            }

            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }

            Spacer()

            Button {
                guard !isWorking else { return }
                isWorking = true
                action()
            } label: {
                Group {
                    if isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Text(buttonLabel)
                            .font(.system(size: 17, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(iconColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 130)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Final page

struct OnboardingFinalPage: View {
    let onComplete: () -> Void
    @State private var showWhoopConnect = false
    @State private var isConnecting = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentGreen.opacity(0.15))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentGreen)
            }

            Text("You're All Set!")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            Text("Connect WHOOP for recovery scores, or start exploring your data now.")
                .font(.system(size: 16))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    guard !isConnecting else { return }
                    isConnecting = true
                    showWhoopConnect = true
                } label: {
                    Text("Connect WHOOP")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.accentBlue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(isConnecting)

                Button { onComplete() } label: {
                    Text("Skip for Now")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
        }
        .sheet(isPresented: $showWhoopConnect, onDismiss: {
            isConnecting = false
            onComplete()   // complete onboarding whether they connected or swiped away
        }) {
            WhoopConnectView(onComplete: onComplete)
        }
    }
}
