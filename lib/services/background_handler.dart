import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import '../constants.dart';
import '../models/alarm_target.dart';
import 'alarm_service.dart';
import 'location_service.dart';
import 'notification_helper.dart';

/// Call once from main() (after NotificationHelper.init(createChannels: true)).
Future<void> initializeBackgroundService() async {
  await FlutterBackgroundService().configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      autoStartOnBoot: false,
      isForegroundMode: true,
      notificationChannelId: trackingChannelId,
      initialNotificationTitle: 'Location Alarm',
      initialNotificationContent: 'Location tracking active...',
      foregroundServiceNotificationId: trackingNotificationId,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

/// Entry point of the background isolate.
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await NotificationHelper.init();
  await _TrackingEngine(service).run();
}

/// Messages
///  UI -> service: 'configure', 'stopAlarm', 'stopService', 'requestState'
///  service -> UI: 'update', 'alarm', 'alarmStopped', 'state', 'error', 'stopped'
class _TrackingEngine {
  _TrackingEngine(this.service);

  final ServiceInstance service;
  final AlarmService _alarm = AlarmService();

  AlarmTarget? _target;
  Timer? _ticker;
  StreamSubscription<Position>? _iosKeepAlive;
  bool _alarmActive = false;
  bool _checking = false;
  double? _lastDistance;
  Position? _lastPosition;

  Future<void> run() async {
    service.on('stopService').listen((_) => _shutdown());
    service.on('stopAlarm').listen((_) => _finishAlarm());
    service.on('requestState').listen((_) => _emitState());
    service.on('configure').listen((_) async {
      _target = await AlarmTarget.load();
      await _check();
    });

    _target = await AlarmTarget.load();
    if (_target == null) {
      await _shutdown();
      return;
    }

    if (Platform.isIOS) {
      _iosKeepAlive =
          LocationService.iosKeepAliveStream().listen((_) {}, onError: (_) {});
    }

    await _check(); // immediate first check
    _ticker = Timer.periodic(
      const Duration(seconds: trackingIntervalSeconds),
      (_) => _check(),
    );
  }

  Future<void> _check() async {
    final target = _target;
    if (_alarmActive || _checking || target == null) return;
    _checking = true;
    try {
      final pos = await LocationService.getCurrentPosition();
      final d = LocationService.distanceMeters(pos, target);
      _lastPosition = pos;
      _lastDistance = d;
      _updateOngoingNotification(d, target);
      service.invoke('update', {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'distance': d,
      });
      if (d <= target.radiusMeters) await _trigger(d);
    } catch (e) {
      service.invoke('error', {'message': '$e'});
    } finally {
      _checking = false;
    }
  }

  Future<void> _trigger(double distance) async {
    _alarmActive = true;
    _ticker?.cancel();
    await NotificationHelper.showAlarm('${_fmt(distance)} from your destination.');
    service.invoke('alarm', {'distance': distance});
    await _alarm.start(onFinished: _finishAlarm);
  }

  Future<void> _finishAlarm() async {
    if (!_alarmActive) return;
    _alarmActive = false;
    await _alarm.stop();
    await NotificationHelper.cancelAlarm();
    service.invoke('alarmStopped');
    await _shutdown();
  }

  void _emitState() {
    service.invoke('state', {
      'alarmActive': _alarmActive,
      'distance': _lastDistance,
      'lat': _lastPosition?.latitude,
      'lng': _lastPosition?.longitude,
    });
  }

  void _updateOngoingNotification(double d, AlarmTarget t) {
    final s = service;
    if (s is AndroidServiceInstance) {
      final hhmm = DateTime.now().toString().substring(11, 16);
      s.setForegroundNotificationInfo(
        title: 'Location tracking active...',
        content: '${_fmt(d)} to destination (alarm at ${t.radiusKm} km) · $hhmm',
      );
    }
  }

  Future<void> _shutdown() async {
    _ticker?.cancel();
    await _iosKeepAlive?.cancel();
    await _alarm.dispose();
    service.invoke('stopped');
    service.stopSelf();
  }

  static String _fmt(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(2)} km' : '${m.round()} m';
}
