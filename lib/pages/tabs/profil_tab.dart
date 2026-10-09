import '../../widgets/adaptive_tiles.dart';
import '../../widgets/glass_surface.dart';
import '../pembatalan_pulang_page.dart';

import 'package:flutter/material.dart';

import '../../main.dart';
import '../../theme/app_theme.dart';
import '../../widgets/theme_switch_tile.dart';
import '../izin_page.dart';
import 'absen_susulan_page.dart';
import '../admin_dashboard_page.dart';
import 'edit_profil_page.dart';
import 'ganti_password_page.dart';

class ProfilTab extends StatefulWidget {
  const ProfilTab({super.key});

  @override
  State<ProfilTab> createState() => _ProfilTabState();
}

class _ProfilTabState extends State<ProfilTab> {
  bool _loading = true;
  String _nama = '';
  String _asalInstansi = '';
  bool _isAdmin = false;
  int _totalHadir = 0;
  int _totalIzin = 0;

  @override
  void initState() {
    super.initState();
    _muatProfil();
  }

  Future<void> _muatProfil() async {
    setState(() => _loading = true);
    try {
      final profile = await appData.profile();

      final counts = await appData.api.json('GET', '/api/me/statistics');
      if (!mounted) return;

      setState(() {
        _nama = profile['nama_lengkap'] ?? '-';
        _asalInstansi = profile['asal_instansi'] ?? '-';
        _isAdmin = profile['role'] == 'admin';
        _totalHadir = counts['hadir'] as int;
        _totalIzin = counts['izin'] as int;
      });
    } catch (e) {
      debugPrint('Gagal muat profil: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    try {
      await appData.logout();
    } catch (error) {
      if (mounted && appData.loggedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout belum berhasil: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _muatProfil,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Profil', style: AppText.headlineMdMobile),
          const SizedBox(height: 16),

          // Header profil
          GlassSurface(
            padding: const EdgeInsets.all(20),
            radius: 24,
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.appColors.secondaryContainer,
                  ),
                  child: Icon(
                    Icons.person,
                    size: 44,
                    color: context.appColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _nama,
                  textAlign: TextAlign.center,
                  style: AppText.headlineSm,
                ),
                const SizedBox(height: 4),
                Text(
                  _isAdmin ? 'Admin / Pembimbing' : 'Peserta Magang',
                  style: AppText.bodyMd.copyWith(
                    color: context.appColors.secondary,
                  ),
                ),
                if (_asalInstansi.isNotEmpty && _asalInstansi != '-') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: context.appColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.business,
                          size: 16,
                          color: context.appColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(_asalInstansi, style: AppText.labelMd),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Statistik bento
          AdaptiveTiles(
            minTileWidth: 140,
            children: [
              _statKartu(
                icon: Icons.check_circle,
                iconColor: context.appColors.tertiaryContainer,
                label: 'Hadir',
                value: _totalHadir,
              ),
              _statKartu(
                icon: Icons.pending_actions,
                iconColor: context.appColors.secondary,
                label: 'Izin/Sakit',
                value: _totalIzin,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Menu pengaturan
          GlassSurface(
            radius: 24,
            child: Column(
              children: [
                _menuHeader('AKTIVITAS'),
                _menuItem(
                  icon: Icons.event_busy,
                  label: 'Izin / Sakit',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const IzinPage()),
                  ),
                ),
                _menuItem(
                  icon: Icons.history_toggle_off,
                  label: 'Absen Susulan',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AbsenSusulanPage(),
                    ),
                  ),
                ),
                _menuItem(
                  icon: Icons.undo,
                  label: 'Pembatalan Absen Pulang',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PembatalanPulangPage(isAdmin: _isAdmin),
                    ),
                  ),
                ),
                if (_isAdmin)
                  _menuItem(
                    icon: Icons.admin_panel_settings,
                    label: 'Dashboard Admin',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AdminDashboardPage(),
                      ),
                    ),
                  ),
                _menuHeader('TAMPILAN'),
                const ThemeSwitchTile(),
                _menuHeader('PENGATURAN AKUN'),
                _menuItem(
                  icon: Icons.edit,
                  label: 'Edit Profil',
                  onTap: () async {
                    final berubah = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (context) => const EditProfilPage(),
                      ),
                    );
                    if (berubah == true) _muatProfil();
                  },
                ),
                _menuItem(
                  icon: Icons.lock,
                  label: 'Keamanan',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const GantiPasswordPage(),
                    ),
                  ),
                ),
                _menuItem(
                  icon: Icons.info,
                  label: 'Tentang Aplikasi',
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'Presensi BPS Kota Batu',
                      applicationVersion: '1.0.0',
                    );
                  },
                ),
                _menuItem(
                  icon: Icons.logout,
                  label: 'Keluar',
                  color: context.appColors.error,
                  onTap: _logout,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _statKartu({
    required IconData icon,
    required Color iconColor,
    required String label,
    required int value,
  }) {
    return GlassSurface(
      padding: const EdgeInsets.all(16),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 6),
              Expanded(child: Text(label, style: AppText.labelMd)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('$value', style: AppText.displayLg),
              const SizedBox(width: 6),
              Text(
                'Hari',
                style: AppText.bodyMd.copyWith(
                  color: context.appColors.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _menuHeader(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: context.appColors.surfaceContainerLow,
      child: Text(
        text,
        style: AppText.labelMd.copyWith(color: context.appColors.secondary),
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(color: context.appColors.surfaceVariant),
                ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(icon, color: color ?? context.appColors.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: AppText.bodyLg.copyWith(
                        color: color ?? context.appColors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (color == null)
              Icon(
                Icons.chevron_right,
                color: context.appColors.outlineVariant,
              ),
          ],
        ),
      ),
    );
  }
}
