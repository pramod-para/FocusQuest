import Foundation
@preconcurrency import WatchConnectivity

struct WatchGoalSnapshot: Codable {
    let id: String
    let title: String
    let timeText: String
    let points: Int
    let symbol: String
    let isComplete: Bool
    let isSkipped: Bool
}

struct WatchSnapshot: Codable {
    let dateKey: String
    let goals: [WatchGoalSnapshot]
    let waterOunces: Int
    let waterTarget: Int
    let points: Int
    let streak: Int

    @MainActor
    init(store: RoutineStore) {
        dateKey = store.todayKey
        goals = store.todayGoals.map { goal in
            WatchGoalSnapshot(
                id: goal.id,
                title: goal.title,
                timeText: store.scheduledTime(for: goal).formatted(date: .omitted, time: .shortened),
                points: goal.points,
                symbol: goal.kind.icon,
                isComplete: store.isComplete(goal),
                isSkipped: store.isSkipped(goal)
            )
        }
        waterOunces = store.today.waterOunces
        waterTarget = RoutinePlan.waterTarget
        points = store.todayPoints
        streak = store.streak
    }
}

@MainActor
final class PhoneWatchConnectivity: NSObject, WCSessionDelegate {
    static let shared = PhoneWatchConnectivity()
    private var pendingSnapshot: WatchSnapshot?

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func send(snapshot: WatchSnapshot) {
        pendingSnapshot = snapshot
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        sendNow(snapshot, session: .default)
    }

    private func sendNow(_ snapshot: WatchSnapshot, session: WCSession) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? session.updateApplicationContext(["snapshot": data])
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        Task { @MainActor in
            guard activationState == .activated, let pendingSnapshot else { return }
            sendNow(pendingSnapshot, session: session)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) { }

    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handle(userInfo)
    }

    nonisolated private func handle(_ message: [String: Any]) {
        guard let action = message["action"] as? String else { return }
        let goalID = message["goalID"] as? String
        let ounces = message["ounces"] as? Int ?? 8
        Task { @MainActor in
            let store = RoutineStore.shared
            switch action {
            case "complete":
                if let goalID { store.completeGoal(id: goalID) }
            case "skip":
                if let goalID { store.skipToday(goalID: goalID) }
            case "water":
                store.addWater(ounces)
            case "refresh":
                store.publishWatchSnapshot()
            default:
                break
            }
        }
    }
}
