import 'package:flutter/material.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';

class EditProfilPage extends StatefulWidget {
  const EditProfilPage({super.key});

  @override
  State<EditProfilPage> createState() => _EditProfilPageState();
}

class _EditProfilPageState extends State<EditProfilPage> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _noHpController = TextEditingController();
  final _asalInstansiController = TextEditingController();
  final _nimController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _muatProfil();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _noHpController.dispose();
    _asalInstansiController.dispose();
    _nimController.dispose();
    super.dispose();
  }

  Future<void> _muatProfil() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final profile = await supabase.from('profiles').select().eq('id', userId).single();

      _namaController.text = profile['nama_lengkap'] ?? '';
      _noHpController.text = profile['no_hp'] ?? '';
      _asalInstansiController.text = profile['asal_instansi'] ?? '';
      _nimController.text = profile['nim'] ?? '';
    } catch (e) {
      debugPrint('Gagal muat profil: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('profiles').update({
        'nama_lengkap': _namaController.text.trim(),
        'no_hp': _noHpController.text.trim(),
        'asal_instansi': _asalInstansiController.text.trim(),
        'nim': _nimController.text.trim(),
      }).eq('id', userId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui'), backgroundColor: AppColors.tertiaryContainer),
      );
      Navigator.of(context).pop(true); // true = ada perubahan, biar profil tab refresh
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profil'),
        foregroundColor: context.appColors.onSurface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _namaController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Nama tidak boleh kosong' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nimController,
                    decoration: const InputDecoration(
                      labelText: 'NIM / NISN (opsional)',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _asalInstansiController,
                    decoration: const InputDecoration(
                      labelText: 'Asal Instansi / Kampus',
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noHpController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nomor HP',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _simpan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.appColors.primary,
                      foregroundColor: context.appColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: context.appColors.onPrimary),
                          )
                        : const Text('Simpan Perubahan'),
                  ),
                ],
              ),
            ),
    );
  }
}