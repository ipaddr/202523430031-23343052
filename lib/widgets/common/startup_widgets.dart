import 'package:flutter/material.dart';

import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_theme.dart';
import 'package:gamezone/styles/gradients.dart';

// Komponen splash dan onboarding yang dipakai ulang pada halaman awal.
class LogoBox extends StatelessWidget {
  final double size;
  final Widget child;

  const LogoBox({super.key, required this.size, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentBlue.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppColors.accentCyan.withValues(alpha: 0.08),
            blurRadius: 60,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        child: Container(
          decoration: const BoxDecoration(gradient: Gradients.kAccent),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class LoadingBar extends StatefulWidget {
  final Duration duration;
  final double height;
  final Color backgroundColor;
  final Gradient gradient;
  final VoidCallback? onComplete;

  const LoadingBar({
    super.key,
    this.duration = const Duration(seconds: 3),
    this.height = 8.0,
    this.backgroundColor = const Color(0xFF334155),
    this.gradient = const LinearGradient(
      colors: [Color(0xFF22D3EE), Color(0xFF3B82F6)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    this.onComplete,
  });

  @override
  State<LoadingBar> createState() => _LoadingBarState();
}

class _LoadingBarState extends State<LoadingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: widget.height,
        color: widget.backgroundColor,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: _animation.value,
                child: Container(
                  decoration: BoxDecoration(gradient: widget.gradient),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class OnboardingCard extends StatelessWidget {
  final String imageAsset;

  const OnboardingCard({super.key, required this.imageAsset});

  @override
  Widget build(BuildContext context) {
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
          size = 300.0;
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
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
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

class SlideIndicator extends StatelessWidget {
  final int count;
  final int activeIndex;

  const SlideIndicator({
    super.key,
    required this.count,
    required this.activeIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final bool active = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: active ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF14B8FF) : const Color(0xFF2A2E3F),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}
