import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            TodayView().tabItem { Label("Today", systemImage: "checkmark.circle.fill") }
            ProgressDashboardView().tabItem { Label("Progress", systemImage: "chart.bar.fill") }
            ScreenTimeDashboardView().tabItem { Label("Screen Time", systemImage: "hourglass") }
            CoachView().tabItem { Label("Coach", systemImage: "sparkles") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

struct TodayView: View {
    @EnvironmentObject private var store: RoutineStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HeroCard()
                    WaterCard()
                    NavigationLink {
                        CognitiveTrackerView()
                    } label: {
                        CognitiveSummaryCard()
                    }
                    .buttonStyle(.plain)
                    HStack {
                        Text("Today's plan").font(.title3.bold())
                        Spacer()
                        Text("\(store.completedCount) of \(store.activeTodayGoals.count)")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    LazyVStack(spacing: 10) {
                        ForEach(store.todayGoals) { goal in GoalRow(goal: goal) }
                        if store.todayGoals.isEmpty {
                            ContentUnavailableView("No activities today", systemImage: "calendar.badge.checkmark", description: Text("Add a goal or enable it for this weekday in Settings."))
                        }
                    }
                }
                .padding()
            }
            .focusQuestScreen()
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text(Date.now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct HeroCard: View {
    @EnvironmentObject private var store: RoutineStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(spacing: 18))
        layout {
            ZStack {
                Circle().stroke(.white.opacity(0.25), lineWidth: 9)
                Circle().trim(from: 0, to: store.completion).stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90))
                Text("\(Int(store.completion * 100))%") .font(.headline.monospacedDigit())
            }
            .frame(width: 88, height: 88)
            VStack(alignment: .leading, spacing: 7) {
                Text(store.completion == 1 ? "Day complete" : "Keep your momentum")
                    .font(.title2.bold())
                Text("Level \(store.level) · \(store.todayPoints) points")
                Label("\(store.streak)-day streak", systemImage: "flame.fill")
                    .font(.subheadline.bold())
            }
            Spacer()
        }
        .foregroundStyle(.white).padding(22)
        .background(
            LinearGradient(colors: [.indigo, .purple, Color(red: 0.36, green: 0.18, blue: 0.65)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .shadow(color: .indigo.opacity(0.22), radius: 18, y: 9)
    }
}

private struct WaterCard: View {
    @EnvironmentObject private var store: RoutineStore
    @State private var showingResetConfirmation = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Water", systemImage: "drop.fill").font(.headline).foregroundStyle(.blue)
                Spacer()
                Text("\(store.today.waterOunces) / 80 oz").font(.headline.monospacedDigit())
            }
            ProgressView(value: min(Double(store.today.waterOunces) / Double(RoutinePlan.waterTarget), 1))
                .tint(.blue)
            HStack {
                ForEach([8, 12, 16], id: \.self) { amount in
                    Button("+\(amount) oz") { store.addWater(amount) }
                        .buttonStyle(.bordered).frame(maxWidth: .infinity)
                }
            }
            if store.today.waterOunces > 0 {
                Button("Reset today's water", role: .destructive) { showingResetConfirmation = true }
                    .font(.footnote)
            }
        }.padding().focusQuestCard()
            .confirmationDialog("Reset today's water to 0 oz?", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
                Button("Reset water", role: .destructive) { store.resetWater() }
                Button("Cancel", role: .cancel) { }
            }
    }
}

private struct GoalRow: View {
    @EnvironmentObject private var store: RoutineStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let goal: RoutineGoal
    private var isSkipped: Bool { store.isSkipped(goal) }
    var body: some View {
        Button {
            withAnimation(.snappy) {
                if isSkipped { store.unskip(goal) } else { store.toggle(goal) }
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                FocusQuestIconTile(
                    symbol: isSkipped ? "minus.circle.fill" : (store.isComplete(goal) ? "checkmark.circle.fill" : goal.kind.icon),
                    color: isSkipped ? .secondary : (store.isComplete(goal) ? .green : .indigo)
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.title).font(.headline).strikethrough(store.isComplete(goal) || isSkipped)
                    Text(goal.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    Text("\(goal.durationMinutes) min").font(.caption2).foregroundStyle(.tertiary)
                }
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 3) {
                    if let completedAt = store.completedAt(goal) {
                        Text("Done \(completedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.caption.bold()).foregroundStyle(.green)
                    } else if isSkipped {
                        Text("Skipped")
                            .font(.caption.bold()).foregroundStyle(.secondary)
                    } else {
                        Text(store.scheduledTime(for: goal), style: .time)
                            .font(.subheadline.monospacedDigit())
                    }
                    Text("+\(goal.points)").font(.caption.bold()).foregroundStyle(.orange)
                }.fixedSize(horizontal: false, vertical: true)
            }.contentShape(Rectangle()).padding(16)
        }
        .buttonStyle(.plain)
        .focusQuestCard()
        .contextMenu {
            if isSkipped {
                Button("Put back today", systemImage: "arrow.uturn.backward") { store.unskip(goal) }
            } else if !store.isComplete(goal) {
                Button("Skip today", systemImage: "forward.fill", role: .destructive) { store.skipToday(goalID: goal.id) }
            }
        }
    }

}

