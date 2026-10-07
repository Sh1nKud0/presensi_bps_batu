import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'tabs/beranda_tab.dart';
import 'tabs/absen_tab.dart';
import 'tabs/riwayat_tab.dart';
import 'tabs/profil_tab.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  // Dipanggil dari tab lain (misal tombol "Absen Sekarang" di Beranda)
  void gantiTab(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      BerandaTab(onAbsenTap: () => gantiTab(1)),
      const AbsenTab(),
      const RiwayatTab(),
      const ProfilTab(),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      (_NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Beranda')),
      (_NavItem(icon: Icons.fingerprint, activeIcon: Icons.fingerprint, label: 'Absen')),
      (_NavItem(icon: Icons.history, activeIcon: Icons.history, label: 'Riwayat')),
      (_NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profil')),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final selected = index == _selectedIndex;
              return GestureDetector(
                onTap: () => gantiTab(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selected ? item.activeIcon : item.icon,
                        color: selected ? AppColors.primary : AppColors.secondary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: AppText.labelMd.copyWith(
                          color: selected ? AppColors.primary : AppColors.secondary,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  _NavItem({required this.icon, required this.activeIcon, required this.label});
}