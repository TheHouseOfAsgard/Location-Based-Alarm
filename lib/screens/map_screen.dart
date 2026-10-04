import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../state/tracking_controller.dart';
import 'alarm_overlay.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _map = MapController();
  bool _centered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TrackingController>();

    if (!_centered && (c.current != null || c.target != null)) {
      _centered = true;
      final focus = c.target ?? c.current!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _map.move(focus, 13));
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: c.current ?? c.target ?? const LatLng(20, 0),
              initialZoom: (c.current ?? c.target) == null ? 2 : 13,
              onTap: (_, point) => c.setTarget(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.location_alarm',
              ),
              if (c.target != null)
                CircleLayer(circles: [
                  CircleMarker(
                    point: c.target!,
                    radius: c.radiusKm * 1000,
                    useRadiusInMeter: true,
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderColor: Colors.blue,
                    borderStrokeWidth: 2,
                  ),
                ]),
              MarkerLayer(markers: [
                if (c.target != null)
                  Marker(
                    point: c.target!,
                    width: 48,
                    height: 48,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 48),
                  ),
                if (c.current != null)
                  Marker(
                    point: c.current!,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
              ]),
              const RichAttributionWidget(attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ]),
            ],
          ),
          Positioned(left: 12, right: 12, bottom: 0, child: _ControlPanel(c: c)),
          if (c.alarmActive) const AlarmOverlay(),
        ],
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({required this.c});
  final TrackingController c;

  static String _fmt(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(2)} km' : '${m.round()} m';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Card(
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.target == null
                    ? 'Tap the map to set your destination'
                    : c.distanceMeters == null
                        ? 'Destination set'
                        : 'Distance remaining: ${_fmt(c.distanceMeters!)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(children: [
                Text('Radius: ${c.radiusKm.toStringAsFixed(1)} km'),
                Expanded(
                  child: Slider(
                    min: 1,
                    max: 5,
                    divisions: 8,
                    value: c.radiusKm,
                    label: '${c.radiusKm.toStringAsFixed(1)} km',
                    onChanged: c.setRadius,
                  ),
                ),
              ]),
              if (c.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(c.error!, style: const TextStyle(color: Colors.red)),
                ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.isTracking ? Colors.red : null,
                  ),
                  icon: Icon(c.isTracking ? Icons.stop : Icons.play_arrow),
                  label: Text(c.isTracking ? 'Stop Tracking' : 'Start Tracking'),
                  onPressed: c.isTracking ? c.stopTracking : c.startTracking,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
