import '../widgets/glass_bottom_navigation.dart';

import 'package:flutter/material.dart';

import '../main.dart';
import 'admin_dashboard_page.dart';
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
  bool? _isAdmin;

  @override
  void initState() {
    super.initState();
    _muatRole();
  }

  Future<void> _muatRole() async {
    try {
      final profile = await appData.profile();
      if (mounted) setState(() => _isAdmin = profile['role'] == 'admin');
    } catch (e) {
      debugPrint('Gagal memuat role pengguna: $e');
      if (mounted) setState(() => _isAdmin = false);
    }
  }

  // Dipanggil dari tab lain (misal tombol "Absen Sekarang" di Beranda)
  void gantiTab(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdmin == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isAdmin!) {
      final pages = [const AdminDashboardPage(), const ProfilTab()];
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _selectedIndex, children: pages),
        ),
        bottomNavigationBar: GlassBottomNavigation(
          isAdmin: true,
          selectedIndex: _selectedIndex,
          onSelected: gantiTab,
        ),
      );
    }

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
        isAdmin: false,
        selectedIndex: _selectedIndex,
        onSelected: gantiTab,
      ),
    );
  }
}
