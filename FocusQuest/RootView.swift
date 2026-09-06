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
                        ForEach(RoutinePlan.goals) { goal in GoalRow(goal: goal) }
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
        }.padding().background(.background, in: RoundedRectangle(cornerRadius: 20))
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
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(goal.time, style: .time).font(.subheadline.monospacedDigit())
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
    var count: Int { store.records[RoutineStore.key(for: date)]?.completedGoalIDs.count ?? 0 }
    var body: some View {
        VStack { Spacer(); RoundedRectangle(cornerRadius: 6).fill(.indigo.gradient).frame(height: max(6, CGFloat(count) / CGFloat(RoutinePlan.goals.count) * 110)); Text(date.formatted(.dateTime.weekday(.narrow))).font(.caption) }.frame(maxWidth: .infinity)
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
                    LabeledContent("Workout", value: "6:00–7:00 AM")
                    LabeledContent("Baby time", value: "5:00–6:00 PM")
                    LabeledContent("Meals", value: "3 daily")
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
