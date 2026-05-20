import 'package:flutter/material.dart';

class Gradients {
  static const Gradient accent = LinearGradient(
    colors: [Color(0xFF14B8FF), Color(0xFF7C4DFF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient kAccent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF22D3EE), Color(0xFF3B82F6), Color(0xFF8B5CF6)],
  );
}
