import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) var appState
    @State private var page = 0

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            TabView(selection: $page) {
                OnboardingPage(
                    icon: "waveform.path.ecg.rectangle.fill",
                    iconColor: .accentGreen,
                    title: "All Your Health Data",
                    subtitle: "Apple Health, WHOOP, Renpho, MyFitnessPal, and Swim.com — unified in one beautiful dashboard.",
                    buttonLabel: "Get Started",
                    action: { withAnimation { page = 1 } }
                ).tag(0)

                OnboardingPage(
                    icon: "heart.fill",
                    iconColor: .accentRed,
                    title: "Grant Health Access",
                    subtitle: "Health+ reads your steps, sleep, heart rate, nutrition, body composition, and workouts from Apple Health.",
                    buttonLabel: "Allow Health Access",
                    action: {
                        Task {
                            await appState.healthKitService.requestAuthorization()
                            withAnimation { page = 2 }
                        }
                    }
                ).tag(1)

                OnboardingPage(
                    icon: "bell.badge.fill",
                    iconColor: .accentBlue,
                    title: "Stay Informed",
                    subtitle: "Get daily summaries, PR alerts, rest timer notifications, and your weekly recap.",
                    buttonLabel: "Enable Notifications",
                    action: {
                        Task {
                            await appState.notificationService.requestAuthorization()
                            withAnimation { page = 3 }
                        }
                    }
                ).tag(2)

                OnboardingFinalPage {
                    appState.isOnboardingComplete = true
                }.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)

            // Page dots
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0..<4) { i in
                        Circle()
                            .fill(i == page ? Color.accentBlue : Color.textTertiary)
                            .frame(width: 8, height: 8)
                            .animation(.spring(response: 0.3), value: page)
                    }
                }
                .padding(.bottom, 100)
            }
        }
    }
}

struct OnboardingPage: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let buttonLabel: String
    let action: () -> Void

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

            Button(action: action) {
                Text(buttonLabel)
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
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

struct OnboardingFinalPage: View {
    let onComplete: () -> Void
    @State private var showWhoopConnect = false

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

                Button {
                    onComplete()
                } label: {
                    Text("Skip for Now")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
        }
        .sheet(isPresented: $showWhoopConnect) {
            WhoopConnectView(onComplete: onComplete)
        }
    }
}
