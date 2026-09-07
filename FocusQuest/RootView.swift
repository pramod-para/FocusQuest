import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            TodayView().tabItem { Label("Today", systemImage: "checkmark.circle.fill") }
            ProgressDashboardView().tabItem { Label("Progress", systemImage: "chart.bar.fill") }
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
                    LazyVStack(spacing: 10) {
                        ForEach(store.todayGoals) { goal in GoalRow(goal: goal) }
                        if store.todayGoals.isEmpty {
                            ContentUnavailableView("No activities today", systemImage: "calendar.badge.checkmark", description: Text("Add a goal or enable it for this weekday in Settings."))
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Your day")
        }
    }
}

private struct HeroCard: View {
    @EnvironmentObject private var store: RoutineStore
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(.white.opacity(0.25), lineWidth: 9)
                Circle().trim(from: 0, to: store.completion).stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90))
                Text("\(Int(store.completion * 100))%") .font(.headline.monospacedDigit())
            }.frame(width: 82, height: 82)
            VStack(alignment: .leading, spacing: 5) {
                Text("Level \(store.level)").font(.title2.bold())
                Text("\(store.todayPoints) points today")
                Label("\(store.streak)-day streak", systemImage: "flame.fill").font(.subheadline.bold())
            }
            Spacer()
        }
        .foregroundStyle(.white).padding(20)
        .background(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
    }
}

private struct WaterCard: View {
    @EnvironmentObject private var store: RoutineStore
    @State private var showingResetConfirmation = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Water", systemImage: "drop.fill").font(.headline).foregroundStyle(.cyan)
                Spacer()
                Text("\(store.today.waterOunces) / 80 oz").font(.headline.monospacedDigit())
            }
            ProgressView(value: min(Double(store.today.waterOunces) / 80, 1)).tint(.cyan)
            HStack {
                ForEach([8, 12, 16], id: \.self) { amount in
                    Button("+\(amount) oz") { store.addWater(amount) }.buttonStyle(.bordered).frame(maxWidth: .infinity)
                }
            }
            if store.today.waterOunces > 0 {
                Button("Reset today's water", role: .destructive) { showingResetConfirmation = true }
                    .font(.footnote)
            }
        }.padding().background(.background, in: RoundedRectangle(cornerRadius: 20))
            .confirmationDialog("Reset today's water to 0 oz?", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
                Button("Reset water", role: .destructive) { store.resetWater() }
                Button("Cancel", role: .cancel) { }
            }
    }
}

private struct GoalRow: View {
    @EnvironmentObject private var store: RoutineStore
    let goal: RoutineGoal
    var body: some View {
        Button { withAnimation(.snappy) { store.toggle(goal) } } label: {
            HStack(spacing: 14) {
                Image(systemName: store.isComplete(goal) ? "checkmark.circle.fill" : goal.kind.icon)
                    .font(.title2).frame(width: 34).foregroundStyle(store.isComplete(goal) ? .green : .indigo)
                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.title).font(.headline).strikethrough(store.isComplete(goal))
                    Text(goal.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    Text("\(goal.durationMinutes) min").font(.caption2).foregroundStyle(.tertiary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    if let completedAt = store.completedAt(goal) {
                        Text("Done \(completedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.caption.bold()).foregroundStyle(.green)
                    } else {
                        Text(store.scheduledTime(for: goal), style: .time)
                            .font(.subheadline.monospacedDigit())
                    }
                    Text("+\(goal.points)").font(.caption.bold()).foregroundStyle(.orange)
                }
            }.contentShape(Rectangle()).padding()
        }.buttonStyle(.plain).background(.background, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct ProgressDashboardView: View {
    @EnvironmentObject private var store: RoutineStore
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    StatCard(title: "Total points", value: "\(store.totalPoints)", icon: "star.fill")
                    StatCard(title: "Current level", value: "\(store.level)", icon: "trophy.fill")
                    StatCard(title: "Current streak", value: "\(store.streak) days", icon: "flame.fill")
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Last 7 days").font(.headline)
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach((0..<7).reversed(), id: \.self) { offset in DayBar(offset: offset) }
                        }.frame(height: 150)
                    }.padding().background(.background, in: RoundedRectangle(cornerRadius: 20))
                }.padding()
            }.background(Color(.systemGroupedBackground)).navigationTitle("Progress")
        }
    }
}

private struct StatCard: View {
    let title: String; let value: String; let icon: String
    var body: some View { HStack { Image(systemName: icon).font(.title).foregroundStyle(.indigo); Text(title); Spacer(); Text(value).font(.title3.bold()) }.padding().background(.background, in: RoundedRectangle(cornerRadius: 18)) }
}

private struct DayBar: View {
    @EnvironmentObject private var store: RoutineStore
    let offset: Int
    var date: Date { Calendar.current.date(byAdding: .day, value: -offset, to: .now)! }
    var count: Int {
        let completed = store.records[RoutineStore.key(for: date)]?.completedGoalIDs ?? []
        return store.goals(for: date).filter { completed.contains($0.id) }.count
    }
    var possibleCount: Int { max(1, store.goals(for: date).count) }
    var body: some View {
        VStack { Spacer(); RoundedRectangle(cornerRadius: 6).fill(.indigo.gradient).frame(height: max(6, CGFloat(count) / CGFloat(possibleCount) * 110)); Text(date.formatted(.dateTime.weekday(.narrow))).font(.caption) }.frame(maxWidth: .infinity)
    }
}

struct CoachView: View {
    @EnvironmentObject private var store: RoutineStore
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "sparkles").font(.system(size: 42)).foregroundStyle(.indigo)
                Text("Weekly coaching").font(.largeTitle.bold())
                Text(store.insight).font(.title3).lineSpacing(5)
                Text("Recommendations use only completion history stored on this device. They are habit coaching, not medical advice.").font(.footnote).foregroundStyle(.secondary)
                Spacer()
            }.padding().navigationTitle("Coach")
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: RoutineStore
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
                }
                Section("Apple Watch delivery") {
                    Label("Every FocusQuest reminder is eligible to mirror to your paired Apple Watch.", systemImage: "applewatch")
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
            }.navigationTitle("Settings")
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
