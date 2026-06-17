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

                VStack(spacing: 28) {
                    Spacer()

                    // WHOOP logo placeholder
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

                    // What you'll get
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

                        if appState.whoopService.isConnected {
                            Button("Disconnect WHOOP", role: .destructive) {
                                appState.whoopService.disconnect()
                                dismiss()
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.accentRed)
                        }

                        Button("Skip") { dismiss() }
                            .font(.system(size: 15))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func startConnect() {
        isConnecting = true
        errorMessage = nil

        // Get the key window as anchor
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first
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
