import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/home_shell_screen.dart';
import 'screens/splash_screen.dart';
import 'services/connection_status.dart';
import 'services/firebase_sensor_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    ConnectionStatus.disconnected(
      'Firebase belum terkonfigurasi di platform ini: $error',
    );
  }

  runApp(const HidroponikApp());
}

class HidroponikApp extends StatefulWidget {
  const HidroponikApp({super.key});

  @override
  State<HidroponikApp> createState() => _HidroponikAppState();
}

class _HidroponikAppState extends State<HidroponikApp> {
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monitoring Hidroponik',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: _initialized
          ? HomeShellScreen(
              sensorService: FirebaseSensorService(),
              greenhouseName: 'Greenhouse 1',
            )
          : SplashScreen(
              onInitialized: _onInitialized,
            ),
    );
  }

  void _onInitialized() {
    setState(() => _initialized = true);
  }
}
