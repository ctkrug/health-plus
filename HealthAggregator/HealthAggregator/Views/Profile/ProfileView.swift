import SwiftUI

/// Combined Profile + Settings hub. Opened from the avatar in the Home (Today) header.
/// Shows who you are + quick stats up top, then every app setting below
/// (appearance, integrations, goals, notifications, workout defaults, units, account).
struct ProfileView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    // Profile
    @AppStorage("profileEmoji") private var profileEmoji = "💪"
    @State private var nameDraft = ""
    @State private var isEditingName = false

    // Goals (mirrored to storage)
    @State private var calorieGoal = "2500"
    @State private var proteinGoal = "180"
    @State private var stepGoal = "10000"
    // Notifications
    @State private var workoutReminderEnabled = false
    @State private var workoutReminderHour = 7
    @State private var workoutReminderMinute = 0
    @State private var showWhoopConnect = false

    @AppStorage("calorieGoal") private var storedCalorieGoal = 2500.0
    @AppStorage("stepGoal") private var storedStepGoal = 10000.0
    @AppStorage("weightUnit") private var storedWeightUnit = "lbs"
    @AppStorage("proteinGoalGrams") private var storedProteinGoal = 180.0
    @AppStorage("workoutReminderEnabled") private var storedReminderEnabled = false
    @AppStorage("workoutReminderHour") private var storedReminderHour = 7
    @AppStorage("workoutReminderMinute") private var storedReminderMinute = 0
    @AppStorage("appearanceMode") private var appearanceMode = AppAppearance.system.rawValue
    @AppStorage("defaultSets") private var defaultSets = 3
    @AppStorage("defaultMinReps") private var defaultMinReps = 8
    @AppStorage("defaultMaxReps") private var defaultMaxReps = 12
    @AppStorage("defaultRestSeconds") private var defaultRestSeconds = 180

    private let emojiChoices = ["💪", "🏋️", "🔥", "⚡️", "🏃", "🧘", "🦾", "🥇", "😤", "🦍", "🐺", "🚀"]

    private var store: WorkoutStore { appState.workoutStore }
    private var auth: AuthService { appState.authService }

    private var profileName: String {
        auth.displayName.isEmpty ? "Athlete" : auth.displayName
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                List {
                    profileSection
                    statsSection

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

                    // Integrations
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
                        goalRow(label: "Step Goal", text: $stepGoal, placeholder: "steps") {
                            if let d = Double($0) { storedStepGoal = d }
                        }
                        goalRow(label: "Calorie Goal", text: $calorieGoal, placeholder: "kcal") {
                            if let d = Double($0) { storedCalorieGoal = d }
                        }
                        goalRow(label: "Protein Goal", text: $proteinGoal, placeholder: "grams") {
                            if let d = Double($0) { storedProteinGoal = d }
                        }
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
                                            appState.notificationService.scheduleWorkoutReminder(hour: workoutReminderHour, minute: workoutReminderMinute)
                                        }
                                       ),
                                       displayedComponents: .hourAndMinute)
                            .foregroundStyle(Color.textPrimary)
                            .listRowBackground(Color.cardBackground)
                        }
                    }

                    // Workout defaults
                    Section("Workout Defaults") {
                        HStack {
                            Text("Default Sets").foregroundStyle(Color.textPrimary)
                            Spacer()
                            Stepper("\(defaultSets)", value: $defaultSets, in: 1...6)
                                .fixedSize()
                                .foregroundStyle(Color.textPrimary)
                        }
                        .listRowBackground(Color.cardBackground)

                        HStack {
                            Text("Rep Range").foregroundStyle(Color.textPrimary)
                            Spacer()
                            HStack(spacing: 4) {
                                Stepper("", value: $defaultMinReps, in: 1...50)
                                    .labelsHidden().fixedSize()
                                Text("\(defaultMinReps)–\(defaultMaxReps)")
                                    .foregroundStyle(Color.accentBlue)
                                    .font(.system(size: 15, weight: .medium))
                                    .frame(minWidth: 56, alignment: .center)
                                Stepper("", value: $defaultMaxReps, in: 1...50)
                                    .labelsHidden().fixedSize()
                            }
                        }
                        .listRowBackground(Color.cardBackground)

                        HStack {
                            Text("Rest Timer").foregroundStyle(Color.textPrimary)
                            Spacer()
                            HStack(spacing: 4) {
                                Stepper("", value: $defaultRestSeconds, in: 30...600, step: 15)
                                    .labelsHidden().fixedSize()
                                Text(restLabel(defaultRestSeconds))
                                    .foregroundStyle(Color.accentBlue)
                                    .font(.system(size: 15, weight: .medium))
                                    .frame(minWidth: 56, alignment: .trailing)
                            }
                        }
                        .listRowBackground(Color.cardBackground)

                        Button(role: .destructive) {
                            store.resetToUserWorkouts()
                        } label: {
                            Label("Reset to My Workouts (A/B/C)", systemImage: "arrow.counterclockwise")
                                .font(.system(size: 14))
                        }
                        .listRowBackground(Color.cardBackground)
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
                        if auth.isSignedIn && !auth.isGuest {
                            HStack {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Color.accentPurple)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(auth.displayName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.textPrimary)
                                    if !auth.email.isEmpty {
                                        Text(auth.email)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.textSecondary)
                                    }
                                }
                                Spacer()
                                Button("Sign Out") {
                                    auth.signOut()
                                    appState.isOnboardingComplete = false
                                }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.accentRed)
                            }
                        } else {
                            Text(auth.isGuest ? "Signed in as Guest — data is local only." : "Not signed in.")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                    .listRowBackground(Color.cardBackground)

                    // About
                    Section("About") {
                        HStack {
                            Text("Version").foregroundStyle(Color.textPrimary)
                            Spacer()
                            Text(appVersion).foregroundStyle(Color.textSecondary)
                        }
                        .listRowBackground(Color.cardBackground)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showWhoopConnect) { WhoopConnectView() }
            .onAppear { syncFromStorage() }
        }
    }

    // MARK: - Profile header

    @ViewBuilder
    private var profileSection: some View {
        Section {
            VStack(spacing: 14) {
                // Avatar + emoji picker
                Menu {
                    ForEach(emojiChoices, id: \.self) { e in
                        Button { profileEmoji = e } label: { Text("\(e)  Set avatar") }
                    }
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(Color.accentBlue.opacity(0.18))
                            .frame(width: 84, height: 84)
                            .overlay(Text(profileEmoji).font(.system(size: 40)))
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.accentBlue)
                            .background(Circle().fill(Color.cardBackground))
                    }
                }

                // Editable name
                if isEditingName {
                    HStack {
                        TextField("Your name", text: $nameDraft)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                            .multilineTextAlignment(.center)
                            .submitLabel(.done)
                            .onSubmit { commitName() }
                        Button("Save") { commitName() }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.accentBlue)
                    }
                } else {
                    Button {
                        nameDraft = profileName
                        isEditingName = true
                    } label: {
                        HStack(spacing: 6) {
                            Text(profileName)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Color.textPrimary)
                            Image(systemName: "pencil")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                if !auth.email.isEmpty {
                    Text(auth.email)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Quick stats

    @ViewBuilder
    private var statsSection: some View {
        Section {
            HStack(spacing: 0) {
                ProfileStat(value: "\(store.sessions.count)", label: "Workouts", color: .accentBlue)
                Divider().frame(height: 38).overlay(Color.separatorColor)
                ProfileStat(value: "\(store.streak.currentDays)", label: "Day Streak", color: .accentOrange)
                Divider().frame(height: 38).overlay(Color.separatorColor)
                ProfileStat(value: "\(store.sessionsThisWeek().count)", label: "This Week", color: .accentGreen)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.cardBackground)
        }
    }

    @ViewBuilder
    private func goalRow(label: String, text: Binding<String>, placeholder: String, onChange: @escaping (String) -> Void) -> some View {
        HStack {
            Text(label).foregroundStyle(Color.textPrimary)
            Spacer()
            TextField(placeholder, text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Color.accentBlue)
                .frame(width: 80)
                .onChange(of: text.wrappedValue) { _, v in onChange(v) }
        }
        .listRowBackground(Color.cardBackground)
    }

    // MARK: - Helpers

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return b.isEmpty ? v : "\(v) (\(b))"
    }

    private func restLabel(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60, s = seconds % 60
        return s == 0 ? "\(m)m" : "\(m)m \(s)s"
    }

    private func commitName() {
        auth.updateDisplayName(nameDraft)
        isEditingName = false
    }

    private func timeFromComponents(_ hour: Int, _ minute: Int) -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c) ?? Date()
    }

    private func syncFromStorage() {
        calorieGoal = "\(Int(storedCalorieGoal))"
        proteinGoal = "\(Int(storedProteinGoal))"
        stepGoal = "\(Int(storedStepGoal))"
        workoutReminderEnabled = storedReminderEnabled
        workoutReminderHour = storedReminderHour
        workoutReminderMinute = storedReminderMinute
    }
}

private struct ProfileStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.metric(22)).foregroundStyle(color)
            Text(label).font(.metricLabel(11)).foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

// MARK: - Reusable avatar (Home header + profile)

struct ProfileAvatar: View {
    var diameter: CGFloat = 34
    @AppStorage("profileEmoji") private var profileEmoji = "💪"

    var body: some View {
        Circle()
            .fill(Color.accentBlue.opacity(0.18))
            .frame(width: diameter, height: diameter)
            .overlay(Text(profileEmoji).font(.system(size: diameter * 0.5)))
            .overlay(Circle().strokeBorder(Color.cardBorder, lineWidth: 0.5))
    }
}

// MARK: - Integration row (third-party setup instructions)

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
                        Text("How to connect \(name) to HealthSync")
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
