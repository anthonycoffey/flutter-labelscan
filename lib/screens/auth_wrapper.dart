import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_labelscan/screens/auth_screen.dart';
import 'package:flutter_labelscan/screens/main_screen.dart'; // Import MainScreen

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // User is logged in
        if (snapshot.connectionState == ConnectionState.active) {
          if (snapshot.hasData) {
            return const MainScreen(); // Go to the main screen with tabs
          }
          // User is not logged in
          return const AuthScreen(); // Go to login/signup screen
        }
        // Waiting for connection
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
