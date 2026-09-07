import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject private var store: WatchRoutineStore

    var body: some View {
        NavigationStack {
            if let day = store.day {
                List {
                    Section {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Today").font(.headline)
                                Text("\(day.points) pts · \(day.streak)-day streak")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Gauge(value: completion(day)) {
                                Image(systemName: "checkmark")
                            }
                            .gaugeStyle(.accessoryCircular)
                            .tint(.indigo)
                        }
                    }

                    Section("Water") {
                        Button { store.addWater() } label: {
                            HStack {
                                Label("\(day.waterOunces) / \(day.waterTarget) oz", systemImage: "drop.fill")
                                Spacer()
                                Text("+8").font(.headline).foregroundStyle(.cyan)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.cyan)
                    }

                    Section("Activities") {
                        ForEach(day.goals) { goal in
                            Button { store.complete(goal) } label: {
                                HStack {
                                    Image(systemName: goal.isComplete ? "checkmark.circle.fill" : (goal.isSkipped ? "minus.circle.fill" : goal.symbol))
                                        .foregroundStyle(goal.isComplete ? .green : (goal.isSkipped ? .secondary : .indigo))
                                    VStack(alignment: .leading) {
                                        Text(goal.title).strikethrough(goal.isComplete || goal.isSkipped)
                                        Text(goal.isComplete ? "Completed" : (goal.isSkipped ? "Skipped" : goal.timeText))
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                if !goal.isComplete && !goal.isSkipped {
                                    Button("Skip") { store.skip(goal) }.tint(.gray)
                                }
                            }
                        }
                    }

                    Text(store.connectionText).font(.caption2).foregroundStyle(.secondary)
                }
                .navigationTitle("FocusQuest")
            } else {
                ContentUnavailableView {
                    Label("Waiting for iPhone", systemImage: "iphone.and.arrow.forward")
                } description: {
                    Text("Open FocusQuest on your iPhone once, then tap Refresh.")
                } actions: {
                    Button("Refresh") { store.requestRefresh() }
                }
            }
        }
    }

    private func completion(_ day: WatchDay) -> Double {
        let active = day.goals.filter { !$0.isSkipped }
        guard !active.isEmpty else { return 0 }
        return Double(active.filter(\.isComplete).count) / Double(active.count)
    }
}
