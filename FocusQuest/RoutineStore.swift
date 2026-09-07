import Foundation
import UserNotifications
import CloudKit

@MainActor
final class RoutineStore: ObservableObject {
    static let shared = RoutineStore()

    @Published private(set) var records: [String: DayRecord] = [:]
    @Published private(set) var preferences = RoutinePreferences()
    @Published var notificationsEnabled = false
    @Published private(set) var notificationTestStatus = ""
    @Published private(set) var iCloudStatus = "Checking iCloud…"
    private let defaultsKey = "focusquest.records.v1"
    private let preferencesKey = "focusquest.preferences.v1"
    #if FOCUSQUEST_LOCAL_ONLY
    private let database: CKDatabase? = nil
    #else
    private let database: CKDatabase? = CKContainer.default().privateCloudDatabase
    #endif

    init() {
        load()
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationsEnabled = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            await syncWithICloud()
            if notificationsEnabled { await scheduleNotifications() }
        }
    }

    var goals: [RoutineGoal] {
        let source = preferences.goals ?? RoutinePlan.goals
        return source.map { goal in
            guard let override = preferences.scheduleOverrides[goal.id] else { return goal }
            var updated = goal
            updated.hour = override.hour
            updated.minute = override.minute
            return updated
        }
    }
    var todayGoals: [RoutineGoal] { goals(for: .now) }
    var activeTodayGoals: [RoutineGoal] { todayGoals.filter { !today.skippedGoalIDs.contains($0.id) } }
    var todayKey: String { Self.key(for: .now) }
    var today: DayRecord { records[todayKey] ?? DayRecord(id: todayKey) }
    var completedCount: Int { activeTodayGoals.filter { today.completedGoalIDs.contains($0.id) }.count }
    var totalPoints: Int {
        records.values.reduce(0) { total, record in
            total + goals.filter { record.completedGoalIDs.contains($0.id) }.reduce(0) { $0 + $1.points }
                + min(record.waterOunces, RoutinePlan.waterTarget) / 8 * 2
        }
    }
    var level: Int { max(1, totalPoints / 500 + 1) }
    var todayPoints: Int {
        todayGoals.filter { today.completedGoalIDs.contains($0.id) }.reduce(0) { $0 + $1.points }
            + min(today.waterOunces, RoutinePlan.waterTarget) / 8 * 2
    }
    var completion: Double { activeTodayGoals.isEmpty ? 0 : Double(completedCount) / Double(activeTodayGoals.count) }
    var streak: Int {
        var count = 0
        for offset in 0..<365 {
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: .now) else { break }
            let record = records[Self.key(for: day)]
            let skipped = record?.skippedGoalIDs ?? []
            let dayGoals = goals(for: day).filter { !skipped.contains($0.id) }
            guard !dayGoals.isEmpty else {
                if offset > 0 { break }
                continue
            }
            let required = max(1, Int(ceil(Double(dayGoals.count) * 0.6)))
            let achieved = dayGoals.filter { record?.completedGoalIDs.contains($0.id) == true }.count
            if achieved >= required { count += 1 } else if offset > 0 { break }
        }
        return count
    }

    func isComplete(_ goal: RoutineGoal) -> Bool { today.completedGoalIDs.contains(goal.id) }
    func isSkipped(_ goal: RoutineGoal) -> Bool { today.skippedGoalIDs.contains(goal.id) }
    func completedAt(_ goal: RoutineGoal) -> Date? { today.completionTimes[goal.id] }
    func scheduledTime(for goal: RoutineGoal) -> Date {
        (preferences.scheduleOverrides[goal.id] ?? GoalScheduleTime(hour: goal.hour, minute: goal.minute)).date
    }

    func goals(for date: Date) -> [RoutineGoal] {
        let weekday = Calendar.current.component(.weekday, from: date)
        return goals.filter { $0.activeWeekdays.contains(weekday) }
    }

    func toggle(_ goal: RoutineGoal) {
        mutateToday { record in
            if record.completedGoalIDs.contains(goal.id) {
                record.completedGoalIDs.remove(goal.id)
                record.completionTimes.removeValue(forKey: goal.id)
            } else {
                record.skippedGoalIDs.remove(goal.id)
                record.completedGoalIDs.insert(goal.id)
                record.completionTimes[goal.id] = .now
            }
        }
    }

    func completeGoal(id: String) {
        mutateToday { record in
            record.skippedGoalIDs.remove(id)
            record.completedGoalIDs.insert(id)
            record.completionTimes[id] = .now
        }
    }

    func skipToday(goalID: String) {
        mutateToday { record in
            record.completedGoalIDs.remove(goalID)
            record.completionTimes.removeValue(forKey: goalID)
            record.skippedGoalIDs.insert(goalID)
        }
    }

    func unskip(_ goal: RoutineGoal) {
        mutateToday { $0.skippedGoalIDs.remove(goal.id) }
    }

    func snooze(goalID: String, minutes: Int = 10) async {
        guard let goal = goals.first(where: { $0.id == goalID }) else { return }
        let content = reminderContent(for: goal)
        let detail = goal.subtitle.isEmpty ? "Time for your activity." : goal.subtitle
        content.body = "Snoozed reminder: \(detail)"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
        let request = UNNotificationRequest(identifier: "\(goal.id).snooze.\(UUID().uuidString)", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    func addWater(_ ounces: Int) { mutateToday { $0.waterOunces = max(0, $0.waterOunces + ounces) } }
    func resetWater() { mutateToday { $0.waterOunces = 0 } }
    func addFocusSession() { mutateToday { $0.focusSessions += 1 } }

    func updateTime(_ date: Date, for goal: RoutineGoal) {
        var updated = goal
        let time = GoalScheduleTime(date: date)
        updated.hour = time.hour
        updated.minute = time.minute
        updateGoal(updated)
    }

    func addGoal(_ goal: RoutineGoal) {
        var updatedGoals = materializedGoals()
        updatedGoals.append(goal)
        persistGoals(updatedGoals)
    }

    func updateGoal(_ goal: RoutineGoal) {
        var updatedGoals = materializedGoals()
        guard let index = updatedGoals.firstIndex(where: { $0.id == goal.id }) else { return }
        var safeGoal = goal
        if safeGoal.activeWeekdays.isEmpty { safeGoal.activeWeekdays = Set(1...7) }
        safeGoal.durationMinutes = max(1, safeGoal.durationMinutes)
        safeGoal.title = safeGoal.title.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedGoals[index] = safeGoal
        persistGoals(updatedGoals)
    }

    func deleteGoals(at offsets: IndexSet) {
        var updatedGoals = materializedGoals()
        updatedGoals.remove(atOffsets: offsets)
        persistGoals(updatedGoals)
    }

    func moveGoals(from source: IndexSet, to destination: Int) {
        var updatedGoals = materializedGoals()
        updatedGoals.move(fromOffsets: source, toOffset: destination)
        persistGoals(updatedGoals)
    }

    private func materializedGoals() -> [RoutineGoal] { goals }

    private func persistGoals(_ updatedGoals: [RoutineGoal]) {
        preferences.goals = updatedGoals
        preferences.scheduleOverrides = [:]
        preferences.modifiedAt = .now
        savePreferencesLocal()
        Task {
            await uploadPreferences()
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                await scheduleNotifications()
            }
        }
    }

    func setQuietHoursEnabled(_ enabled: Bool) {
        preferences.quietHoursEnabled = enabled
        persistPreferences()
    }

    func updateQuietStart(_ date: Date) {
        preferences.quietStart = GoalScheduleTime(date: date)
        persistPreferences()
    }

    func updateQuietEnd(_ date: Date) {
        preferences.quietEnd = GoalScheduleTime(date: date)
        persistPreferences()
    }

    private func persistPreferences() {
        preferences.modifiedAt = .now
        savePreferencesLocal()
        Task {
            await uploadPreferences()
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                await scheduleNotifications()
            }
        }
    }

    func syncWithICloud() async {
        guard let database else {
            iCloudStatus = "On-device test mode"
            return
        }
        do {
            let status = try await CKContainer.default().accountStatus()
            guard status == .available else {
                iCloudStatus = "Sign in to iCloud to sync"
                return
            }
            iCloudStatus = "Syncing…"
            let query = CKQuery(recordType: "RoutineDay", predicate: NSPredicate(value: true))
            let result = try await database.records(matching: query, resultsLimit: 365)
            for (_, cloudResult) in result.matchResults {
                guard case let .success(cloudRecord) = cloudResult,
                      let decoded = Self.dayRecord(from: cloudRecord) else { continue }
                if decoded.modifiedAt > (records[decoded.id]?.modifiedAt ?? .distantPast) {
                    records[decoded.id] = decoded
                }
            }
            await downloadPreferences(from: database)
            saveLocal()
            iCloudStatus = "Synced with private iCloud"
        } catch {
            iCloudStatus = "Offline—changes saved on this device"
        }
    }

    var insight: String {
        let recent = (0..<7).compactMap { offset -> DayRecord? in
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: .now) else { return nil }
            return records[Self.key(for: date)]
        }
        guard !recent.isEmpty else { return "Complete a few days and your weekly coaching will appear here." }
        let missed = goals.map { goal in
            (goal, recent.filter { !$0.completedGoalIDs.contains(goal.id) }.count)
        }.max { $0.1 < $1.1 }
        if let missed, missed.1 > 0 {
            return "Your best improvement opportunity is “\(missed.0.title).” Make it easier: prepare the environment five minutes before \(scheduledTime(for: missed.0).formatted(date: .omitted, time: .shortened))."
        }
        return "Your routine is consistent. Protect sleep and increase difficulty gradually—not all at once."
    }

    func requestNotifications() async {
        ReminderNotificationSupport.registerCategories()
        do {
            notificationsEnabled = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            if notificationsEnabled { await scheduleNotifications() }
        } catch { notificationsEnabled = false }
    }

    func sendTestNotification() async {
        let center = UNUserNotificationCenter.current()
        do {
            let settings = await center.notificationSettings()
            if settings.authorizationStatus != .authorized && settings.authorizationStatus != .provisional {
                notificationsEnabled = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } else {
                notificationsEnabled = true
            }
            guard notificationsEnabled else {
                notificationTestStatus = "Notifications are disabled in iPhone Settings."
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "FocusQuest reminder test"
            content.body = "Success—press and hold to test Complete, Snooze, or Skip."
            content.sound = .default
            content.interruptionLevel = .active
            if let goal = todayGoals.first {
                content.categoryIdentifier = ReminderNotificationSupport.categoryIdentifier
                content.userInfo = [ReminderNotificationSupport.goalIDKey: goal.id]
            }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
            try await center.add(UNNotificationRequest(identifier: "focusquest.test", content: content, trigger: trigger))
            notificationTestStatus = "Scheduled—lock the iPhone, then press and hold the alert to test its actions."
        } catch {
            notificationTestStatus = "Could not schedule the test reminder."
        }
    }

    private func scheduleNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let recurringIdentifiers = pending
            .map(\.identifier)
            .filter { $0 != "focusquest.test" && !$0.contains(".snooze.") }
        center.removePendingNotificationRequests(withIdentifiers: recurringIdentifiers)
        ReminderNotificationSupport.registerCategories()
        for goal in goals where goal.reminderEnabled {
            if goal.activeWeekdays.count == 7 {
                let components = reminderComponents(for: goal, weekday: nil)
                guard !isQuietTime(components) else { continue }
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                try? await center.add(UNNotificationRequest(identifier: "\(goal.id).daily", content: reminderContent(for: goal), trigger: trigger))
            } else {
                for weekday in goal.activeWeekdays.sorted() {
                    let components = reminderComponents(for: goal, weekday: weekday)
                    guard !isQuietTime(components) else { continue }
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    let identifier = "\(goal.id).\(weekday)"
                    try? await center.add(UNNotificationRequest(identifier: identifier, content: reminderContent(for: goal), trigger: trigger))
                }
            }
        }
    }

    private func reminderContent(for goal: RoutineGoal) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = goal.title
        if goal.reminderLeadMinutes > 0 {
            let detail = goal.subtitle.isEmpty ? "Get ready for your \(goal.durationMinutes)-minute activity." : goal.subtitle
            content.body = "Starts in \(goal.reminderLeadMinutes) minutes. \(detail)"
        } else {
            content.body = goal.subtitle.isEmpty ? "Time for your \(goal.durationMinutes)-minute activity." : goal.subtitle
        }
        content.sound = .default
        content.interruptionLevel = .active
        content.threadIdentifier = "daily-routine"
        content.categoryIdentifier = ReminderNotificationSupport.categoryIdentifier
        content.userInfo = [ReminderNotificationSupport.goalIDKey: goal.id]
        return content
    }

    private func reminderComponents(for goal: RoutineGoal, weekday: Int?) -> DateComponents {
        let calendar = Calendar.current
        var anchorComponents = DateComponents()
        anchorComponents.calendar = calendar
        anchorComponents.timeZone = calendar.timeZone
        anchorComponents.year = 2024
        anchorComponents.month = 1
        anchorComponents.day = 7 + ((weekday ?? 1) - 1)
        anchorComponents.hour = goal.hour
        anchorComponents.minute = goal.minute
        let anchor = calendar.date(from: anchorComponents) ?? .now
        let reminderDate = calendar.date(byAdding: .minute, value: -max(0, goal.reminderLeadMinutes), to: anchor) ?? anchor
        if weekday == nil {
            return calendar.dateComponents([.hour, .minute], from: reminderDate)
        }
        return calendar.dateComponents([.weekday, .hour, .minute], from: reminderDate)
    }

    private func isQuietTime(_ components: DateComponents) -> Bool {
        guard preferences.quietHoursEnabled else { return false }
        let minuteOfDay = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let start = preferences.quietStart.hour * 60 + preferences.quietStart.minute
        let end = preferences.quietEnd.hour * 60 + preferences.quietEnd.minute
        if start == end { return true }
        if start < end { return minuteOfDay >= start && minuteOfDay < end }
        return minuteOfDay >= start || minuteOfDay < end
    }

    private func mutateToday(_ update: (inout DayRecord) -> Void) {
        var record = today
        update(&record)
        record.modifiedAt = .now
        records[todayKey] = record
        saveLocal()
        Task { await upload(record) }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let value = try? JSONDecoder().decode([String: DayRecord].self, from: data) {
            records = value
        }
        if let data = UserDefaults.standard.data(forKey: preferencesKey),
           let value = try? JSONDecoder().decode(RoutinePreferences.self, from: data) {
            preferences = value
        }
    }

    private func saveLocal() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func savePreferencesLocal() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        UserDefaults.standard.set(data, forKey: preferencesKey)
    }

    private func upload(_ value: DayRecord) async {
        guard let database else {
            iCloudStatus = "Saved on this device"
            return
        }
        let id = CKRecord.ID(recordName: value.id)
        do {
            let record = (try? await database.record(for: id)) ?? CKRecord(recordType: "RoutineDay", recordID: id)
            record["completedGoalIDs"] = Array(value.completedGoalIDs) as CKRecordValue
            record["completionTimes"] = try? JSONEncoder().encode(value.completionTimes) as CKRecordValue
            record["skippedGoalIDs"] = Array(value.skippedGoalIDs) as CKRecordValue
            record["waterOunces"] = value.waterOunces as CKRecordValue
            record["focusSessions"] = value.focusSessions as CKRecordValue
            record["importedSteps"] = value.importedSteps as CKRecordValue
            record["modifiedAt"] = value.modifiedAt as CKRecordValue
            _ = try await database.save(record)
            iCloudStatus = "Synced with private iCloud"
        } catch {
            iCloudStatus = "Offline—will sync later"
        }
    }

    private func uploadPreferences() async {
        guard let database else {
            iCloudStatus = "Saved on this device"
            return
        }
        let id = CKRecord.ID(recordName: "routine-preferences")
        do {
            let record = (try? await database.record(for: id)) ?? CKRecord(recordType: "RoutinePreferences", recordID: id)
            record["preferencesData"] = try JSONEncoder().encode(preferences) as CKRecordValue
            record["modifiedAt"] = preferences.modifiedAt as CKRecordValue
            _ = try await database.save(record)
            iCloudStatus = "Synced with private iCloud"
        } catch {
            iCloudStatus = "Offline—will sync later"
        }
    }

    private func downloadPreferences(from database: CKDatabase) async {
        let id = CKRecord.ID(recordName: "routine-preferences")
        guard let record = try? await database.record(for: id),
              let modifiedAt = record["modifiedAt"] as? Date else {
            if preferences.goals != nil || !preferences.scheduleOverrides.isEmpty { await uploadPreferences() }
            return
        }
        if modifiedAt > preferences.modifiedAt {
            if let data = record["preferencesData"] as? Data,
               var decoded = try? JSONDecoder().decode(RoutinePreferences.self, from: data) {
                decoded.modifiedAt = modifiedAt
                preferences = decoded
            } else if let data = record["scheduleOverrides"] as? Data,
                      let overrides = try? JSONDecoder().decode([String: GoalScheduleTime].self, from: data) {
                preferences = RoutinePreferences(scheduleOverrides: overrides, modifiedAt: modifiedAt)
            }
            savePreferencesLocal()
        }
    }

    private static func dayRecord(from record: CKRecord) -> DayRecord? {
        guard let modifiedAt = record["modifiedAt"] as? Date else { return nil }
        let goalIDs = Set(record["completedGoalIDs"] as? [String] ?? [])
        let skippedGoalIDs = Set(record["skippedGoalIDs"] as? [String] ?? [])
        let completionTimes: [String: Date]
        if let data = record["completionTimes"] as? Data,
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            completionTimes = decoded
        } else {
            completionTimes = [:]
        }
        return DayRecord(
            id: record.recordID.recordName,
            completedGoalIDs: goalIDs,
            completionTimes: completionTimes,
            skippedGoalIDs: skippedGoalIDs,
            waterOunces: (record["waterOunces"] as? Int64).map(Int.init) ?? 0,
            focusSessions: (record["focusSessions"] as? Int64).map(Int.init) ?? 0,
            importedSteps: (record["importedSteps"] as? Int64).map(Int.init) ?? 0,
            modifiedAt: modifiedAt
        )
    }

    static func key(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
