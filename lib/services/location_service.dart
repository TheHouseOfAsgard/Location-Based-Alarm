import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/alarm_target.dart';

class LocationService {
  /// Walks through the permission ladder. Call from the UI isolate (needs an Activity).
  /// Android 10+: "while in use" first, then "always" as a separate request.
  /// Android 11+: "always" is granted from system settings (permission_handler opens it).
  static Future<bool> ensurePermissions() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return false;
    }

    final whenInUse = await Permission.locationWhenInUse.request();
    if (!whenInUse.isGranted) return false;

    if (Platform.isAndroid) {
      await Permission.notification.request(); // Android 13+
    }

    final always = await Permission.locationAlways.request();
    if (!always.isGranted) return false;

    if (Platform.isAndroid &&
        !await Permission.ignoreBatteryOptimizations.isGranted) {
      await Permission.ignoreBatteryOptimizations.request(); // Doze exemption
    }
    return true;
  }

  static Future<Position?> tryGetPosition() async {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return null;
    }
    try {
      return await getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  static Future<Position> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: _settings(timeLimit: const Duration(seconds: 45)),
      );
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      rethrow;
    }
  }

  /// Haversine distance in meters.
  static double distanceMeters(Position p, AlarmTarget t) =>
      Geolocator.distanceBetween(p.latitude, p.longitude, t.latitude, t.longitude);

  /// iOS only: a low-rate background location stream keeps the process alive
  /// so the 5-minute timer keeps firing while the app is backgrounded.
  static Stream<Position> iosKeepAliveStream() => Geolocator.getPositionStream(
        locationSettings: AppleSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 100,
          activityType: ActivityType.otherNavigation,
          pauseLocationUpdatesAutomatically: false,
          allowBackgroundLocationUpdates: true,
          showBackgroundLocationIndicator: true,
        ),
      );

  static LocationSettings _settings({Duration? timeLimit}) {
    if (Platform.isAndroid) {
      return AndroidSettings(accuracy: LocationAccuracy.high, timeLimit: timeLimit);
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.otherNavigation,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
        timeLimit: timeLimit,
      );
    }
    return LocationSettings(accuracy: LocationAccuracy.high, timeLimit: timeLimit);
  }
}
