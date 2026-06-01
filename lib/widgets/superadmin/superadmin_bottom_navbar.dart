import 'package:flutter/material.dart';

class SuperAdminNavItem extends StatelessWidget {
  final bool isActive;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const SuperAdminNavItem({
    super.key,
    required this.isActive,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Item navigasi bawah dengan state aktif dan efek gradient.
    final Color textColor = isActive
        ? const Color(0xFF22D3EE)
        : const Color(0xFF64748B);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 85,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isActive
                ? Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF22D3EE), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  )
                : Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(color: Colors.transparent),
                    child: Icon(icon, color: const Color(0xFF64748B), size: 22),
                  ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 9.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SuperAdminBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const SuperAdminBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final double systemBottomInset = MediaQuery.of(context).padding.bottom;

    // Area background navbar.
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF090D20),
        border: Border(top: BorderSide(color: Color(0xFF141C38), width: 1.2)),
      ),
      child: Padding(
        // Menyesuaikan tinggi dengan system navigation inset.
        padding: EdgeInsets.only(bottom: systemBottomInset),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Center(
            // Konten utama navbar.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SizedBox(
                height: 82,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      SuperAdminNavItem(
                        isActive: currentIndex == 0,
                        icon: Icons.home_rounded,
                        label: 'BERANDA',
                        onTap: () => onTabSelected(0),
                      ),
                      SuperAdminNavItem(
                        isActive: currentIndex == 1,
                        icon: Icons.help_outline_rounded,
                        label: 'VERIFIKASI',
                        onTap: () => onTabSelected(1),
                      ),
                      SuperAdminNavItem(
                        isActive: currentIndex == 2,
                        icon: Icons.people_outline_rounded,
                        label: 'USER',
                        onTap: () => onTabSelected(2),
                      ),
                      SuperAdminNavItem(
                        isActive: currentIndex == 3,
                        icon: Icons.person_rounded,
                        label: 'PROFIL',
                        onTap: () => onTabSelected(3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
