# Location Alarm – Setup Guide

## 1. Create the project and drop in the files
```bash
flutter create --org com.example --project-name location_alarm location_alarm
cd location_alarm
# copy lib/, pubspec.yaml, android/app/src/main/AndroidManifest.xml, ios/Runner/Info.plist over the generated ones
mkdir assets   # put your alarm sound at assets/alarm.mp3
flutter pub get
```
If your org/package differs from `com.example.location_alarm`, update `userAgentPackageName` in `map_screen.dart`.
Versions in pubspec are pinned exactly; run `flutter pub outdated` to see newer ones.
(flutter_local_notifications 18.x uses positional `initialize/show` – if you bump to 19+, the call signatures change.)

## 2. Android
`android/app/build.gradle(.kts)`:
```groovy
android {
    compileSdk = 35
    compileOptions { coreLibraryDesugaringEnabled true }   // flutter_local_notifications
    defaultConfig { minSdk = 23 }
}
dependencies { coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4' }
```
(Kotlin DSL: `isCoreLibraryDesugaringEnabled = true` and `coreLibraryDesugaring("...")`.)

### Background-location permission flow (what the app does on "Start Tracking")
1. Location services check → opens system location settings if off.
2. `locationWhenInUse` dialog (Android 10+ requires this FIRST).
3. `POST_NOTIFICATIONS` dialog (Android 13+).
4. `locationAlways`: on Android 11+ there is no dialog – the system opens the app's permission page; the user must choose **"Allow all the time"**. Tell users this in onboarding copy.
5. Battery-optimization exemption dialog (Doze bypass, below).
Android 14+: the service must be typed `location` (done in the manifest override + `foregroundServiceTypes`) and started while the app is visible – Start Tracking does this.
Android 14+ also treats `USE_FULL_SCREEN_INTENT` as user-revocable for non-calling/alarm apps; if the lock-screen takeover doesn't appear, enable "Full-screen notifications" in App settings.

### Doze / OEM battery killers
- The `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` prompt whitelists the app from Doze and App Standby. Without it, the 5-minute `Timer` can be delayed by minutes while the screen is off.
- On Xiaomi/Huawei/Oppo/Vivo/Samsung etc. also enable **Autostart / "Unrestricted" battery / "Lock in recents"** (see dontkillmyapp.com). No API can do this for the user.
- Test with: `adb shell dumpsys deviceidle force-idle` and watch whether pings continue.
- If you need hard guarantees, add a native `AlarmManager.setExactAndAllowWhileIdle` heartbeat that pokes the service – the Dart `Timer` is best-effort under Doze.

## 3. iOS
1. Replace `ios/Runner/Info.plist` (or merge the keys): usage strings, `UIBackgroundModes` = location, processing, audio (+ `fetch`, needed by flutter_background_service), and `BGTaskSchedulerPermittedIdentifiers`.
2. Xcode → Runner → Signing & Capabilities → **+ Capability → Background Modes**: tick *Location updates*, *Audio*, *Background processing*, *Background fetch*.
3. `ios/Podfile` – enable the permission_handler modules:
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_LOCATION=1',
        'PERMISSION_LOCATION_WHENINUSE=1',
        'PERMISSION_LOCATION_ALWAYS=1',
        'PERMISSION_NOTIFICATIONS=1',
      ]
    end
  end
end
```
4. Always-location on iOS: the first request shows "While Using"; iOS later prompts the user to upgrade to "Always" (or they set it in Settings → Location). Start Tracking in the foreground so the blue background-location indicator is allowed.
5. **iOS reality check:** iOS does not allow arbitrary background timers. This build keeps the process alive via a low-power background location stream (`allowBackgroundLocationUpdates`) and runs the 5-minute check on top of it; the `audio` mode lets the alarm play. If the user force-quits the app, iOS stops it. For guaranteed wake-ups, consider region monitoring (`CLCircularRegion`) natively as a complement.

## 4. Run
```bash
flutter run --release        # background behaviour is unreliable in debug
```
1. Tap map → set radius → **Start Tracking** → grant permissions.
2. Lock the phone; the ongoing "Location tracking active..." notification shows distance every 5 min.
3. Within the radius: alarm sound + vibration for 300 s, full-screen overlay, **Dismiss Alarm** stops both and ends tracking.
Tip: test by setting the pin ~1 km away and radius 5 km – the first check runs immediately on start.
