import 'package:flutter/material.dart';

class SuperAdminSheetHeader extends StatelessWidget {
  final String title;

  const SuperAdminSheetHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    // Header modal dipakai ulang untuk beberapa sheet super admin.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
