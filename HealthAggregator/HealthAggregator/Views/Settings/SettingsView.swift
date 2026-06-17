import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    @State private var workoutReminderEnabled = false
    @State private var workoutReminderHour = 7
    @State private var workoutReminderMinute = 0
    // workoutReminderMinute @State is synced from/to storedReminderMinute
    @State private var calorieGoal = "2500"
    @State private var proteinGoal = "180"
    @State private var weightUnit: WeightUnit = .lbs
    @State private var showWhoopConnect = false
    @AppStorage("calorieGoal") private var storedCalorieGoal = 2500.0
    @AppStorage("proteinGoalGrams") private var storedProteinGoal = 180.0
    @AppStorage("workoutReminderEnabled") private var storedReminderEnabled = false
    @AppStorage("workoutReminderHour") private var storedReminderHour = 7
    @AppStorage("workoutReminderMinute") private var storedReminderMinute = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                List {
                    // WHOOP
                    Section("Integrations") {
                        HStack {
                            Circle()
                                .fill(Color(hex: "#1A1A2E"))
                                .frame(width: 36, height: 36)
                                .overlay(Text("W").font(.system(size: 18, weight: .black)).foregroundStyle(.white))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("WHOOP")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                                Text(appState.whoopService.isConnected ? "Connected" : "Not connected")
                                    .font(.metricLabel(12))
                                    .foregroundStyle(appState.whoopService.isConnected ? Color.accentGreen : Color.textSecondary)
                            }
                            Spacer()
                            Button(appState.whoopService.isConnected ? "Manage" : "Connect") {
                                showWhoopConnect = true
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.accentBlue)
                        }
                        .listRowBackground(Color.cardBackground)

                        IntegrationRow(
                            icon: "scalemass.fill", color: .accentOrange,
                            name: "Renpho", status: "Enable Health sync in Renpho app"
                        )
                        IntegrationRow(
                            icon: "fork.knife", color: .accentGreen,
                            name: "MyFitnessPal", status: "Enable Health sync in MFP app"
                        )
                        IntegrationRow(
                            icon: "figure.pool.swim", color: .accentBlue,
                            name: "Swim.com", status: "Enable Health sync in Swim.com app"
                        )
                    }

                    // Nutrition goals
                    Section("Nutrition Goals") {
                        HStack {
                            Text("Calorie Goal")
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            TextField("kcal", text: $calorieGoal)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(Color.accentBlue)
                                .frame(width: 80)
                                .onChange(of: calorieGoal) { _, v in
                                    if let d = Double(v) { storedCalorieGoal = d }
                                }
                        }
                        .listRowBackground(Color.cardBackground)

                        HStack {
                            Text("Protein Goal")
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            TextField("grams", text: $proteinGoal)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(Color.accentBlue)
                                .frame(width: 80)
                                .onChange(of: proteinGoal) { _, v in
                                    if let d = Double(v) { storedProteinGoal = d }
                                }
                        }
                        .listRowBackground(Color.cardBackground)
                    }

                    // Notifications
                    Section("Notifications") {
                        Toggle("Workout Reminder", isOn: $workoutReminderEnabled)
                            .tint(Color.accentBlue)
                            .foregroundStyle(Color.textPrimary)
                            .onChange(of: workoutReminderEnabled) { _, v in
                                storedReminderEnabled = v
                                if v {
                                    appState.notificationService.scheduleWorkoutReminder(hour: workoutReminderHour, minute: workoutReminderMinute)
                                } else {
                                    appState.notificationService.cancelWorkoutReminder()
                                }
                            }
                            .listRowBackground(Color.cardBackground)

                        if workoutReminderEnabled {
                            DatePicker("Reminder Time",
                                       selection: Binding(
                                        get: { timeFromComponents(workoutReminderHour, workoutReminderMinute) },
                                        set: { d in
                                            workoutReminderHour = Calendar.current.component(.hour, from: d)
                                            workoutReminderMinute = Calendar.current.component(.minute, from: d)
                                            storedReminderHour = workoutReminderHour
                                            storedReminderMinute = workoutReminderMinute
                                            if workoutReminderEnabled {
                                                appState.notificationService.scheduleWorkoutReminder(hour: workoutReminderHour, minute: workoutReminderMinute)
                                            }
                                        }
                                       ),
                                       displayedComponents: .hourAndMinute)
                            .foregroundStyle(Color.textPrimary)
                            .listRowBackground(Color.cardBackground)
                        }
                    }

                    // Units
                    Section("Units") {
                        Picker("Weight Unit", selection: $weightUnit) {
                            Text("Pounds (lb)").tag(WeightUnit.lbs)
                            Text("Kilograms (kg)").tag(WeightUnit.kg)
                        }
                        .foregroundStyle(Color.textPrimary)
                        .listRowBackground(Color.cardBackground)
                    }

                    // AI
                    Section("AI Coach") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Anthropic API Key")
                                .foregroundStyle(Color.textPrimary)
                                .font(.system(size: 15))
                            SecureField("sk-ant-…", text: Binding(
                                get: { ClaudeService.shared.apiKey },
                                set: { ClaudeService.shared.apiKey = $0 }
                            ))
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Color.accentBlue)
                            Text("Used for the Habits AI setup chat. Get a key at console.anthropic.com.")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.cardBackground)
                    }

                    // About
                    Section("About") {
                        HStack {
                            Text("Version")
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Text("1.0.0")
                                .foregroundStyle(Color.textSecondary)
                        }
                        .listRowBackground(Color.cardBackground)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showWhoopConnect) {
                WhoopConnectView()
            }
            .onAppear {
                calorieGoal = "\(Int(storedCalorieGoal))"
                proteinGoal = "\(Int(storedProteinGoal))"
                workoutReminderEnabled = storedReminderEnabled
                workoutReminderHour = storedReminderHour
                workoutReminderMinute = storedReminderMinute
            }
        }
    }

    private func timeFromComponents(_ hour: Int, _ minute: Int) -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c) ?? Date()
    }
}

struct IntegrationRow: View {
    let icon: String
    let color: Color
    let name: String
    let status: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                Text(status)
                    .font(.metricLabel(12))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundStyle(Color.textTertiary)
        }
        .listRowBackground(Color.cardBackground)
    }
}
