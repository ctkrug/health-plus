import SwiftUI

struct HabitSetupChatView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var isFinishing = false
    @State private var conversationHistory: [ClaudeMessage] = []
    @State private var setupDone = false
    @State private var parsedHabits: [Habit] = []
    @FocusState private var inputFocused: Bool

    private var store: HabitStore { appState.habitStore }

    /// Whether the user has said enough that "Done" is worth offering.
    private var canFinish: Bool {
        conversationHistory.contains { $0.role == "user" } && !isLoading && !isFinishing
    }

    // The chat model ONLY converses — it never emits JSON. Turning the conversation into habits is a
    // separate, deterministic extraction step (forced tool use), so the model can't get stuck trying
    // to switch into "data mode" and the user is never asked to phrase a magic "that's everything".
    private let systemPrompt = """
    You are a warm, concise personal wellness coach helping someone set up their daily habits tracker. \
    Have a natural conversation to learn the habits they want to track across all areas of life: \
    morning routine, evening routine, fitness, mindfulness, nutrition, AM/PM skincare, supplements, \
    dental, hydration, sleep, and anything else.

    Rules:
    - Ask ONE question at a time, friendly and brief.
    - Move through the areas naturally; don't interrogate. It's fine to skip areas they clearly don't care about.
    - NEVER output JSON, code blocks, lists of fields, or any structured data. The app saves the habits \
    for them automatically — you only talk.
    - When the user signals they're finished (or you've covered the ground), reply with ONE short, warm \
    sentence letting them know they can tap Done to finish. Do not summarize every habit back to them.
    """

    /// System prompt for the separate extraction pass (a different, stronger model with forced tool use).
    private let extractionSystemPrompt = """
    You are a data-extraction step. Read the conversation between a wellness coach and a user, then call \
    the save_habits tool exactly once with every habit the user said they want to track.

    Guidance:
    - Include only habits the user actually mentioned or agreed to — do not invent extras.
    - For each, infer a sensible category, an SF Symbol icon, a hex color matching the category, and a \
    timeSlot (am / pm / anytime). Group related skincare/routine items with routineGroup when natural.
    - Suggested colors: morning #F59E0B, evening #8B5CF6, fitness #EF4444, mindfulness #10B981, \
    nutrition #F97316, sleep #6366F1, supplements #A855F7, skincareAM #F97316, skincareMP #8B5CF6, \
    dental #3B82F6, hydration #06B6D4, wellness #10B981.
    - Good icons: pills.fill, drop.fill, mouth.fill, heart.fill, sunrise.fill, moon.stars.fill, \
    flame.fill, figure.run, figure.mind.and.body, figure.strengthtraining.traditional, book.fill, \
    shower.fill, sparkles, wind, leaf.fill, fork.knife, bed.double.fill, brain.head.profile, \
    lungs.fill, stopwatch.fill, bolt.fill, eye.fill, pencil, star.fill.
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
                                if isLoading || isFinishing {
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
                        VStack(spacing: 10) {
                            // Deterministic finish — never rely on the model recognizing "I'm done".
                            if canFinish {
                                Button {
                                    finishSetup()
                                } label: {
                                    Label("Done — build my habits", systemImage: "checkmark.circle.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(Color.accentGreen.opacity(0.16))
                                        .foregroundStyle(Color.accentGreen)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }

                            HStack(spacing: 10) {
                                TextField("Message…", text: $inputText, axis: .vertical)
                                    .lineLimit(1...4)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .foregroundStyle(Color.textPrimary)
                                    .focused($inputFocused)
                                    .disabled(isFinishing)

                                Button {
                                    sendMessage()
                                } label: {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 34))
                                        .foregroundStyle(inputText.isEmpty || isLoading || isFinishing ? Color.textTertiary : Color.accentBlue)
                                }
                                .disabled(inputText.isEmpty || isLoading || isFinishing)
                            }
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

        // If the user signals they're finished, go straight to extraction instead of another chat
        // turn — so "that's everything" (and its many variations) just works, no loop.
        if looksLikeDone(text) {
            finishSetup()
            return
        }

        isLoading = true
        Task {
            do {
                let reply = try await ClaudeService.shared.send(
                    system: systemPrompt,
                    history: Array(conversationHistory.dropLast()),
                    userMessage: text
                )
                conversationHistory.append(ClaudeMessage(role: "assistant", content: reply))
                // The chat model never emits JSON now, but keep the sanitizer as a belt-and-braces
                // guard so a stray code block can never reach the user.
                messages.append(ChatMessage(role: .assistant, content: HabitSetupParser.sanitizedReply(reply)))
            } catch {
                messages.append(ChatMessage(role: .assistant, content: "Sorry, I hit an error: \(error.localizedDescription)"))
            }
            isLoading = false
        }
    }

    /// Turn the whole conversation into habits via a dedicated extraction pass (forced tool use on a
    /// stronger model). Deterministic — triggered by the Done button or an end-of-chat phrase, not by
    /// hoping the chat model decides to emit JSON.
    private func finishSetup() {
        guard !isFinishing, !isLoading else { return }
        inputFocused = false
        isFinishing = true
        Task {
            do {
                // Pass the whole chat as ONE user message. Replaying the multi-turn history would
                // often end on an assistant turn (e.g. when the user taps Done right after the coach's
                // question), and forced tool use rejects that with 400 "conversation must end with a
                // user message." A single user-role transcript always ends correctly.
                let transcript = conversationHistory
                    .map { "\($0.role == "user" ? "User" : "Coach"): \($0.content)" }
                    .joined(separator: "\n")
                let extractionMessages = [ClaudeMessage(
                    role: "user",
                    content: "Here is the full habit-setup conversation:\n\n\(transcript)\n\nExtract every habit the user wants to track and save them.")]

                let input = try await ClaudeService.shared.runTool(
                    model: ClaudeService.extractionModel,
                    system: extractionSystemPrompt,
                    messages: extractionMessages,
                    toolName: HabitSetupParser.toolName,
                    toolDescription: HabitSetupParser.toolDescription,
                    inputSchema: HabitSetupParser.inputSchema
                )
                if let habits = HabitSetupParser.buildHabits(from: input) {
                    parsedHabits = habits
                    messages.append(ChatMessage(role: .assistant,
                        content: "Perfect! I've put together \(habits.count) habit\(habits.count == 1 ? "" : "s") for you. Tap below to add them to your tracker."))
                    setupDone = true
                } else {
                    messages.append(ChatMessage(role: .assistant,
                        content: "I couldn't find any habits to add yet — tell me a bit more about what you'd like to track, then tap Done again."))
                }
            } catch {
                messages.append(ChatMessage(role: .assistant,
                    content: "I had trouble building your habits just now. Mind tapping Done once more?"))
            }
            isFinishing = false
        }
    }

    /// Broad, local end-of-conversation detection. The Done button is the guaranteed path; this just
    /// makes natural sign-offs ("that's everything", "I'm done", "nope, that's it") work too. Finishing
    /// is non-destructive (it shows a confirm screen), so a generous match is fine.
    private func looksLikeDone(_ text: String) -> Bool {
        let t = text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
        let phrases = [
            "that's everything", "thats everything", "that is everything",
            "that's it", "thats it", "that is it", "that's all", "thats all", "that is all",
            "i'm done", "im done", "i am done", "all done", "we're done", "were done",
            "nothing else", "no more", "that's enough", "thats enough", "that's it for now",
            "good for now", "i'm finished", "im finished", "i'm good", "im good", "all set",
        ]
        if phrases.contains(where: { t.contains($0) }) { return true }
        let exactShort: Set<String> = ["done", "finished", "finish", "complete", "yep that's it", "nope", "no thanks"]
        return t.split(separator: " ").count <= 3 && exactShort.contains(t)
    }

    private func reset() {
        messages = []
        conversationHistory = []
        parsedHabits = []
        setupDone = false
        isFinishing = false
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
