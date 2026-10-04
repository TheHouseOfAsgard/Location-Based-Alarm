import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:vibration/vibration.dart';
import '../constants.dart';

/// Looping sound + patterned vibration with a hard 300 s cut-off.
/// Runs inside the background isolate.
class AlarmService {
  final AudioPlayer _player = AudioPlayer();
  Timer? _autoStop;
  bool _ringing = false;

  bool get isRinging => _ringing;

  Future<void> start({required Future<void> Function() onFinished}) async {
    if (_ringing) return;
    _ringing = true;

    // Push the alarm stream to max (best effort; plugin may be unavailable).
    try {
      await FlutterVolumeController.updateShowSystemUI(false);
      await FlutterVolumeController.setVolume(1.0, stream: AudioStream.alarm);
    } catch (_) {}

    await _player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm, // routes via the alarm stream
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {},
        ),
      ),
    );
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(1.0);
    await _player.play(AssetSource('alarm.mp3'));

    if (await Vibration.hasVibrator() == true) {
      // repeat: 0 => loop the pattern from index 0 until cancelled.
      Vibration.vibrate(pattern: [0, 800, 400, 800, 400, 1200, 600], repeat: 0);
    }

    _autoStop = Timer(const Duration(seconds: alarmDurationSeconds), () async {
      await stop();
      await onFinished();
    });
  }

  Future<void> stop() async {
    _autoStop?.cancel();
    _autoStop = null;
    _ringing = false;
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await Vibration.cancel();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
