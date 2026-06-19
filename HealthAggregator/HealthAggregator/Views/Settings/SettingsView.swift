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
    @State private var stepGoal = "10000"
    @State private var showWhoopConnect = false
    @AppStorage("calorieGoal") private var storedCalorieGoal = 2500.0
    @AppStorage("stepGoal") private var storedStepGoal = 10000.0
    @AppStorage("weightUnit") private var storedWeightUnit = "lbs"
    @AppStorage("proteinGoalGrams") private var storedProteinGoal = 180.0
    @AppStorage("workoutReminderEnabled") private var storedReminderEnabled = false
    @AppStorage("workoutReminderHour") private var storedReminderHour = 7
    @AppStorage("workoutReminderMinute") private var storedReminderMinute = 0
    @AppStorage("appearanceMode") private var appearanceMode = AppAppearance.system.rawValue

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                List {
                    // Appearance
                    Section("Appearance") {
                        Picker(selection: $appearanceMode) {
                            ForEach(AppAppearance.allCases) { mode in
                                Label(mode.label, systemImage: mode.icon).tag(mode.rawValue)
                            }
                        } label: {
                            Text("Theme").foregroundStyle(Color.textPrimary)
                        }
                        .pickerStyle(.menu)
                        .tint(Color.accentBlue)
                        .listRowBackground(Color.cardBackground)
                    }

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
                            name: "Renpho", status: "Tap for setup instructions",
                            instructions: "1. Open the Renpho app\n2. Go to Me → Settings\n3. Enable Apple Health sync\n4. Grant read/write access"
                        )
                        IntegrationRow(
                            icon: "fork.knife", color: .accentGreen,
                            name: "MyFitnessPal", status: "Tap for setup instructions",
                            instructions: "1. Open MyFitnessPal\n2. Go to More → Apps & Devices\n3. Connect Apple Health\n4. Enable nutrition sync"
                        )
                        IntegrationRow(
                            icon: "figure.pool.swim", color: .accentBlue,
                            name: "Swim.com", status: "Tap for setup instructions",
                            instructions: "1. Open Swim.com\n2. Go to Profile → Connections\n3. Connect Apple Health\n4. Enable workout sync"
                        )
                    }

                    // Daily goals
                    Section("Daily Goals") {
                        HStack {
                            Text("Step Goal")
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            TextField("steps", text: $stepGoal)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(Color.accentBlue)
                                .frame(width: 80)
                                .onChange(of: stepGoal) { _, v in
                                    if let d = Double(v) { storedStepGoal = d }
                                }
                        }
                        .listRowBackground(Color.cardBackground)

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
                        Picker("Weight Unit", selection: $storedWeightUnit) {
                            Text("Pounds (lb)").tag("lbs")
                            Text("Kilograms (kg)").tag("kg")
                        }
                        .foregroundStyle(Color.textPrimary)
                        .listRowBackground(Color.cardBackground)
                    }

                    // Account
                    Section("Account") {
                        if appState.authService.isSignedIn && !appState.authService.isGuest {
                            HStack {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Color.accentPurple)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(appState.authService.displayName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.textPrimary)
                                    if !appState.authService.email.isEmpty {
                                        Text(appState.authService.email)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.textSecondary)
                                    }
                                }
                                Spacer()
                                Button("Sign Out") {
                                    appState.authService.signOut()
                                    appState.isOnboardingComplete = false
                                }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.accentRed)
                            }
                        } else {
                            Text(appState.authService.isGuest ? "Signed in as Guest — data is local only." : "Not signed in.")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                    .listRowBackground(Color.cardBackground)

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
                stepGoal = "\(Int(storedStepGoal))"
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
    var instructions: String? = nil
    @State private var showInstructions = false

    var body: some View {
        Button {
            if instructions != nil { showInstructions = true }
        } label: {
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
        }
        .listRowBackground(Color.cardBackground)
        .sheet(isPresented: $showInstructions) {
            NavigationStack {
                ZStack {
                    Color.appBackground.ignoresSafeArea()
                    VStack(alignment: .leading, spacing: 20) {
                        Label(name, systemImage: icon)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(color)
                        Text("How to connect \(name) to Health+")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text(instructions ?? "")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.textSecondary)
                            .lineSpacing(6)
                        Spacer()
                    }
                    .padding(24)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showInstructions = false }
                    }
                }
            }
        }
    }
}
