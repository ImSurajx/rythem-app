import 'package:flutter/material.dart';

void main() {
  runApp(const RythemApp());
}

class RythemApp extends StatelessWidget {
  const RythemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rythem',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: Color(0xFF141414),
        ),
      ),
      home: const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(
          child: Text(
            'RYTHEM',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              letterSpacing: 8,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ),
    );
  }
}
