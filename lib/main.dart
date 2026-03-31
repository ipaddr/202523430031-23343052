import 'package:flutter/material.dart';
import 'screens/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RempahinApp());
}

class RempahinApp extends StatelessWidget {
  const RempahinApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2E7D32);
    const secondary = Color(0xFF66BB6A);
    const accent = Color(0xFF43A047);
    const background = Color(0xFFF4FAF4);
    const text = Color(0xFF1F2D1F);

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: primary,
          secondary: secondary,
          tertiary: accent,
          surface: background,
          onSurface: text,
          onPrimary: Colors.white,
          onSecondary: text,
          onTertiary: Colors.white,
        );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rempahin',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: colorScheme,
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: text,
          displayColor: text,
        ),
      ),
      home: const HomePage(),
    );
  }
}
