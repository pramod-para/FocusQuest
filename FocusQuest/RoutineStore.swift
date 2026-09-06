import Foundation
import UserNotifications
import CloudKit

@MainActor
final class RoutineStore: ObservableObject {
    @Published private(set) var records: [String: DayRecord] = [:]
    @Published var notificationsEnabled = false
    @Published private(set) var notificationTestStatus = ""
    @Published private(set) var iCloudStatus = "Checking iCloud…"
    private let defaultsKey = "focusquest.records.v1"
    #if FOCUSQUEST_LOCAL_ONLY
    private let database: CKDatabase? = nil
    #else
    private let database: CKDatabase? = CKContainer.default().privateCloudDatabase
    #endif

    init() {
        load()
        Task { await syncWithICloud() }
    }

    var todayKey: String { Self.key(for: .now) }
    var today: DayRecord { records[todayKey] ?? DayRecord(id: todayKey) }
    var completedCount: Int { today.completedGoalIDs.count }
    var totalPoints: Int {
        records.values.reduce(0) { total, record in
            total + RoutinePlan.goals.filter { record.completedGoalIDs.contains($0.id) }.reduce(0) { $0 + $1.points }
                + min(record.waterOunces, RoutinePlan.waterTarget) / 8 * 2
        }
    }
    var level: Int { max(1, totalPoints / 500 + 1) }
    var todayPoints: Int {
        RoutinePlan.goals.filter { today.completedGoalIDs.contains($0.id) }.reduce(0) { $0 + $1.points }
            + min(today.waterOunces, RoutinePlan.waterTarget) / 8 * 2
    }
    var completion: Double { Double(completedCount) / Double(RoutinePlan.goals.count) }
    var streak: Int {
        var count = 0
        for offset in 0..<365 {
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: .now) else { break }
            let record = records[Self.key(for: day)]
            if let record, record.completedGoalIDs.count >= 8 { count += 1 } else if offset > 0 { break }
        }
        return count
    }

    func isComplete(_ goal: RoutineGoal) -> Bool { today.completedGoalIDs.contains(goal.id) }

    func toggle(_ goal: RoutineGoal) {
        mutateToday { record in
            if record.completedGoalIDs.contains(goal.id) { record.completedGoalIDs.remove(goal.id) }
            else { record.completedGoalIDs.insert(goal.id) }
        }
    }

    func addWater(_ ounces: Int) { mutateToday { $0.waterOunces = max(0, $0.waterOunces + ounces) } }
    func addFocusSession() { mutateToday { $0.focusSessions += 1 } }

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
        let missed = RoutinePlan.goals.map { goal in
            (goal, recent.filter { !$0.completedGoalIDs.contains(goal.id) }.count)
        }.max { $0.1 < $1.1 }
        if let missed, missed.1 > 0 {
            return "Your best improvement opportunity is “\(missed.0.title).” Make it easier: prepare the environment five minutes before \(missed.0.time.formatted(date: .omitted, time: .shortened))."
        }
        return "Your routine is consistent. Protect sleep and increase difficulty gradually—not all at once."
    }

    func requestNotifications() async {
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
            content.body = "Success—your routine reminders are ready."
            content.sound = .default
            content.interruptionLevel = .active
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
            try await center.add(UNNotificationRequest(identifier: "focusquest.test", content: content, trigger: trigger))
            notificationTestStatus = "Scheduled—lock the iPhone now and watch for the alert."
        } catch {
            notificationTestStatus = "Could not schedule the test reminder."
        }
    }

    private func scheduleNotifications() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: RoutinePlan.goals.map(\.id))
        for goal in RoutinePlan.goals {
            let content = UNMutableNotificationContent()
            content.title = goal.title
            content.body = goal.subtitle
            content.sound = .default
            content.interruptionLevel = .active
            content.threadIdentifier = "daily-routine"
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: goal.hour, minute: goal.minute), repeats: true)
            try? await center.add(UNNotificationRequest(identifier: goal.id, content: content, trigger: trigger))
        }
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
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let value = try? JSONDecoder().decode([String: DayRecord].self, from: data) else { return }
        records = value
    }

    private func saveLocal() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
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

    private static func dayRecord(from record: CKRecord) -> DayRecord? {
        guard let modifiedAt = record["modifiedAt"] as? Date else { return nil }
        let goalIDs = Set(record["completedGoalIDs"] as? [String] ?? [])
        return DayRecord(
            id: record.recordID.recordName,
            completedGoalIDs: goalIDs,
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
