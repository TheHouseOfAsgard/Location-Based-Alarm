import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:latlong2/latlong.dart';
import '../models/alarm_target.dart';
import '../services/location_service.dart';

class TrackingController extends ChangeNotifier {
  final FlutterBackgroundService _service = FlutterBackgroundService();
  final List<StreamSubscription> _subs = [];

  LatLng? target;
  double radiusKm = 2;
  LatLng? current;
  double? distanceMeters;
  bool isTracking = false;
  bool alarmActive = false;
  String? error;

  Future<void> init() async {
    final saved = await AlarmTarget.load();
    if (saved != null) {
      target = LatLng(saved.latitude, saved.longitude);
      radiusKm = saved.radiusKm;
    }
    _listen();

    isTracking = await _service.isRunning();
    if (isTracking) _service.invoke('requestState');
    notifyListeners();

    final pos = await LocationService.tryGetPosition();
    if (pos != null) {
      current = LatLng(pos.latitude, pos.longitude);
      notifyListeners();
    }
  }

  void _listen() {
    _subs.add(_service.on('update').listen((e) {
      if (e == null) return;
      current = LatLng((e['lat'] as num).toDouble(), (e['lng'] as num).toDouble());
      distanceMeters = (e['distance'] as num).toDouble();
      error = null;
      notifyListeners();
    }));
    _subs.add(_service.on('state').listen((e) {
      if (e == null) return;
      alarmActive = e['alarmActive'] == true;
      if (e['lat'] != null) {
        current = LatLng((e['lat'] as num).toDouble(), (e['lng'] as num).toDouble());
      }
      if (e['distance'] != null) distanceMeters = (e['distance'] as num).toDouble();
      notifyListeners();
    }));
    _subs.add(_service.on('alarm').listen((_) {
      alarmActive = true;
      notifyListeners();
    }));
    _subs.add(_service.on('alarmStopped').listen((_) {
      alarmActive = false;
      notifyListeners();
    }));
    _subs.add(_service.on('stopped').listen((_) {
      isTracking = false;
      alarmActive = false;
      notifyListeners();
    }));
    _subs.add(_service.on('error').listen((e) {
      error = e?['message']?.toString();
      notifyListeners();
    }));
  }

  void setTarget(LatLng p) {
    target = p;
    distanceMeters = null;
    error = null;
    notifyListeners();
    if (isTracking) _persistAndNotifyService();
  }

  void setRadius(double km) {
    radiusKm = km;
    notifyListeners();
    if (isTracking) _persistAndNotifyService();
  }

  Future<void> _persistAndNotifyService() async {
    await _persist();
    _service.invoke('configure');
  }

  Future<void> _persist() => AlarmTarget(
        latitude: target!.latitude,
        longitude: target!.longitude,
        radiusKm: radiusKm,
      ).save();

  Future<void> startTracking() async {
    if (target == null) {
      error = 'Tap the map to choose a destination first.';
      notifyListeners();
      return;
    }
    if (!await LocationService.ensurePermissions()) {
      error = 'Location (Always), notification and battery permissions are required.';
      notifyListeners();
      return;
    }
    await _persist();
    if (await _service.isRunning()) {
      _service.invoke('configure');
    } else {
      await _service.startService();
    }
    isTracking = true;
    error = null;
    notifyListeners();
  }

  void stopTracking() {
    _service.invoke('stopService');
    isTracking = false;
    alarmActive = false;
    notifyListeners();
  }

  void dismissAlarm() {
    _service.invoke('stopAlarm');
    alarmActive = false;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
