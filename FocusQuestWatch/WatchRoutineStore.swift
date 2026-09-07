import Foundation
@preconcurrency import WatchConnectivity

struct WatchGoal: Codable, Identifiable {
    let id: String
    let title: String
    let timeText: String
    let points: Int
    let symbol: String
    var isComplete: Bool
    var isSkipped: Bool
}

struct WatchDay: Codable {
    let dateKey: String
    var goals: [WatchGoal]
    var waterOunces: Int
    let waterTarget: Int
    var points: Int
    let streak: Int
}

@MainActor
final class WatchRoutineStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var day: WatchDay?
    @Published private(set) var connectionText = "Connecting to iPhone…"

    private let cacheKey = "focusquest.watch.snapshot.v1"

    override init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: cacheKey) {
            day = try? JSONDecoder().decode(WatchDay.self, from: data)
        }
        guard WCSession.isSupported() else {
            connectionText = "Open FocusQuest on iPhone to sync"
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func complete(_ goal: WatchGoal) {
        guard !goal.isComplete else { return }
        if let index = day?.goals.firstIndex(where: { $0.id == goal.id }) {
            day?.goals[index].isComplete = true
            day?.goals[index].isSkipped = false
            day?.points += goal.points
        }
        saveCache()
        send(["action": "complete", "goalID": goal.id])
    }

    func skip(_ goal: WatchGoal) {
        guard !goal.isComplete else { return }
        if let index = day?.goals.firstIndex(where: { $0.id == goal.id }) {
            day?.goals[index].isSkipped = true
        }
        saveCache()
        send(["action": "skip", "goalID": goal.id])
    }

    func addWater(_ ounces: Int = 8) {
        day?.waterOunces += ounces
        saveCache()
        send(["action": "water", "ounces": ounces])
    }

    func requestRefresh() { send(["action": "refresh"]) }

    private func send(_ message: [String: Any]) {
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { _ in
                session.transferUserInfo(message)
            }
        } else {
            session.transferUserInfo(message)
        }
    }

    private func receive(_ data: Data) {
        guard let decoded = try? JSONDecoder().decode(WatchDay.self, from: data) else { return }
        day = decoded
        UserDefaults.standard.set(data, forKey: cacheKey)
        connectionText = "Synced with iPhone"
    }

    private func saveCache() {
        guard let day, let data = try? JSONEncoder().encode(day) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        let snapshotData = session.receivedApplicationContext["snapshot"] as? Data
        Task { @MainActor in
            connectionText = activationState == .activated ? "Connected to iPhone" : "Open FocusQuest on iPhone to sync"
            if let snapshotData { receive(snapshotData) }
            requestRefresh()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["snapshot"] as? Data else { return }
        Task { @MainActor in receive(data) }
    }
}
