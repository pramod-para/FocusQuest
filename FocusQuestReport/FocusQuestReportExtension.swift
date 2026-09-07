import DeviceActivity
import ExtensionKit
import SwiftUI

@main
@MainActor
struct FocusQuestReportExtension: @preconcurrency DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TodayActivityReport { configuration in
            TodayActivityReportView(configuration: configuration)
        }
        WeekActivityReport { configuration in
            WeekActivityReportView(configuration: configuration)
        }
    }
}
