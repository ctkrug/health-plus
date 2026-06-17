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
    Your job is to ask them a few conversational questions to understand their supplement stack, skincare routine, \
    dental hygiene, hydration goals, and any other wellness habits they want to track.

    Ask ONE question at a time, in a friendly and concise way. Cover:
    1. Their supplement stack (names of each supplement)
    2. Their AM skincare routine (each product step: e.g. cleanser, vitamin C serum, sunscreen)
    3. Their PM skincare routine (each product step: e.g. cleanser, retinol, moisturizer)
    4. Dental: do they floss, mouthwash, whitening strips?
    5. Water intake goal (or just a daily water habit)
    6. Any other wellness habits (meditation, journaling, cold shower, etc.)

    After you have gathered all the information (usually 5-7 exchanges), output ONLY a JSON block in this exact format — \
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

    Valid category values: supplements, skincareAM, skincareMP, dental, hydration, wellness, custom
    Valid timeSlot values: am, pm, anytime
    Valid icons (use these SF Symbol names): pills.fill, drop.fill, mouth.fill, heart.fill, sun.max.fill, \
    moon.stars.fill, flame.fill, figure.mind.and.body, book.fill, shower.fill, checkmark.circle.fill, \
    sparkles, wind, leaf.fill

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
        let opening = "Hey! I'm your AI wellness coach. I'll help you set up your daily habits tracker in just a few questions. Let's start — what supplements do you take each day? List them all and I'll add each one individually."
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

                if let habits = parseHabits(from: reply) {
                    parsedHabits = habits
                    let summary = "Perfect! I've set up \(habits.count) habits for you. Tap below to add them all to your tracker."
                    messages.append(ChatMessage(role: .assistant, content: summary))
                    setupDone = true
                } else {
                    messages.append(ChatMessage(role: .assistant, content: reply))
                }
            } catch {
                messages.append(ChatMessage(role: .assistant, content: "Sorry, I hit an error: \(error.localizedDescription)"))
            }
            isLoading = false
        }
    }

    private func parseHabits(from text: String) -> [Habit]? {
        // Extract JSON block from response
        guard let start = text.range(of: "```json"),
              let end = text.range(of: "```", range: start.upperBound..<text.endIndex) else { return nil }
        let jsonStr = String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let habitsArr = json["habits"] as? [[String: Any]] else { return nil }

        return habitsArr.compactMap { dict -> Habit? in
            guard let name = dict["name"] as? String,
                  let catStr = dict["category"] as? String,
                  let category = categoryFromString(catStr) else { return nil }
            let icon = dict["icon"] as? String ?? category.icon
            let colorHex = dict["colorHex"] as? String ?? category.colorHex
            let slotStr = (dict["timeSlot"] as? String ?? "anytime").lowercased()
            let slot: HabitTimeSlot = slotStr == "am" ? .am : slotStr == "pm" ? .pm : .anytime
            let group = dict["routineGroup"] as? String
            return Habit(name: name, category: category, icon: icon, colorHex: colorHex,
                         timeSlot: slot, routineGroup: group)
        }
    }

    private func categoryFromString(_ s: String) -> HabitCategory? {
        switch s.lowercased() {
        case "supplements":                          return .supplements
        case "skineream", "skincare_am", "am skincare", "skincaream": return .skincareAM
        case "skincaremp", "skincare_pm", "pm skincare", "skincarepm": return .skincareMP
        case "dental":                               return .dental
        case "hydration":                            return .hydration
        case "wellness":                             return .wellness
        default:                                     return .custom
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
