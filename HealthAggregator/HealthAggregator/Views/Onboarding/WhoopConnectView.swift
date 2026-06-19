import SwiftUI
import AuthenticationServices

struct WhoopConnectView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    var onComplete: (() -> Void)? = nil

    @State private var isConnecting = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                if appState.whoopService.isConnected {
                    connectedView
                } else {
                    connectView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.accentBlue)
                }
            }
        }
    }

    // MARK: - Already connected

    private var connectedView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle().fill(Color.accentGreen.opacity(0.15)).frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.accentGreen)
            }

            VStack(spacing: 10) {
                Text("WHOOP Connected")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text("Your recovery, strain, HRV, and sleep data is syncing to the Recovery tab.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            VStack(spacing: 14) {
                Button("Disconnect WHOOP", role: .destructive) {
                    appState.whoopService.disconnect()
                    dismiss()
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.accentRed)
            }
            .padding(.bottom, 50)
        }
    }

    // MARK: - Connect flow

    private var connectView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color(hex: "#1A1A2E"))
                    .frame(width: 100, height: 100)
                Text("W")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 12) {
                Text("Connect WHOOP")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text("Sign in to your WHOOP account to pull recovery scores, strain, HRV, and sleep data directly into Health+.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            VStack(alignment: .leading, spacing: 10) {
                WhoopFeatureRow(icon: "arrow.counterclockwise.circle.fill", color: .accentGreen, text: "Daily recovery score (0–100%)")
                WhoopFeatureRow(icon: "waveform.path.ecg.rectangle.fill", color: .accentPurple, text: "HRV and resting heart rate")
                WhoopFeatureRow(icon: "bolt.fill", color: .accentYellow, text: "Strain score and daily effort")
                WhoopFeatureRow(icon: "moon.fill", color: .accentBlue, text: "Sleep performance and stages")
            }
            .padding(16)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.accentRed)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    startConnect()
                } label: {
                    Group {
                        if isConnecting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Connect with WHOOP")
                                .font(.system(size: 17, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.accentBlue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(isConnecting)

                Button("Skip") { dismiss() }
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    private func startConnect() {
        isConnecting = true
        errorMessage = nil

        // Get the key window of the active scene as the presentation anchor
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard let window = activeScene?.windows.first(where: \.isKeyWindow) ?? activeScene?.windows.first
        else {
            errorMessage = "Could not present authentication"
            isConnecting = false
            return
        }

        Task {
            await appState.whoopService.startOAuthFlow(presenting: window)
            isConnecting = false
            if appState.whoopService.isConnected {
                onComplete?()
                dismiss()
            } else if let err = appState.whoopService.authError {
                errorMessage = err
            }
        }
    }
}

struct WhoopFeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color.textPrimary)
        }
    }
}
