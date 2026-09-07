# FocusQuest

A privacy-first SwiftUI app that turns the daily health, focus, movement, and family routine into a lightweight game.

## Included in the MVP

- Chronological daily goals based on `DAILY.md`
- Add, rename, schedule, reorder, and delete activities
- Per-activity weekday selection and duration
- Per-activity reminders at the start time or 5–30 minutes before
- Global quiet hours and actionable Complete, Snooze, and Skip notifications
- Points, levels, completion percentage, and streaks
- 80 oz water tracker
- Hourly movement and meal reminders
- Protected 5–6 p.m. baby-time reminder
- Seven-day history chart
- Opt-in automatic Screen Time totals, pickups, and seven-day trends
- Completion timestamps recorded at check-in
- On-device weekly coaching based on missed goals
- Private iCloud persistence through CloudKit, with an offline on-device cache
- Automatic notification forwarding to a paired Apple Watch

## Run

1. Open `FocusQuest.xcodeproj` in Xcode.
2. Select the FocusQuest target, then choose your Apple Developer team under **Signing & Capabilities**.
3. Replace `com.example.FocusQuest` with your unique bundle identifier.
4. Replace `iCloud.com.example.FocusQuest` in `FocusQuest.entitlements` with an iCloud container owned by your team.
5. In **Signing & Capabilities**, enable iCloud and check **CloudKit**.
6. Add the **Family Controls** capability to both the FocusQuest and FocusQuestReport targets.
7. Set the report extension bundle identifier to use the app identifier as its prefix (for example, `com.example.FocusQuest.Report`).
8. Choose an iPhone or iPad device and press Run. Apple’s Screen Time reports aren’t available in the simulator.

The checked-in identifiers are placeholders. The repository contains no Apple ID, developer-team identifier, signing certificate, API key, or personal health history.

Notification permission is requested only after tapping **Enable daily reminders** in Settings.

For Watch delivery, open the Watch app on the paired iPhone, select **My Watch → Notifications**, and enable FocusQuest under **Mirror iPhone Alerts From**. Apple sends an alert to the Watch when the iPhone is locked or asleep and the Watch is unlocked; it normally does not alert both devices simultaneously.

### Free Personal Team testing

Apple does not allow CloudKit or Family Controls on a free Personal Team. Select the included **FocusQuestLocal** scheme to test the routine, reminders, and interface without either capability. The Screen Time tab explains why automatic reporting is unavailable in that build. Production builds should use the **FocusQuest** scheme, retain the checked-in CloudKit and Family Controls entitlements, and use a paid Apple Developer Program team.

Before App Store distribution, the Account Holder must request Apple’s Family Controls distribution entitlement for both the app and the FocusQuestReport extension.

## Next iterations

1. HealthKit import for workouts, steps, sleep, and historical trends (opt-in)
2. Adaptive reminders based on completion patterns and missed activities
3. Data export and account-safe deletion controls
4. Widgets, Live Activities, and Apple Watch companion
5. Safer recommendation rules with user-selected goals and constraints

## Privacy architecture

- Routine history is written to the current user's **private CloudKit database**.
- A local `UserDefaults` cache supports offline use; it contains only that installation's routine records.
- Notifications are scheduled locally and require explicit permission.
- Screen Time authorization is optional. Total usage, pickups, and the seven-day chart are rendered inside Apple’s sandboxed Device Activity report extension; raw app and website history is not copied into the app or uploaded to iCloud.
- No analytics SDK, advertising SDK, backend server, or third-party tracking library is included.
- The recommendation engine runs on-device.

## License

MIT
