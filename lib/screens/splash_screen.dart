import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // MDP Logo
            Image.asset(
              'assets/MDP_logo.jpeg',
              width: 150,
              // Fallback text if asset fails to load
              errorBuilder: (context, error, stackTrace) => const Text(
                'MDP',
                style: TextStyle(
                  fontSize: 72, 
                  fontWeight: FontWeight.w900, 
                  color: Colors.black, 
                  letterSpacing: 8
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
