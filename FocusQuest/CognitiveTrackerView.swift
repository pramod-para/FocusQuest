import SwiftUI

struct CognitiveSummaryCard: View {
    @EnvironmentObject private var store: RoutineStore

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "brain.head.profile.fill")
                .font(.title).foregroundStyle(.indigo).frame(width: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text("Cognitive check-in").font(.headline)
                if store.today.cognitive.hasOutcomeCheckIn {
                    Text("Energy \(store.today.cognitive.energyRating)/5 · Focus \(store.today.cognitive.focusRating)/5 · Stress \(store.today.cognitive.stressRating)/5")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Track what improves or drains your performance")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
        }
        .padding().background(.background, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct CognitiveTrackerView: View {
    @EnvironmentObject private var store: RoutineStore

    var body: some View {
        Form {
            Section {
                Text("Rate these at roughly the same time each evening. Consistency matters more than precision.")
                    .font(.footnote).foregroundStyle(.secondary)
                RatingRow(title: "Mental energy", low: "Drained", high: "Strong", value: cognitiveBinding(\.energyRating))
                RatingRow(title: "Focus quality", low: "Scattered", high: "Deep", value: cognitiveBinding(\.focusRating))
                RatingRow(title: "Stress load", low: "Calm", high: "Overloaded", value: cognitiveBinding(\.stressRating))
            } header: {
                Text("Performance outcomes")
            }

            Section {
                Stepper("Deep work: \(store.today.cognitive.deepWorkMinutes) min", value: cognitiveBinding(\.deepWorkMinutes), in: 0...480, step: 15)
                Stepper("Morning daylight: \(store.today.cognitive.morningDaylightMinutes) min", value: cognitiveBinding(\.morningDaylightMinutes), in: 0...120, step: 5)
            } header: {
                Text("Focus-supporting activities")
            } footer: {
                Text("Sleep, steps, workouts, and water are already imported or tracked elsewhere in FocusQuest.")
            }

            Section {
                Stepper("Caffeine: \(store.today.cognitive.caffeineServings) serving\(store.today.cognitive.caffeineServings == 1 ? "" : "s")", value: cognitiveBinding(\.caffeineServings), in: 0...10)
                if store.today.cognitive.caffeineServings > 0 {
                    DatePicker("Last caffeine", selection: lastCaffeineBinding, displayedComponents: .hourAndMinute)
                }
                Stepper("Alcohol: \(store.today.cognitive.alcoholDrinks) drink\(store.today.cognitive.alcoholDrinks == 1 ? "" : "s")", value: cognitiveBinding(\.alcoholDrinks), in: 0...12)
                Toggle("Energy crash after a meal", isOn: cognitiveBinding(\.mealEnergyCrash))
            } header: {
                Text("Possible drains")
            } footer: {
                Text("These are neutral observations—not failures. Tracking timing and response helps identify your own patterns.")
            }

            Section("Automatic signals today") {
                LabeledContent("Sleep", value: duration(store.today.importedSleepMinutes))
                LabeledContent("Workout", value: "\(store.today.importedWorkoutMinutes) min")
                LabeledContent("Steps", value: store.today.importedSteps.formatted())
                LabeledContent("Water", value: "\(store.today.waterOunces) oz")
            }

            Section("Your emerging pattern") {
                Text(store.cognitivePattern)
                Text("Personal comparisons require at least seven scored days and should not be interpreted as medical advice.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Cognitive performance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func cognitiveBinding<Value>(_ keyPath: WritableKeyPath<CognitiveRecord, Value>) -> Binding<Value> {
        Binding(
            get: { store.today.cognitive[keyPath: keyPath] },
            set: { value in
                var updated = store.today.cognitive
                updated[keyPath: keyPath] = value
                store.updateCognitiveRecord(updated)
            }
        )
    }

    private var lastCaffeineBinding: Binding<Date> {
        Binding(
            get: { store.today.cognitive.lastCaffeineAt ?? .now },
            set: { value in
                var updated = store.today.cognitive
                updated.lastCaffeineAt = value
                store.updateCognitiveRecord(updated)
            }
        )
    }

    private func duration(_ minutes: Int) -> String {
        guard minutes > 0 else { return "Not imported" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

private struct RatingRow: View {
    let title: String
    let low: String
    let high: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title)
                Spacer()
                Text(value == 0 ? "Not rated" : "\(value)/5")
                    .font(.subheadline.bold()).foregroundStyle(value == 0 ? Color.secondary : Color.indigo)
            }
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { rating in
                    Button {
                        value = rating
                    } label: {
                        Text("\(rating)").font(.subheadline.bold()).frame(maxWidth: .infinity).frame(height: 32)
                            .background(value == rating ? Color.indigo : Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(value == rating ? Color.white : Color.primary)
                    }.buttonStyle(.plain)
                }
            }
            HStack { Text(low); Spacer(); Text(high) }.font(.caption2).foregroundStyle(.secondary)
        }.padding(.vertical, 4)
    }
}
