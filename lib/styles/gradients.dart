import 'package:flutter/material.dart';

// Gradient yang dipakai berulang untuk elemen branding.
class Gradients {
  static const LinearGradient kAccent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF22D3EE), Color(0xFF3B82F6), Color(0xFF8B5CF6)],
  );

  static const Gradient accent = kAccent;
}
