import Foundation

enum GoalKind: String, Codable, CaseIterable {
    case workout, meal, water, movement, focus, family, evening

    var icon: String {
        switch self {
        case .workout: "figure.strengthtraining.traditional"
        case .meal: "fork.knife"
        case .water: "drop.fill"
        case .movement: "figure.walk"
        case .focus: "scope"
        case .family: "heart.fill"
        case .evening: "moon.stars.fill"
        }
    }

    var colorName: String {
        switch self {
        case .workout: "orange"
        case .meal: "green"
        case .water: "cyan"
        case .movement: "mint"
        case .focus: "indigo"
        case .family: "pink"
        case .evening: "purple"
        }
    }
}

struct RoutineGoal: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let hour: Int
    let minute: Int
    let points: Int
    let kind: GoalKind

    var time: Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
    }
}

struct GoalScheduleTime: Codable, Hashable {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    init(date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        hour = components.hour ?? 0
        minute = components.minute ?? 0
    }

    var date: Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
    }
}

struct RoutinePreferences: Codable {
    var scheduleOverrides: [String: GoalScheduleTime] = [:]
    var modifiedAt: Date = .distantPast
}

struct DayRecord: Identifiable, Codable {
    var id: String
    var completedGoalIDs: Set<String> = []
    var completionTimes: [String: Date] = [:]
    var waterOunces: Int = 0
    var focusSessions: Int = 0
    var importedSteps: Int = 0
    var modifiedAt: Date = .now

    init(
        id: String,
        completedGoalIDs: Set<String> = [],
        completionTimes: [String: Date] = [:],
        waterOunces: Int = 0,
        focusSessions: Int = 0,
        importedSteps: Int = 0,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.completedGoalIDs = completedGoalIDs
        self.completionTimes = completionTimes
        self.waterOunces = waterOunces
        self.focusSessions = focusSessions
        self.importedSteps = importedSteps
        self.modifiedAt = modifiedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, completedGoalIDs, completionTimes, waterOunces, focusSessions, importedSteps, modifiedAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        completedGoalIDs = try values.decodeIfPresent(Set<String>.self, forKey: .completedGoalIDs) ?? []
        completionTimes = try values.decodeIfPresent([String: Date].self, forKey: .completionTimes) ?? [:]
        waterOunces = try values.decodeIfPresent(Int.self, forKey: .waterOunces) ?? 0
        focusSessions = try values.decodeIfPresent(Int.self, forKey: .focusSessions) ?? 0
        importedSteps = try values.decodeIfPresent(Int.self, forKey: .importedSteps) ?? 0
        modifiedAt = try values.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? .distantPast
    }
}

enum RoutinePlan {
    static let waterTarget = 80
    static let goals: [RoutineGoal] = [
        .init(id: "wake", title: "Start with water", subtitle: "Drink 12 oz and get ready", hour: 5, minute: 40, points: 10, kind: .water),
        .init(id: "workout", title: "Morning workout", subtitle: "Warm up, train, cool down", hour: 6, minute: 0, points: 30, kind: .workout),
        .init(id: "breakfast", title: "Recovery breakfast", subtitle: "Protein, fiber, moderate carbs", hour: 7, minute: 10, points: 15, kind: .meal),
        .init(id: "priority", title: "Most important task", subtitle: "Three distraction-free focus rounds", hour: 9, minute: 0, points: 30, kind: .focus),
        .init(id: "walk1", title: "Movement reset", subtitle: "Walk or move for 5 minutes", hour: 9, minute: 50, points: 5, kind: .movement),
        .init(id: "walk2", title: "Movement reset", subtitle: "Walk or move for 5 minutes", hour: 10, minute: 50, points: 5, kind: .movement),
        .init(id: "lunch", title: "Balanced lunch", subtitle: "½ vegetables, ¼ protein, ¼ high-fiber carbs", hour: 12, minute: 0, points: 15, kind: .meal),
        .init(id: "lunchwalk", title: "Post-lunch walk", subtitle: "Easy walk for 10 minutes", hour: 12, minute: 40, points: 10, kind: .movement),
        .init(id: "walk3", title: "Movement reset", subtitle: "Walk or move for 5 minutes", hour: 13, minute: 50, points: 5, kind: .movement),
        .init(id: "walk4", title: "Movement reset", subtitle: "Walk or move for 5 minutes", hour: 14, minute: 50, points: 5, kind: .movement),
        .init(id: "walk5", title: "Movement reset", subtitle: "Walk or move for 5 minutes", hour: 15, minute: 50, points: 5, kind: .movement),
        .init(id: "shutdown", title: "Finish work", subtitle: "Close loops and transition", hour: 16, minute: 50, points: 10, kind: .focus),
        .init(id: "baby", title: "Protected baby time", subtitle: "Phone away—be fully present", hour: 17, minute: 0, points: 40, kind: .family),
        .init(id: "dinner", title: "Balanced dinner", subtitle: "Comfortable portion, no sugary drink", hour: 18, minute: 30, points: 15, kind: .meal),
        .init(id: "tomorrow", title: "Set up tomorrow", subtitle: "Choose one priority and wind down", hour: 21, minute: 0, points: 15, kind: .evening)
    ]
}
