import '../widgets/glass_bottom_navigation.dart';

import 'package:flutter/material.dart';

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
      BerandaTab(onAbsenTap: () => gantiTab(1), isActive: _selectedIndex == 0),
      AbsenTab(isActive: _selectedIndex == 1),
      RiwayatTab(isActive: _selectedIndex == 2),
      const ProfilTab(),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: GlassBottomNavigation(
        selectedIndex: _selectedIndex,
        onSelected: gantiTab,
      ),
    );
  }
}
