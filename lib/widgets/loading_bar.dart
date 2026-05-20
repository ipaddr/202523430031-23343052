import 'package:flutter/material.dart';

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
