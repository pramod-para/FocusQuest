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

    var displayName: String {
        switch self {
        case .workout: "Workout"
        case .meal: "Meal"
        case .water: "Water"
        case .movement: "Movement"
        case .focus: "Focus"
        case .family: "Family"
        case .evening: "Evening"
        }
    }
}

struct RoutineGoal: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var subtitle: String
    var hour: Int
    var minute: Int
    var durationMinutes: Int
    var activeWeekdays: Set<Int>
    var points: Int
    var kind: GoalKind

    init(
        id: String,
        title: String,
        subtitle: String,
        hour: Int,
        minute: Int,
        durationMinutes: Int = 10,
        activeWeekdays: Set<Int> = Set(1...7),
        points: Int,
        kind: GoalKind
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.hour = hour
        self.minute = minute
        self.durationMinutes = durationMinutes
        self.activeWeekdays = activeWeekdays
        self.points = points
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, subtitle, hour, minute, durationMinutes, activeWeekdays, points, kind
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        subtitle = try values.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        hour = try values.decode(Int.self, forKey: .hour)
        minute = try values.decode(Int.self, forKey: .minute)
        durationMinutes = try values.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 10
        activeWeekdays = try values.decodeIfPresent(Set<Int>.self, forKey: .activeWeekdays) ?? Set(1...7)
        points = try values.decodeIfPresent(Int.self, forKey: .points) ?? 10
        kind = try values.decodeIfPresent(GoalKind.self, forKey: .kind) ?? .focus
    }

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
    var goals: [RoutineGoal]? = nil
    var scheduleOverrides: [String: GoalScheduleTime] = [:]
    var modifiedAt: Date = .distantPast

    private enum CodingKeys: String, CodingKey { case goals, scheduleOverrides, modifiedAt }

    init(goals: [RoutineGoal]? = nil, scheduleOverrides: [String: GoalScheduleTime] = [:], modifiedAt: Date = .distantPast) {
        self.goals = goals
        self.scheduleOverrides = scheduleOverrides
        self.modifiedAt = modifiedAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        goals = try values.decodeIfPresent([RoutineGoal].self, forKey: .goals)
        scheduleOverrides = try values.decodeIfPresent([String: GoalScheduleTime].self, forKey: .scheduleOverrides) ?? [:]
        modifiedAt = try values.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? .distantPast
    }
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
        .init(id: "wake", title: "Start with water", subtitle: "Drink 12 oz and get ready", hour: 5, minute: 40, durationMinutes: 5, points: 10, kind: .water),
        .init(id: "workout", title: "Morning workout", subtitle: "Warm up, train, cool down", hour: 6, minute: 0, durationMinutes: 60, points: 30, kind: .workout),
        .init(id: "breakfast", title: "Recovery breakfast", subtitle: "Protein, fiber, moderate carbs", hour: 7, minute: 10, durationMinutes: 30, points: 15, kind: .meal),
        .init(id: "priority", title: "Most important task", subtitle: "Three distraction-free focus rounds", hour: 9, minute: 0, durationMinutes: 75, activeWeekdays: Set(2...6), points: 30, kind: .focus),
        .init(id: "walk1", title: "Movement reset", subtitle: "Walk or move", hour: 9, minute: 50, durationMinutes: 5, activeWeekdays: Set(2...6), points: 5, kind: .movement),
        .init(id: "walk2", title: "Movement reset", subtitle: "Walk or move", hour: 10, minute: 50, durationMinutes: 5, activeWeekdays: Set(2...6), points: 5, kind: .movement),
        .init(id: "lunch", title: "Balanced lunch", subtitle: "½ vegetables, ¼ protein, ¼ high-fiber carbs", hour: 12, minute: 0, durationMinutes: 30, points: 15, kind: .meal),
        .init(id: "lunchwalk", title: "Post-lunch walk", subtitle: "Easy walk", hour: 12, minute: 40, durationMinutes: 10, points: 10, kind: .movement),
        .init(id: "walk3", title: "Movement reset", subtitle: "Walk or move", hour: 13, minute: 50, durationMinutes: 5, activeWeekdays: Set(2...6), points: 5, kind: .movement),
        .init(id: "walk4", title: "Movement reset", subtitle: "Walk or move", hour: 14, minute: 50, durationMinutes: 5, activeWeekdays: Set(2...6), points: 5, kind: .movement),
        .init(id: "walk5", title: "Movement reset", subtitle: "Walk or move", hour: 15, minute: 50, durationMinutes: 5, activeWeekdays: Set(2...6), points: 5, kind: .movement),
        .init(id: "shutdown", title: "Finish work", subtitle: "Close loops and transition", hour: 16, minute: 50, durationMinutes: 10, activeWeekdays: Set(2...6), points: 10, kind: .focus),
        .init(id: "baby", title: "Protected baby time", subtitle: "Phone away—be fully present", hour: 17, minute: 0, durationMinutes: 60, points: 40, kind: .family),
        .init(id: "dinner", title: "Balanced dinner", subtitle: "Comfortable portion, no sugary drink", hour: 18, minute: 30, durationMinutes: 30, points: 15, kind: .meal),
        .init(id: "tomorrow", title: "Set up tomorrow", subtitle: "Choose one priority and wind down", hour: 21, minute: 0, durationMinutes: 10, points: 15, kind: .evening)
    ]
}
