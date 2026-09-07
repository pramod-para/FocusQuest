import Foundation
import HealthKit

@MainActor
final class HealthKitManager: ObservableObject {
    @Published private(set) var status = "Not connected"
    @Published private(set) var isRefreshing = false

    private let healthStore = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func connectAndRefresh(store: RoutineStore) async {
        guard isAvailable else {
            status = "Apple Health is unavailable on this device"
            return
        }
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount),
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            status = "Required Apple Health data types are unavailable"
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let readTypes: Set<HKObjectType> = [stepType, HKObjectType.workoutType(), sleepType]
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            try await refresh(store: store, stepType: stepType, sleepType: sleepType)
        } catch {
            status = "Apple Health could not be connected"
        }
    }

    func refresh(store: RoutineStore) async {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount),
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            try await refresh(store: store, stepType: stepType, sleepType: sleepType)
        } catch {
            status = "Could not refresh Apple Health"
        }
    }

    private func refresh(store: RoutineStore, stepType: HKQuantityType, sleepType: HKCategoryType) async throws {
        let calendar = Calendar.current
        let now = Date.now
        let startOfToday = calendar.startOfDay(for: now)
        let sleepStart = calendar.date(byAdding: .hour, value: -18, to: startOfToday) ?? startOfToday

        async let steps = querySteps(type: stepType, from: startOfToday, to: now)
        async let workoutMinutes = queryWorkoutMinutes(from: startOfToday, to: now)
        async let sleepMinutes = querySleepMinutes(type: sleepType, from: sleepStart, to: now)
        let values = try await (steps, workoutMinutes, sleepMinutes)

        store.updateHealthMetrics(steps: values.0, workoutMinutes: values.1, sleepMinutes: values.2)
        status = "Updated just now"
    }

    private func querySteps(type: HKQuantityType, from start: Date, to end: Date) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                if let error { continuation.resume(throwing: error); return }
                let count = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(count.rounded()))
            }
            healthStore.execute(query)
        }
    }

    private func queryWorkoutMinutes(from start: Date, to end: Date) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let seconds = (samples as? [HKWorkout] ?? []).reduce(0) { $0 + $1.duration }
                continuation.resume(returning: Int((seconds / 60).rounded()))
            }
            healthStore.execute(query)
        }
    }

    private func querySleepMinutes(type: HKCategoryType, from start: Date, to end: Date) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let intervals = (samples as? [HKCategorySample] ?? []).compactMap { sample -> DateInterval? in
                    guard Self.isAsleep(sample.value) else { return nil }
                    return DateInterval(start: max(sample.startDate, start), end: min(sample.endDate, end))
                }
                continuation.resume(returning: Self.mergedMinutes(intervals))
            }
            healthStore.execute(query)
        }
    }

    nonisolated private static func isAsleep(_ value: Int) -> Bool {
        value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
        value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
        value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
        value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
    }

    nonisolated private static func mergedMinutes(_ intervals: [DateInterval]) -> Int {
        let sorted = intervals.filter { $0.duration > 0 }.sorted { $0.start < $1.start }
        guard var current = sorted.first else { return 0 }
        var seconds: TimeInterval = 0
        for interval in sorted.dropFirst() {
            if interval.start <= current.end {
                current = DateInterval(start: current.start, end: max(current.end, interval.end))
            } else {
                seconds += current.duration
                current = interval
            }
        }
        seconds += current.duration
        return Int((seconds / 60).rounded())
    }
}
