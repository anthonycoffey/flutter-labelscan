import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart'; // Keep package but comment out import
import 'package:flutter_labelscan/screens/auth_wrapper.dart'; // Import your main screen/wrapper

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    // Wait for a short duration to show the splash screen
    // You could also perform async initialization here (e.g., load settings)
    await Future.delayed(const Duration(seconds: 3));

    // Ensure the widget is still mounted before navigating
    if (mounted) {
      // Replace the splash screen with the AuthWrapper
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // You might want to set a background color matching your theme
      // backgroundColor: Colors.white,
      body: Center(
        child: Image.asset( // Use Image.asset for PNG
          'lib/assets/logo-full@4x.png', // Use highest resolution PNG
          height: 150, // Adjust size as needed
          semanticLabel: 'LabelScan Full Logo',
          // Optional: Add scale parameter if needed, but height usually suffices
          // scale: 1.0,
        ),
      ),
    );
  }
}