struct ProgressDashboardView: View {
    @EnvironmentObject private var store: RoutineStore
    @EnvironmentObject private var health: HealthKitManager
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HStack(spacing: 10) {
                        StatCard(title: "Points", value: "\(store.totalPoints)", icon: "star.fill", color: .orange)
                        StatCard(title: "Level", value: "\(store.level)", icon: "trophy.fill", color: .indigo)
                        StatCard(title: "Streak", value: "\(store.streak)d", icon: "flame.fill", color: .pink)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Apple Health", systemImage: "heart.fill").font(.headline).foregroundStyle(.pink)
                            Spacer()
                            if health.isRefreshing { ProgressView() }
                        }
                        HStack {
                            HealthMetric(value: store.today.importedSteps.formatted(), label: "steps", icon: "figure.walk")
                            HealthMetric(value: "\(store.today.importedWorkoutMinutes)", label: "workout min", icon: "figure.run")
                            HealthMetric(value: sleepText, label: "sleep", icon: "bed.double.fill")
                        }
                        if let date = store.today.healthImportedAt {
                            Text("Updated \(date.formatted(date: .omitted, time: .shortened))")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("Connect Apple Health in Settings to import private daily summaries.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding().focusQuestCard()
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Last 7 days", systemImage: "chart.bar.fill").font(.headline)
                            Spacer()
                            Text("Activity completion").font(.caption).foregroundStyle(.secondary)
                        }
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach((0..<7).reversed(), id: \.self) { offset in DayBar(offset: offset) }
                        }.frame(height: 150)
                    }.padding().focusQuestCard()
                }.padding()
            }.focusQuestScreen().navigationTitle("Progress")
        }
    }

    private var sleepText: String {
        let minutes = store.today.importedSleepMinutes
        return minutes == 0 ? "—" : String(format: "%dh %02dm", minutes / 60, minutes % 60)
    }
}

private struct HealthMetric: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(.pink).font(.headline)
            Text(value).font(.headline.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.pink.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(color).font(.headline)
            Text(value).font(.title2.bold()).lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusQuestCard()
    }
}

private struct DayBar: View {
    @EnvironmentObject private var store: RoutineStore
    let offset: Int
    var date: Date { Calendar.current.date(byAdding: .day, value: -offset, to: .now)! }
    var count: Int {
        let record = store.records[RoutineStore.key(for: date)]
        let completed = record?.completedGoalIDs ?? []
        return store.goals(for: date).filter { completed.contains($0.id) }.count
    }
    var possibleCount: Int {
        let skipped = store.records[RoutineStore.key(for: date)]?.skippedGoalIDs ?? []
        return max(1, store.goals(for: date).filter { !skipped.contains($0.id) }.count)
    }
    var body: some View {
        VStack(spacing: 7) {
            Spacer()
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(offset == 0 ? AnyShapeStyle(Color.indigo.gradient) : AnyShapeStyle(Color.indigo.opacity(0.38)))
                .frame(height: max(7, CGFloat(count) / CGFloat(possibleCount) * 110))
            Text(date.formatted(.dateTime.weekday(.narrow))).font(.caption.weight(offset == 0 ? .bold : .regular))
        }.frame(maxWidth: .infinity)
    }
}

