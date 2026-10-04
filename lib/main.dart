import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/map_screen.dart';
import 'services/background_handler.dart';
import 'services/notification_helper.dart';
import 'state/tracking_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationHelper.init(createChannels: true); // channels must exist before the service starts
  await initializeBackgroundService();
  runApp(
    ChangeNotifierProvider(
      create: (_) => TrackingController()..init(),
      child: const LocationAlarmApp(),
    ),
  );
}

class LocationAlarmApp extends StatelessWidget {
  const LocationAlarmApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Location Alarm',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
        home: const MapScreen(),
      );
}
