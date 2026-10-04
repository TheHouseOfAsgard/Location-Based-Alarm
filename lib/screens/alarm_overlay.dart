import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/tracking_controller.dart';

/// Full-screen overlay. Place inside a Stack.
class AlarmOverlay extends StatelessWidget {
  const AlarmOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.read<TrackingController>();
    return Positioned.fill(
      child: Material(
        color: Colors.red.shade900,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.alarm, size: 120, color: Colors.white),
                const SizedBox(height: 24),
                const Text('You have arrived!',
                    style: TextStyle(
                        color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Within ${c.radiusKm} km of your destination',
                    style: const TextStyle(color: Colors.white70, fontSize: 18)),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red.shade900,
                    ),
                    onPressed: c.dismissAlarm,
                    child: const Text('Dismiss Alarm',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
