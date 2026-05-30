import 'package:flutter/material.dart';

// Background utama yang dipakai di banyak halaman autentikasi dan dashboard.
class GameZoneBackground extends StatelessWidget {
  final Widget child;

  const GameZoneBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF060A1A),
                  Color(0xFF0A1030),
                  Color(0xFF080A1F),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.82, -0.92),
                radius: 1.05,
                colors: [Color(0x66219CFF), Color(0x00103870)],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.78, 0.96),
                radius: 1.0,
                colors: [Color(0x553D2CFF), Color(0x00162453)],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0x90010316),
                  Color(0x200D3A78),
                  Color(0x90010316),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x42000000),
                  Color(0x00000000),
                  Color(0x15000000),
                  Color(0x30000000),
                ],
                stops: [0.0, 0.32, 0.72, 1.0],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