struct CoachView: View {
    @EnvironmentObject private var store: RoutineStore
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ZStack {
                        Circle().fill(.indigo.opacity(0.13)).frame(width: 72, height: 72)
                        Image(systemName: "sparkles").font(.system(size: 32, weight: .semibold)).foregroundStyle(.indigo)
                    }
                    Text("One useful change").font(.largeTitle.bold())
                    Text(store.insight).font(.title3).lineSpacing(6)
                    Divider()
                    Label("Based on your private completion history", systemImage: "lock.fill")
                        .font(.footnote.weight(.medium)).foregroundStyle(.secondary)
                }
                .padding(22)
                .focusQuestCard()
                .padding()
                Spacer()
            }
            .focusQuestScreen()
            .navigationTitle("Coach")
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: RoutineStore
    @EnvironmentObject private var health: HealthKitManager
    var body: some View {
        NavigationStack {
            Form {
                Section("Reminders") {
                    Button { Task { await store.requestNotifications() } } label: { Label(store.notificationsEnabled ? "Reminders enabled" : "Enable daily reminders", systemImage: "bell.badge.fill") }
                    Button { Task { await store.sendTestNotification() } } label: {
                        Label("Send test reminder in 10 seconds", systemImage: "bell.and.waves.left.and.right.fill")
                    }
                    if !store.notificationTestStatus.isEmpty {
                        Text(store.notificationTestStatus).font(.footnote).foregroundStyle(.secondary)
                    }
                    Text("Press and hold a reminder to Complete, Snooze 10 min, or Skip today.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Quiet hours") {
                    Toggle("Pause reminders", isOn: Binding(
                        get: { store.preferences.quietHoursEnabled },
                        set: { store.setQuietHoursEnabled($0) }
                    ))
                    if store.preferences.quietHoursEnabled {
                        DatePicker("From", selection: Binding(
                            get: { store.preferences.quietStart.date },
                            set: { store.updateQuietStart($0) }
                        ), displayedComponents: .hourAndMinute)
                        DatePicker("Until", selection: Binding(
                            get: { store.preferences.quietEnd.date },
                            set: { store.updateQuietEnd($0) }
                        ), displayedComponents: .hourAndMinute)
                    }
                    Text("Activity reminders that fall inside this window stay silent and are not scheduled.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Apple Watch") {
                    Label("Native companion included", systemImage: "applewatch")
                    Text("View today's routine, check in, skip an activity, and log 8 oz of water from your Watch. Changes sync back to this iPhone.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Label("Every FocusQuest reminder is also eligible to mirror to your paired Apple Watch.", systemImage: "bell.badge.fill")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("On your iPhone:").font(.headline)
                        Text("1. Open the Watch app")
                        Text("2. Tap My Watch → Notifications")
                        Text("3. Under “Mirror iPhone Alerts From,” enable FocusQuest")
                        Text("4. Keep the Watch unlocked and worn")
                    }.font(.subheadline)
                    Text("Apple normally alerts either the Watch or iPhone—not both. When the iPhone is locked or asleep, the alert goes to the unlocked Watch.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Apple Health") {
                    Button {
                        Task { await health.connectAndRefresh(store: store) }
                    } label: {
                        Label(store.today.healthImportedAt == nil ? "Connect Apple Health" : "Refresh Apple Health", systemImage: "heart.fill")
                    }
                    .disabled(health.isRefreshing || !health.isAvailable)
                    if health.isRefreshing { ProgressView("Reading daily summaries…") }
                    else { Text(health.status).font(.footnote).foregroundStyle(.secondary) }
                    Text("Read only: today's steps and workouts, plus last night's sleep. FocusQuest never writes health data and stores only daily totals in your private app history.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Plan") {
                    LabeledContent("Water target", value: "80 oz")
                    LabeledContent("Activities", value: "\(store.goals.count)")
                    NavigationLink("Manage activities") { ScheduleEditorView() }
                }
                Section("iCloud") {
                    Label(store.iCloudStatus, systemImage: "icloud.fill")
                    Button("Sync now") { Task { await store.syncWithICloud() } }
                    Text("History is stored in the signed-in user's private CloudKit database and cached on this device for offline use. The app developer and other users cannot access it through the app.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .focusQuestScreen()
            .navigationTitle("Settings")
        }
    }
}

struct ScheduleEditorView: View {
    @EnvironmentObject private var store: RoutineStore
    @State private var showingNewGoal = false

    var body: some View {
        List {
            Section {
                Text("Add, edit, delete, or reorder activities. Notification schedules update automatically.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Activities") {
                ForEach(store.goals) { goal in
                    NavigationLink {
                        GoalEditorView(goal: goal, isNew: false)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: goal.kind.icon).foregroundStyle(.indigo).frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(goal.title)
                                Text("\(store.scheduledTime(for: goal).formatted(date: .omitted, time: .shortened)) · \(goal.durationMinutes) min · \(weekdaySummary(goal.activeWeekdays))")
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                Label(reminderSummary(goal), systemImage: goal.reminderEnabled ? "bell.fill" : "bell.slash.fill")
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .onDelete(perform: store.deleteGoals)
                .onMove(perform: store.moveGoals)
            }
        }
        .navigationTitle("Activities")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()
                Button { showingNewGoal = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingNewGoal) {
            NavigationStack {
                GoalEditorView(
                    goal: RoutineGoal(
                        id: UUID().uuidString,
                        title: "",
                        subtitle: "",
                        hour: Calendar.current.component(.hour, from: .now),
                        minute: Calendar.current.component(.minute, from: .now),
                        durationMinutes: 10,
                        points: 10,
                        kind: .focus
                    ),
                    isNew: true
                )
            }
        }
    }

    private func weekdaySummary(_ weekdays: Set<Int>) -> String {
        if weekdays.count == 7 { return "Every day" }
        let ordered = [(2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")]
        return ordered.filter { weekdays.contains($0.0) }.map(\.1).joined(separator: ", ")
    }

    private func reminderSummary(_ goal: RoutineGoal) -> String {
        guard goal.reminderEnabled else { return "Reminder off" }
        return goal.reminderLeadMinutes == 0 ? "At start time" : "\(goal.reminderLeadMinutes) min before"
    }
}

struct GoalEditorView: View {
    @EnvironmentObject private var store: RoutineStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: RoutineGoal
    let isNew: Bool

    private let weekdays = [(2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S"), (1, "S")]

    init(goal: RoutineGoal, isNew: Bool) {
        _draft = State(initialValue: goal)
        self.isNew = isNew
    }

    var body: some View {
        Form {
            Section("Activity") {
                TextField("Name", text: $draft.title)
                TextField("Helpful note (optional)", text: $draft.subtitle, axis: .vertical)
                Picker("Category", selection: $draft.kind) {
                    ForEach(GoalKind.allCases, id: \.self) { kind in
                        Label(kind.displayName, systemImage: kind.icon).tag(kind)
                    }
                }
            }
            Section("Schedule") {
                DatePicker("Start time", selection: Binding(
                    get: { GoalScheduleTime(hour: draft.hour, minute: draft.minute).date },
                    set: {
                        let value = GoalScheduleTime(date: $0)
                        draft.hour = value.hour
                        draft.minute = value.minute
                    }
                ), displayedComponents: .hourAndMinute)
                Stepper("Duration: \(draft.durationMinutes) minutes", value: $draft.durationMinutes, in: 5...240, step: 5)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Repeat").font(.subheadline)
                    HStack {
                        ForEach(weekdays, id: \.0) { weekday, label in
                            Button {
                                if draft.activeWeekdays.contains(weekday) { draft.activeWeekdays.remove(weekday) }
                                else { draft.activeWeekdays.insert(weekday) }
                            } label: {
                                Text(label).font(.caption.bold()).frame(width: 28, height: 28)
                                    .background(draft.activeWeekdays.contains(weekday) ? Color.indigo : Color(.tertiarySystemFill), in: Circle())
                                    .foregroundStyle(draft.activeWeekdays.contains(weekday) ? .white : .primary)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            Section("Reminder") {
                Toggle("Remind me", isOn: $draft.reminderEnabled)
                if draft.reminderEnabled {
                    Picker("Alert", selection: $draft.reminderLeadMinutes) {
                        Text("At start time").tag(0)
                        Text("5 minutes before").tag(5)
                        Text("10 minutes before").tag(10)
                        Text("15 minutes before").tag(15)
                        Text("30 minutes before").tag(30)
                    }
                }
            }
            Section("Game") {
                Stepper("Reward: \(draft.points) points", value: $draft.points, in: 5...100, step: 5)
            }
        }
        .navigationTitle(isNew ? "New activity" : "Edit activity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if isNew { store.addGoal(draft) } else { store.updateGoal(draft) }
                    dismiss()
                }
                .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.activeWeekdays.isEmpty)
            }
        }
    }
}
