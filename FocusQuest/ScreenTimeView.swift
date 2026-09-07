import SwiftUI
import DeviceActivity
@preconcurrency import FamilyControls

extension DeviceActivityReport.Context {
    static let focusQuestToday = Self("FocusQuest.Today")
    static let focusQuestWeek = Self("FocusQuest.Week")
}

struct ScreenTimeDashboardView: View {
    #if !FOCUSQUEST_LOCAL_ONLY
    @ObservedObject private var authorizationCenter = AuthorizationCenter.shared
    @AppStorage("focusquest.screenTimeOptIn") private var screenTimeOptIn = false
    @State private var authorizationMessage = ""
    #endif

    var body: some View {
        NavigationStack {
            Group {
                #if FOCUSQUEST_LOCAL_ONLY
                localTestingExplanation
                #else
                if isAuthorized {
                    reportContent
                } else {
                    authorizationContent
                }
                #endif
            }
            .navigationTitle("Screen Time")
            #if !FOCUSQUEST_LOCAL_ONLY
            .task {
                if screenTimeOptIn && !isAuthorized {
                    await requestAuthorization()
                }
            }
            #endif
        }
    }

    #if FOCUSQUEST_LOCAL_ONLY
    private var localTestingExplanation: some View {
        ContentUnavailableView {
            Label("Screen Time needs permission", systemImage: "hourglass")
        } description: {
            Text("Automatic Screen Time reporting is included in FocusQuest, but this local build is signed without Apple’s Family Controls capability. Your routine and reminders still work normally.")
        }
    }
    #else
    private var isAuthorized: Bool {
        switch authorizationCenter.authorizationStatus {
        case .approved: true
        default: false
        }
    }

    private var authorizationContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "hourglass")
                .font(.system(size: 54))
                .foregroundStyle(.indigo)
            Text("Understand your phone habits")
                .font(.title2.bold())
            Text("FocusQuest can show your total iPhone use and pickups for today and the last seven days. Apple keeps the underlying app and website history inside a protected report.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Allow Screen Time access") {
                Task { await requestAuthorization() }
            }
            .buttonStyle(.borderedProminent)
            if !authorizationMessage.isEmpty {
                Text(authorizationMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Text("Permission is optional and can be revoked in iPhone Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(28)
    }

    private var reportContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Today", systemImage: "iphone")
                        .font(.headline)
                    DeviceActivityReport(.focusQuestToday, filter: todayFilter)
                        .frame(height: 150)
                }
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 8) {
                    Label("Last 7 days", systemImage: "chart.bar.fill")
                        .font(.headline)
                    DeviceActivityReport(.focusQuestWeek, filter: weekFilter)
                        .frame(height: 210)
                }
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 20))

                Label("Screen Time details stay in Apple’s privacy-protected report and are not uploaded to FocusQuest or iCloud.", systemImage: "lock.shield.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var todayFilter: DeviceActivityFilter {
        let interval = DateInterval(start: Calendar.current.startOfDay(for: .now), end: .now)
        return DeviceActivityFilter(
            segment: .hourly(during: interval),
            users: .all,
            devices: .init([.iPhone])
        )
    }

    private var weekFilter: DeviceActivityFilter {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? .now
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: start, end: end)),
            users: .all,
            devices: .init([.iPhone])
        )
    }

    private func requestAuthorization() async {
        do {
            try await authorizationCenter.requestAuthorization(for: .individual)
            screenTimeOptIn = authorizationCenter.authorizationStatus == .approved
            authorizationMessage = authorizationCenter.authorizationStatus == .approved
                ? "Screen Time reporting is ready."
                : "Screen Time access was not approved."
        } catch {
            authorizationMessage = "FocusQuest could not request Screen Time access. Check the Family Controls capability and try again."
        }
    }
    #endif
}
