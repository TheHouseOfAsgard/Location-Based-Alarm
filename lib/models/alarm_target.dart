import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

/// Destination + trigger radius. Persisted so the background isolate can read it.
class AlarmTarget {
  const AlarmTarget({
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
  });

  final double latitude;
  final double longitude;
  final double radiusKm;

  double get radiusMeters => radiusKm * 1000;

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefsTargetKey,
      jsonEncode({'lat': latitude, 'lng': longitude, 'radiusKm': radiusKm}),
    );
  }

  /// Reload first: the UI and background isolates have separate pref caches.
  static Future<AlarmTarget?> load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(prefsTargetKey);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return AlarmTarget(
        latitude: (m['lat'] as num).toDouble(),
        longitude: (m['lng'] as num).toDouble(),
        radiusKm: (m['radiusKm'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
