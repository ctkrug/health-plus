import SwiftUI

struct RecoveryCard: View {
    let whoop: WhoopSnapshot
    let hk: HealthKitService

    private var recoveryValue: Double { whoop.recoveryScore ?? 0 }
    private var hrv: Double { whoop.hrv ?? hk.hrvMssd }
    private var rhr: Double { whoop.restingHR ?? hk.restingHR }
    private var isWhoopConnected: Bool { whoop.isConnected }
    private var recoveryColor: Color { Color.recoveryColor(for: recoveryValue) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Recovery", systemImage: "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                if isWhoopConnected {
                    Image("whoop_logo")
                        .resizable().scaledToFit().frame(height: 14)
                        .opacity(0.6)
                } else {
                    Text("WHOOP not connected")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                }
            }

            HStack(alignment: .center, spacing: 20) {
                // Big recovery ring
                ZStack {
                    RingView(progress: recoveryValue / 100, color: recoveryColor, lineWidth: 12, diameter: 90)
                    VStack(spacing: 2) {
                        Text(isWhoopConnected ? "\(Int(recoveryValue))" : "—")
                            .font(.metric(30))
                            .foregroundStyle(recoveryColor)
                        Text("%")
                            .font(.metricLabel(12))
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    MetricRow(label: "HRV", value: hrv > 0 ? "\(Int(hrv))" : "—", unit: "ms", color: .accentPurple)
                    MetricRow(label: "Resting HR", value: rhr > 0 ? "\(Int(rhr))" : "—", unit: "bpm")
                    if let strain = whoop.strain {
                        MetricRow(label: "Strain", value: String(format: "%.1f", strain), unit: "/21", color: .accentYellow)
                    }
                }
                Spacer()
            }

            if !isWhoopConnected {
                ConnectWhoopBanner()
            }
        }
        .card()
    }
}

struct ConnectWhoopBanner: View {
    @Environment(AppState.self) var appState
    @State private var showWhoopConnect = false

    var body: some View {
        Button {
            showWhoopConnect = true
        } label: {
            HStack {
                Image(systemName: "link.circle.fill")
                    .foregroundStyle(Color.accentBlue)
                Text("Connect WHOOP for recovery data")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.accentBlue)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(12)
            .background(Color.accentBlue.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .sheet(isPresented: $showWhoopConnect) {
            WhoopConnectView()
        }
    }
}
