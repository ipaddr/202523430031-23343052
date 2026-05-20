import 'package:flutter/material.dart';

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
