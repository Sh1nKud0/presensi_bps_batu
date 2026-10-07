import 'package:flutter/material.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';
import '../login_page.dart';
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
      final userId = supabase.auth.currentUser!.id;
      final profile = await supabase.from('profiles').select().eq('id', userId).single();

      final absensi = await supabase.from('absensi').select().eq('user_id', userId).not('jam_masuk', 'is', null);
      final izin = await supabase.from('izin').select().eq('user_id', userId).eq('status_persetujuan', 'disetujui');

      setState(() {
        _nama = profile['nama_lengkap'] ?? '-';
        _asalInstansi = profile['asal_instansi'] ?? '-';
        _isAdmin = profile['role'] == 'admin';
        _totalHadir = (absensi as List).length;
        _totalIzin = (izin as List).length;
      });
    } catch (e) {
      debugPrint('Gagal muat profil: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceVariant),
            ),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.secondaryContainer,
                  ),
                  child: Icon(Icons.person, size: 44, color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                Text(_nama, style: AppText.headlineSm),
                const SizedBox(height: 4),
                Text(_isAdmin ? 'Admin / Pembimbing' : 'Peserta Magang', style: AppText.bodyMd.copyWith(color: AppColors.secondary)),
                if (_asalInstansi.isNotEmpty && _asalInstansi != '-') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.business, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(_asalInstansi, style: AppText.labelMd),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Statistik bento
          Row(
            children: [
              Expanded(
                child: _statKartu(
                  icon: Icons.check_circle,
                  iconColor: AppColors.tertiaryContainer,
                  label: 'Hadir',
                  value: _totalHadir,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statKartu(
                  icon: Icons.pending_actions,
                  iconColor: AppColors.secondary,
                  label: 'Izin/Sakit',
                  value: _totalIzin,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Menu pengaturan
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _menuHeader('AKTIVITAS'),
                _menuItem(
                  icon: Icons.event_busy,
                  label: 'Izin / Sakit',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const IzinPage())),
                ),
                _menuItem(
                  icon: Icons.history_toggle_off,
                  label: 'Absen Susulan',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AbsenSusulanPage())),
                ),
                if (_isAdmin)
                  _menuItem(
                    icon: Icons.admin_panel_settings,
                    label: 'Dashboard Admin',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AdminDashboardPage())),
                  ),
                _menuHeader('PENGATURAN AKUN'),
                _menuItem(
                  icon: Icons.edit,
                  label: 'Edit Profil',
                  onTap: () async {
                    final berubah = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (context) => const EditProfilPage()),
                    );
                    if (berubah == true) _muatProfil();
                  },
                ),
                _menuItem(
                  icon: Icons.lock,
                  label: 'Keamanan',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const GantiPasswordPage()),
                  ),
                ),
                _menuItem(icon: Icons.info, label: 'Tentang Aplikasi', onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Presensi BPS Kota Batu',
                    applicationVersion: '1.0.0',
                  );
                }),
                _menuItem(
                  icon: Icons.logout,
                  label: 'Keluar',
                  color: AppColors.error,
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

  Widget _statKartu({required IconData icon, required Color iconColor, required String label, required int value}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 6),
              Text(label, style: AppText.labelMd),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$value', style: AppText.displayLg),
              const SizedBox(width: 6),
              Text('Hari', style: AppText.bodyMd.copyWith(color: AppColors.secondary)),
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
      color: AppColors.surfaceContainerLow,
      child: Text(text, style: AppText.labelMd.copyWith(color: AppColors.secondary)),
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
          border: isLast ? null : Border(bottom: BorderSide(color: AppColors.surfaceVariant)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color ?? AppColors.primary),
                const SizedBox(width: 16),
                Text(label, style: AppText.bodyLg.copyWith(color: color ?? AppColors.onSurface)),
              ],
            ),
            if (color == null) Icon(Icons.chevron_right, color: AppColors.outlineVariant),
          ],
        ),
      ),
    );
  }
}