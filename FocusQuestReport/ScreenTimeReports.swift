import DeviceActivity
import ExtensionKit
import SwiftUI

extension DeviceActivityReport.Context {
    static let focusQuestToday = Self("FocusQuest.Today")
    static let focusQuestWeek = Self("FocusQuest.Week")
}

struct TodayActivityConfiguration {
    let totalDuration: TimeInterval
    let pickups: Int
}

struct DayActivity: Identifiable {
    let date: Date
    let duration: TimeInterval
    var id: Date { date }
}

struct WeekActivityConfiguration {
    let days: [DayActivity]
    let dailyAverage: TimeInterval
}

struct TodayActivityReport: @preconcurrency DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .focusQuestToday
    let content: (TodayActivityConfiguration) -> TodayActivityReportView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> TodayActivityConfiguration {
        var totalDuration: TimeInterval = 0
        var pickups = 0
        for await device in data {
            for await segment in device.activitySegments {
                totalDuration += segment.totalActivityDuration
                pickups += segment.totalPickupsWithoutApplicationActivity
                for await category in segment.categories {
                    for await application in category.applications {
                        pickups += application.numberOfPickups
                    }
                }
            }
        }
        return TodayActivityConfiguration(totalDuration: totalDuration, pickups: pickups)
    }
}

struct WeekActivityReport: @preconcurrency DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .focusQuestWeek
    let content: (WeekActivityConfiguration) -> WeekActivityReportView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> WeekActivityConfiguration {
        let calendar = Calendar.current
        var durationByDay: [Date: TimeInterval] = [:]
        for await device in data {
            for await segment in device.activitySegments {
                let day = calendar.startOfDay(for: segment.dateInterval.start)
                durationByDay[day, default: 0] += segment.totalActivityDuration
            }
        }

        let today = calendar.startOfDay(for: .now)
        let days = (-6...0).compactMap { offset -> DayActivity? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return DayActivity(date: date, duration: durationByDay[date, default: 0])
        }
        let average = days.isEmpty ? 0 : days.reduce(0) { $0 + $1.duration } / Double(days.count)
        return WeekActivityConfiguration(days: days, dailyAverage: average)
    }
}

struct TodayActivityReportView: View {
    let configuration: TodayActivityConfiguration

    var body: some View {
        HStack(spacing: 24) {
            metric(title: "Screen time", value: durationText(configuration.totalDuration), icon: "hourglass")
            Divider()
            metric(title: "Pickups", value: "\(configuration.pickups)", icon: "hand.tap.fill")
        }
        .padding(.vertical, 10)
    }

    private func metric(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon).foregroundStyle(.indigo)
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WeekActivityReportView: View {
    let configuration: WeekActivityConfiguration

    private var maximumDuration: TimeInterval {
        max(configuration.days.map(\.duration).max() ?? 0, 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily average").foregroundStyle(.secondary)
                Spacer()
                Text(durationText(configuration.dailyAverage)).font(.headline.monospacedDigit())
            }
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(configuration.days) { day in
                    VStack(spacing: 5) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.indigo.gradient)
                            .frame(height: max(5, 105 * day.duration / maximumDuration))
                        Text(day.date.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 132)
        }
        .padding(.vertical, 8)
    }
}

private func durationText(_ duration: TimeInterval) -> String {
    let minutes = max(0, Int(duration / 60))
    let hours = minutes / 60
    let remainder = minutes % 60
    if hours == 0 { return "\(remainder)m" }
    return "\(hours)h \(remainder)m"
}
