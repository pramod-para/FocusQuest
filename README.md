# FocusQuest

A privacy-first SwiftUI app that turns the daily health, focus, movement, and family routine into a lightweight game.

## Included in the MVP

- Chronological daily goals based on `DAILY.md`
- Add, rename, schedule, reorder, and delete activities
- Per-activity weekday selection and duration
- Points, levels, completion percentage, and streaks
- 80 oz water tracker
- Hourly movement and meal reminders
- Protected 5–6 p.m. baby-time reminder
- Seven-day history chart
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
6. Choose an iPhone simulator or device and press Run.

The checked-in identifiers are placeholders. The repository contains no Apple ID, developer-team identifier, signing certificate, API key, or personal health history.

Notification permission is requested only after tapping **Enable daily reminders** in Settings.

For Watch delivery, open the Watch app on the paired iPhone, select **My Watch → Notifications**, and enable FocusQuest under **Mirror iPhone Alerts From**. Apple sends an alert to the Watch when the iPhone is locked or asleep and the Watch is unlocked; it normally does not alert both devices simultaneously.

### Free Personal Team testing

Apple does not allow CloudKit entitlements on a free Personal Team. Contributors can still test the interface and local notifications by using an empty local entitlement file and adding `-DFOCUSQUEST_LOCAL_ONLY` to **Other Swift Flags** for the Debug configuration. Files ending in `.local.entitlements` are ignored by Git. Production builds should retain the checked-in CloudKit entitlement and use a paid Apple Developer team.

## Next iterations

1. HealthKit import for workouts, steps, sleep, and historical trends (opt-in)
2. Editable schedules and notification days
3. Data export and account-safe deletion controls
4. Widgets, Live Activities, and Apple Watch companion
5. Safer recommendation rules with user-selected goals and constraints

## Privacy architecture

- Routine history is written to the current user's **private CloudKit database**.
- A local `UserDefaults` cache supports offline use; it contains only that installation's routine records.
- Notifications are scheduled locally and require explicit permission.
- No analytics SDK, advertising SDK, backend server, or third-party tracking library is included.
- The recommendation engine runs on-device.

## License

MIT
