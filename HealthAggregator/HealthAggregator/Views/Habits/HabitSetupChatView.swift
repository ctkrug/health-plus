import SwiftUI

struct HabitSetupChatView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var conversationHistory: [ClaudeMessage] = []
    @State private var setupDone = false
    @State private var parsedHabits: [Habit] = []
    @State private var showConfirm = false
    @FocusState private var inputFocused: Bool

    private var store: HabitStore { appState.habitStore }

    private let systemPrompt = """
    You are a personal wellness coach helping someone set up their daily habits tracker in a health app. \
    Your job is to have a friendly conversation to understand their wellness habits across all areas of life: \
    morning routine, evening routine, fitness, mindfulness, nutrition, skincare, supplements, dental, hydration, sleep, and more.

    Ask ONE question at a time, in a friendly and concise way. Cover:
    1. Morning routine (wake time habits, morning workout, journaling, meditation, etc.)
    2. Supplement stack (names of each supplement)
    3. AM skincare routine (cleanser, vitamin C serum, sunscreen, etc.)
    4. Fitness habits (workouts, steps, mobility, stretching)
    5. Nutrition habits (protein goal, no alcohol, meal prep, etc.)
    6. Mindfulness (meditation, breathing, gratitude, journaling)
    7. Evening/PM skincare routine (cleanser, retinol, moisturizer, etc.)
    8. Dental hygiene (floss, mouthwash, whitening strips)
    9. Hydration goal
    10. Sleep habits (consistent bedtime, no screens, sleep tracking)
    11. Any other habits they want to track

    After you have gathered all the information (usually 6-9 exchanges), output ONLY a JSON block in this exact format — \
    no prose before or after the JSON:

    ```json
    {
      "habits": [
        {
          "name": "Vitamin D",
          "category": "supplements",
          "icon": "pills.fill",
          "colorHex": "#A855F7",
          "timeSlot": "anytime"
        },
        {
          "name": "Morning Meditation",
          "category": "morning",
          "icon": "sunrise.fill",
          "colorHex": "#F59E0B",
          "timeSlot": "am"
        },
        {
          "name": "Cleanser",
          "category": "skincareAM",
          "icon": "drop.fill",
          "colorHex": "#F97316",
          "timeSlot": "am",
          "routineGroup": "AM Skincare"
        }
      ]
    }
    ```

    Valid category values: morning, evening, fitness, mindfulness, nutrition, sleep, supplements, skincareAM, skincareMP, dental, hydration, wellness, custom
    Valid timeSlot values: am, pm, anytime
    Valid icons (use these SF Symbol names): pills.fill, drop.fill, mouth.fill, heart.fill, heart.text.square.fill, \
    sun.max.fill, sunrise.fill, moon.stars.fill, moon.fill, flame.fill, figure.run, figure.mind.and.body, \
    figure.strengthtraining.traditional, book.fill, shower.fill, checkmark.circle.fill, sparkles, wind, leaf.fill, \
    fork.knife, bed.double.fill, brain.head.profile, lungs.fill, stopwatch.fill, trophy.fill, bolt.fill, \
    hand.raised.fill, eye.fill, music.note, pencil, star.fill

    Use colorHex values that match the category feel:
    morning → #F59E0B (amber), evening → #8B5CF6 (purple), fitness → #EF4444 (red), mindfulness → #10B981 (teal), \
    nutrition → #F97316 (orange), sleep → #6366F1 (indigo), supplements → #A855F7 (violet), \
    skincareAM → #F97316 (orange), skincareMP → #8B5CF6 (purple), dental → #3B82F6 (blue), \
    hydration → #06B6D4 (cyan), wellness → #10B981 (green)

    Once you output the JSON, you are done. Do not add any text after the JSON block.
    """

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.accentPurple)
                        Text("Habit Setup")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                        Text("Chat with your AI wellness coach to set up your daily habits")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.vertical, 20)
                    .background(Color.cardBackground)

                    // Messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(messages) { msg in
                                    ChatBubble(message: msg)
                                        .id(msg.id)
                                }
                                if isLoading {
                                    TypingIndicator()
                                }
                            }
                            .padding(16)
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let last = messages.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                    }

                    // Input
                    if !setupDone {
                        HStack(spacing: 10) {
                            TextField("Message…", text: $inputText, axis: .vertical)
                                .lineLimit(1...4)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .foregroundStyle(Color.textPrimary)
                                .focused($inputFocused)

                            Button {
                                sendMessage()
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 34))
                                    .foregroundStyle(inputText.isEmpty || isLoading ? Color.textTertiary : Color.accentBlue)
                            }
                            .disabled(inputText.isEmpty || isLoading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.appBackground)
                    } else {
                        // Confirm habits
                        VStack(spacing: 12) {
                            Text("\(parsedHabits.count) habits ready to add")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.textSecondary)
                            Button {
                                store.applyAIHabits(parsedHabits)
                                dismiss()
                            } label: {
                                Text("Set Up My Habits")
                                    .font(.system(size: 17, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 15)
                                    .background(Color.accentGreen)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            Button("Start Over") {
                                reset()
                            }
                            .foregroundStyle(Color.textTertiary)
                            .font(.system(size: 14))
                        }
                        .padding(16)
                        .background(Color.appBackground)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip") { dismiss() }
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
        .onAppear { startConversation() }
    }

    // MARK: - Logic

    private func startConversation() {
        guard messages.isEmpty else { return }
        let opening = "Hey! I'm your AI wellness coach. I'll help you set up your daily habits tracker in just a few questions. We'll cover your morning routine, workouts, nutrition, mindfulness, skincare, supplements, sleep, and more. Let's start — walk me through your ideal morning. What habits or rituals do you do (or want to do) right after waking up?"
        messages.append(ChatMessage(role: .assistant, content: opening))
        conversationHistory.append(ClaudeMessage(role: "assistant", content: opening))
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        messages.append(ChatMessage(role: .user, content: text))
        conversationHistory.append(ClaudeMessage(role: "user", content: text))
        isLoading = true

        Task {
            do {
                let reply = try await ClaudeService.shared.send(
                    system: systemPrompt,
                    history: Array(conversationHistory.dropLast()),
                    userMessage: text
                )
                conversationHistory.append(ClaudeMessage(role: "assistant", content: reply))

                if let habits = HabitSetupParser.parseHabits(from: reply) {
                    parsedHabits = habits
                    let summary = "Perfect! I've set up \(habits.count) habits for you. Tap below to add them all to your tracker."
                    messages.append(ChatMessage(role: .assistant, content: summary))
                    setupDone = true
                } else {
                    // Never show a raw JSON/code blob to the user — strip any fenced block first.
                    messages.append(ChatMessage(role: .assistant, content: HabitSetupParser.sanitizedReply(reply)))
                }
            } catch {
                messages.append(ChatMessage(role: .assistant, content: "Sorry, I hit an error: \(error.localizedDescription)"))
            }
            isLoading = false
        }
    }

    private func reset() {
        messages = []
        conversationHistory = []
        parsedHabits = []
        setupDone = false
        startConversation()
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 50) }

            if !isUser {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentPurple)
                    .frame(width: 28, height: 28)
                    .background(Color.accentPurple.opacity(0.15))
                    .clipShape(Circle())
            }

            Text(message.content)
                .font(.system(size: 15))
                .foregroundStyle(isUser ? .white : Color.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isUser ? Color.accentBlue : Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)

            if isUser { Spacer(minLength: 0).frame(width: 0) }
        }
    }
}

// MARK: - Typing indicator

struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundStyle(Color.accentPurple)
                .frame(width: 28, height: 28)
                .background(Color.accentPurple.opacity(0.15))
                .clipShape(Circle())

            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.textTertiary)
                        .frame(width: 7, height: 7)
                        .scaleEffect(phase == i ? 1.3 : 0.8)
                        .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.13), value: phase)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18))

            Spacer()
        }
        .onAppear { phase = 1 }
    }
}
