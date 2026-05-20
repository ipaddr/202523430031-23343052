import 'package:flutter/material.dart';

class OnboardingCard extends StatelessWidget {
  final String imageAsset;

  const OnboardingCard({super.key, required this.imageAsset});

  @override
  Widget build(BuildContext context) {
    // Memastikan kartu onboarding memiliki rasio persegi (1:1)
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        double size;
        if (maxW.isFinite && maxH.isFinite) {
          size = maxW < maxH ? maxW : maxH;
        } else if (maxW.isFinite) {
          size = maxW;
        } else if (maxH.isFinite) {
          size = maxH;
        } else {
          size = 300.0; // cadangan jika ukuran tidak terhingga
        }

        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: SizedBox(
              width: size,
              height: size,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1220),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                  image: DecorationImage(
                    image: AssetImage(imageAsset),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
