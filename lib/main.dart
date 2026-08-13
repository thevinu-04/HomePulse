import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'services/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final safetyMonitor = FirebaseService();
  unawaited(safetyMonitor.enforceSafetyCutoffs());
  unawaited(safetyMonitor.enforceScheduledLights());
  Timer.periodic(const Duration(seconds: 5), (_) {
    unawaited(safetyMonitor.enforceSafetyCutoffs());
    unawaited(safetyMonitor.enforceScheduledLights());
  });
  runApp(const SmartHomeApp());
}

class SmartHomeApp extends StatelessWidget {
  const SmartHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomePulse',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const AuthGate(),
    );
  }

  ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7356E8),
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF171422)
          : const Color(0xFFF8F7FF),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? const Color(0xFF171422)
            : const Color(0xFFF8F7FF),
        foregroundColor: scheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      useMaterial3: true,
    );
  }
}
