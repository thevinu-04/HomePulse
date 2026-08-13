import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'floor_list_screen.dart';
import 'sign_in_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasData) {
        return FloorListScreen(isDark: isDark, onToggleTheme: onToggleTheme);
      }
      return const SignInScreen();
    },
  );
}
