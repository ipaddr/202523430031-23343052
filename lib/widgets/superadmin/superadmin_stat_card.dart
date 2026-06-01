import 'package:flutter/material.dart';

import 'package:gamezone/widgets/admin/admin_stat_card.dart';

class SuperAdminStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const SuperAdminStatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return AdminStatCard(
      icon: icon,
      iconColor: iconColor,
      title: label,
      value: value,
    );
  }
}
