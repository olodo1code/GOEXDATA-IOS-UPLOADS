import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'webview_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    final navigator = Navigator.of(context);
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      navigator.pushReplacement(
        MaterialPageRoute(builder: (context) => const WebViewScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Image.asset(
                'assets/splash.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 30),
            const SpinKitDoubleBounce(
              color: Colors.blue,
              size: 40.0,
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
