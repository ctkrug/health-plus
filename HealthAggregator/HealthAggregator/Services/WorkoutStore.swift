import CoreData
import SwiftUI
import WidgetKit

@Observable
final class WorkoutStore {
    private let container: NSPersistentContainer
    private(set) var sessions: [WorkoutSession] = []
    private(set) var templates: [WorkoutTemplate] = []
    private(set) var personalRecords: [String: PersonalRecord] = [:]
    private(set) var programs: [TrainingProgram] = []

    var currentSession: WorkoutSession? = nil
    var isInWorkout = false
    var activeProgram: TrainingProgram? { programs.first { $0.isActive } }

    init() {
        container = NSPersistentContainer(name: "HealthAggregator", managedObjectModel: WorkoutStore.makeModel())
        container.loadPersistentStores { _, error in
            if let error { print("Core Data error: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        loadFromDisk()
        if templates.isEmpty { seedDefaultTemplates() }
        if programs.isEmpty { seedBuiltInPrograms() }
    }

    // MARK: - Core Data Model (programmatic, no .xcdatamodeld needed)

    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // WorkoutSessionEntity
        let sessionEntity = NSEntityDescription()
        sessionEntity.name = "WorkoutSessionEntity"
        sessionEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        let sessionAttrs: [(String, NSAttributeType)] = [
            ("id", .UUIDAttributeType),
            ("name", .stringAttributeType),
            ("workoutType", .stringAttributeType),
            ("startDate", .dateAttributeType),
            ("endDate", .dateAttributeType),
            ("notes", .stringAttributeType),
            ("totalVolumeKg", .doubleAttributeType),
            ("jsonData", .binaryDataAttributeType),
        ]
        sessionEntity.properties = sessionAttrs.map { attr(name: $0.0, type: $0.1) }

        // PersonalRecordEntity
        let prEntity = NSEntityDescription()
        prEntity.name = "PersonalRecordEntity"
        prEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        let prAttrs: [(String, NSAttributeType)] = [
            ("id", .UUIDAttributeType),
            ("exerciseName", .stringAttributeType),
            ("weightKg", .doubleAttributeType),
            ("reps", .integer32AttributeType),
            ("estimated1RM", .doubleAttributeType),
            ("date", .dateAttributeType),
            ("sessionID", .UUIDAttributeType),
        ]
        prEntity.properties = prAttrs.map { attr(name: $0.0, type: $0.1) }

        // WorkoutTemplateEntity
        let templateEntity = NSEntityDescription()
        templateEntity.name = "WorkoutTemplateEntity"
        templateEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        templateEntity.properties = [
            attr(name: "id", type: .UUIDAttributeType),
            attr(name: "jsonData", type: .binaryDataAttributeType),
        ]

        // TrainingProgramEntity
        let programEntity = NSEntityDescription()
        programEntity.name = "TrainingProgramEntity"
        programEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        programEntity.properties = [
            attr(name: "id", type: .UUIDAttributeType),
            attr(name: "jsonData", type: .binaryDataAttributeType),
        ]

        model.entities = [sessionEntity, prEntity, templateEntity, programEntity]
        return model
    }

    private static func attr(name: String, type: NSAttributeType) -> NSAttributeDescription {
        let a = NSAttributeDescription()
        a.name = name
        a.attributeType = type
        a.isOptional = true
        return a
    }

    // MARK: - Session management

    func startWorkout(from template: WorkoutTemplate) -> WorkoutSession {
        var session = template.toSession()
        session.startDate = Date()
        currentSession = session
        isInWorkout = true
        return session
    }

    func startEmptyWorkout(name: String, type: WorkoutType) -> WorkoutSession {
        let session = WorkoutSession(name: name, type: type, startDate: Date())
        currentSession = session
        isInWorkout = true
        return session
    }

    func completeWorkout(_ session: WorkoutSession, fromProgram: Bool = false) {
        var finished = session
        finished.endDate = Date()
        finished.totalVolumeKg = session.exercises.reduce(0) { $0 + $1.totalVolume }
        detectPRs(in: &finished)   // mark isPR on sets before saving
        saveSession(finished)
        sessions.insert(finished, at: 0)
        currentSession = nil
        isInWorkout = false
        updateTemplateLastUsed(session.name)
        if fromProgram { advanceActiveProgram() }
        writeWidgetWorkoutData(finished)
    }

    func discardCurrentWorkout() {
        currentSession = nil
        isInWorkout = false
    }

    func deleteSession(_ session: WorkoutSession) {
        sessions.removeAll { $0.id == session.id }
        deleteSessionFromDisk(session.id)
    }

    // MARK: - Template management

    func saveTemplate(_ template: WorkoutTemplate) {
        if let idx = templates.firstIndex(where: { $0.id == template.id }) {
            templates[idx] = template
        } else {
            templates.append(template)
        }
        saveTemplateToDisk(template)
    }

    func deleteTemplate(_ template: WorkoutTemplate) {
        templates.removeAll { $0.id == template.id }
        deleteTemplateFromDisk(template.id)
    }

    private func updateTemplateLastUsed(_ name: String) {
        if let idx = templates.firstIndex(where: { $0.name == name }) {
            templates[idx].lastUsed = Date()
            templates[idx].useCount += 1
            saveTemplateToDisk(templates[idx])
        }
    }

    // MARK: - Program management

    func saveProgram(_ program: TrainingProgram) {
        if let idx = programs.firstIndex(where: { $0.id == program.id }) {
            programs[idx] = program
        } else {
            programs.append(program)
        }
        saveProgramToDisk(program)
    }

    func deleteProgram(_ program: TrainingProgram) {
        programs.removeAll { $0.id == program.id }
        deleteProgramFromDisk(program.id)
    }

    func setActiveProgram(_ program: TrainingProgram) {
        for i in programs.indices {
            programs[i].isActive = programs[i].id == program.id
        }
        // Save all in a single pass so a force-kill can't leave two programs active
        programs.forEach { saveProgramToDisk($0) }
    }

    func advanceActiveProgram() {
        guard let idx = programs.firstIndex(where: { $0.isActive }) else { return }
        programs[idx].advance()
        saveProgramToDisk(programs[idx])
    }

    /// Start session from the active program's next workout, pre-populated with smart weights
    func startProgramWorkout() -> WorkoutSession? {
        guard let prog = activeProgram,
              let pw = prog.nextWorkout else { return nil }
        let session = ProgressionEngine.populateSession(programWorkout: pw, history: sessions)
        currentSession = session
        isInWorkout = true
        return session
    }

    /// Get a progression suggestion for an exercise in the current session
    func suggestion(for exerciseName: String, rule: ProgressionRule) -> ProgressionSuggestion {
        ProgressionEngine.suggestion(for: exerciseName, rule: rule, history: sessions)
    }

    // MARK: - PR Detection

    private func detectPRs(in session: inout WorkoutSession) {
        for exIdx in session.exercises.indices {
            for setIdx in session.exercises[exIdx].sets.indices {
                var workoutSet = session.exercises[exIdx].sets[setIdx]
                guard workoutSet.isCompleted, let e1rm = workoutSet.estimated1RM else { continue }
                let name = session.exercises[exIdx].name
                let current = personalRecords[name]
                if current == nil || e1rm > (current?.estimated1RM ?? 0) {
                    workoutSet.isPR = true
                    session.exercises[exIdx].sets[setIdx] = workoutSet
                    let pr = PersonalRecord(
                        exerciseName: name,
                        weightKg: workoutSet.weightKg ?? 0,
                        reps: workoutSet.reps ?? 0,
                        estimated1RM: e1rm,
                        date: Date(),
                        sessionID: session.id
                    )
                    personalRecords[name] = pr
                    savePRToDisk(pr)
                }
            }
        }
    }

    func isPR(exerciseName: String, estimated1RM: Double) -> Bool {
        guard let current = personalRecords[exerciseName] else { return true }
        return estimated1RM > current.estimated1RM
    }

    // MARK: - Analytics

    var streak: WorkoutStreak {
        let calendar = Calendar.current
        let sorted = sessions.sorted { $0.startDate > $1.startDate }
        guard let first = sorted.first else { return WorkoutStreak(currentDays: 0, longestDays: 0, lastWorkoutDate: nil) }

        // Deduplicate to one entry per calendar day, newest first
        var uniqueDays: [Date] = []
        for session in sorted {
            let day = calendar.startOfDay(for: session.startDate)
            if uniqueDays.last != day { uniqueDays.append(day) }
        }

        // Current streak: contiguous days from today backwards
        var current = 0
        var checkDate = calendar.startOfDay(for: Date())
        for day in uniqueDays {
            if day == checkDate {
                current += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }

        // Longest streak: scan full history chronologically
        var longest = 0
        var run = 0
        var prevDay: Date? = nil
        for day in uniqueDays.reversed() {
            if let prev = prevDay,
               calendar.date(byAdding: .day, value: 1, to: prev) == day {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
            prevDay = day
        }

        return WorkoutStreak(currentDays: current, longestDays: max(longest, current), lastWorkoutDate: first.startDate)
    }

    func weeklyVolume(for exerciseName: String, weeks: Int = 8) -> [(Date, Double)] {
        let calendar = Calendar.current
        return (0..<weeks).map { weekOffset in
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: Date())!
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
            let volume = sessions
                .filter { $0.startDate >= weekStart && $0.startDate < weekEnd }
                .flatMap(\.exercises)
                .filter { $0.name == exerciseName }
                .reduce(0) { $0 + $1.totalVolume }
            return (weekStart, volume)
        }.reversed()
    }

    func sessionsThisWeek() -> [WorkoutSession] {
        guard let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else {
            return []
        }
        return sessions.filter { weekInterval.contains($0.startDate) }
    }

    // MARK: - Persistence (JSON-backed Core Data blobs)

    private func loadFromDisk() {
        let ctx = container.viewContext
        loadPrograms(ctx: ctx)

        // Sessions
        let sessionFetch = NSFetchRequest<NSManagedObject>(entityName: "WorkoutSessionEntity")
        sessionFetch.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        let sessionObjs = (try? ctx.fetch(sessionFetch)) ?? []
        sessions = sessionObjs.compactMap { obj in
            guard let data = obj.value(forKey: "jsonData") as? Data else { return nil }
            return try? JSONDecoder().decode(WorkoutSession.self, from: data)
        }

        // Templates
        let templateFetch = NSFetchRequest<NSManagedObject>(entityName: "WorkoutTemplateEntity")
        let templateObjs = (try? ctx.fetch(templateFetch)) ?? []
        templates = templateObjs.compactMap { obj in
            guard let data = obj.value(forKey: "jsonData") as? Data else { return nil }
            return try? JSONDecoder().decode(WorkoutTemplate.self, from: data)
        }

        // PRs
        let prFetch = NSFetchRequest<NSManagedObject>(entityName: "PersonalRecordEntity")
        let prObjs = (try? ctx.fetch(prFetch)) ?? []
        let prs = prObjs.compactMap { obj -> PersonalRecord? in
            guard let name = obj.value(forKey: "exerciseName") as? String,
                  let weightKg = obj.value(forKey: "weightKg") as? Double,
                  let reps = obj.value(forKey: "reps") as? Int32,
                  let e1rm = obj.value(forKey: "estimated1RM") as? Double,
                  let date = obj.value(forKey: "date") as? Date,
                  let sessionID = obj.value(forKey: "sessionID") as? UUID,
                  let id = obj.value(forKey: "id") as? UUID
            else { return nil }
            return PersonalRecord(id: id, exerciseName: name, weightKg: weightKg, reps: Int(reps), estimated1RM: e1rm, date: date, sessionID: sessionID)
        }
        personalRecords = Dictionary(prs.map { ($0.exerciseName, $0) }, uniquingKeysWith: { a, b in a.estimated1RM > b.estimated1RM ? a : b })
    }

    private func saveSession(_ session: WorkoutSession) {
        let ctx = container.viewContext
        guard let data = try? JSONEncoder().encode(session) else { return }

        let fetch = NSFetchRequest<NSManagedObject>(entityName: "WorkoutSessionEntity")
        fetch.predicate = NSPredicate(format: "id == %@", session.id as CVarArg)
        let existing = (try? ctx.fetch(fetch))?.first ?? NSManagedObject(entity: container.managedObjectModel.entitiesByName["WorkoutSessionEntity"]!, insertInto: ctx)

        existing.setValue(session.id, forKey: "id")
        existing.setValue(session.name, forKey: "name")
        existing.setValue(session.startDate, forKey: "startDate")
        existing.setValue(session.endDate, forKey: "endDate")
        existing.setValue(data, forKey: "jsonData")
        try? ctx.save()
    }

    private func deleteSessionFromDisk(_ id: UUID) {
        let ctx = container.viewContext
        let fetch = NSFetchRequest<NSManagedObject>(entityName: "WorkoutSessionEntity")
        fetch.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let obj = (try? ctx.fetch(fetch))?.first { ctx.delete(obj) }
        try? ctx.save()
    }

    private func saveTemplateToDisk(_ template: WorkoutTemplate) {
        let ctx = container.viewContext
        guard let data = try? JSONEncoder().encode(template) else { return }

        let fetch = NSFetchRequest<NSManagedObject>(entityName: "WorkoutTemplateEntity")
        fetch.predicate = NSPredicate(format: "id == %@", template.id as CVarArg)
        let existing = (try? ctx.fetch(fetch))?.first ?? NSManagedObject(entity: container.managedObjectModel.entitiesByName["WorkoutTemplateEntity"]!, insertInto: ctx)

        existing.setValue(template.id, forKey: "id")
        existing.setValue(data, forKey: "jsonData")
        try? ctx.save()
    }

    private func deleteTemplateFromDisk(_ id: UUID) {
        let ctx = container.viewContext
        let fetch = NSFetchRequest<NSManagedObject>(entityName: "WorkoutTemplateEntity")
        fetch.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let obj = (try? ctx.fetch(fetch))?.first { ctx.delete(obj) }
        try? ctx.save()
    }

    private func savePRToDisk(_ pr: PersonalRecord) {
        let ctx = container.viewContext
        let fetch = NSFetchRequest<NSManagedObject>(entityName: "PersonalRecordEntity")
        fetch.predicate = NSPredicate(format: "exerciseName == %@", pr.exerciseName)
        let existing = (try? ctx.fetch(fetch))?.first ?? NSManagedObject(entity: container.managedObjectModel.entitiesByName["PersonalRecordEntity"]!, insertInto: ctx)

        existing.setValue(pr.id, forKey: "id")
        existing.setValue(pr.exerciseName, forKey: "exerciseName")
        existing.setValue(pr.weightKg, forKey: "weightKg")
        existing.setValue(Int32(pr.reps), forKey: "reps")
        existing.setValue(pr.estimated1RM, forKey: "estimated1RM")
        existing.setValue(pr.date, forKey: "date")
        existing.setValue(pr.sessionID, forKey: "sessionID")
        try? ctx.save()
    }

    private func seedDefaultTemplates() {
        let defaults = ExerciseLibrary.defaultTemplates
        defaults.forEach { saveTemplate($0) }
        templates = defaults  // same instances — UUIDs match what was saved to disk
    }

    private func seedBuiltInPrograms() {
        var prog = ExerciseLibrary.strongerABC
        prog.isActive = true
        let all = [prog, ExerciseLibrary.pplProgram, ExerciseLibrary.upperLowerProgram, ExerciseLibrary.swimProgram]
        all.forEach { saveProgram($0) }
        programs = all
    }

    private func loadPrograms(ctx: NSManagedObjectContext) {
        let fetch = NSFetchRequest<NSManagedObject>(entityName: "TrainingProgramEntity")
        let objs = (try? ctx.fetch(fetch)) ?? []
        programs = objs.compactMap { obj in
            guard let data = obj.value(forKey: "jsonData") as? Data else { return nil }
            return try? JSONDecoder().decode(TrainingProgram.self, from: data)
        }
    }

    private func saveProgramToDisk(_ program: TrainingProgram) {
        let ctx = container.viewContext
        guard let data = try? JSONEncoder().encode(program) else { return }
        let fetch = NSFetchRequest<NSManagedObject>(entityName: "TrainingProgramEntity")
        fetch.predicate = NSPredicate(format: "id == %@", program.id as CVarArg)
        let existing = (try? ctx.fetch(fetch))?.first ?? NSManagedObject(entity: container.managedObjectModel.entitiesByName["TrainingProgramEntity"]!, insertInto: ctx)
        existing.setValue(program.id, forKey: "id")
        existing.setValue(data, forKey: "jsonData")
        try? ctx.save()
    }

    private func deleteProgramFromDisk(_ id: UUID) {
        let ctx = container.viewContext
        let fetch = NSFetchRequest<NSManagedObject>(entityName: "TrainingProgramEntity")
        fetch.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let obj = (try? ctx.fetch(fetch))?.first { ctx.delete(obj) }
        try? ctx.save()
    }

    // MARK: - Widget data

    private func writeWidgetWorkoutData(_ session: WorkoutSession) {
        let defaults = UserDefaults(suiteName: "group.com.healthaggregator.app")
        defaults?.set(session.name, forKey: "widget_lastWorkoutName")
        defaults?.set(Int(session.duration / 60), forKey: "widget_lastWorkoutDuration")
        let wasToday = Calendar.current.isDateInToday(session.startDate)
        defaults?.set(wasToday, forKey: "widget_lastWorkoutToday")
        defaults?.set(streak.currentDays, forKey: "widget_streak")
        WidgetCenter.shared.reloadTimelines(ofKind: "WorkoutSummaryWidget")
    }
}
