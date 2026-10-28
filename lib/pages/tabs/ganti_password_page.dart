import 'package:flutter/material.dart';

import '../../main.dart';
import '../../theme/app_theme.dart';

class GantiPasswordPage extends StatefulWidget {
  const GantiPasswordPage({super.key});

  @override
  State<GantiPasswordPage> createState() => _GantiPasswordPageState();
}

class _GantiPasswordPageState extends State<GantiPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordLamaController = TextEditingController();
  final _passwordBaruController = TextEditingController();
  final _konfirmasiController = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  bool get _hasPassword => appData.api.user?['has_password'] != false;

  @override
  void dispose() {
    _passwordLamaController.dispose();
    _passwordBaruController.dispose();
    _konfirmasiController.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await appData.changePassword(
        _hasPassword ? _passwordLamaController.text : null,
        _passwordBaruController.text,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keamanan'),
        foregroundColor: context.appColors.onSurface,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _hasPassword ? 'Ganti Password' : 'Buat Password',
              style: AppText.headlineSm,
            ),
            const SizedBox(height: 4),
            Text('Password baru minimal 8 karakter.', style: AppText.bodyMd),
            const SizedBox(height: 24),
            if (!_hasPassword)
              const Text(
                'Jika sesi sudah lama, masuk kembali dengan Google sebelum membuat password.',
              ),
            if (_hasPassword) ...[
              TextFormField(
                controller: _passwordLamaController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password saat ini',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Isi password saat ini' : null,
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _passwordBaruController,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password Baru',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Password tidak boleh kosong';
                }
                if (v.length < 8) return 'Minimal 8 karakter';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _konfirmasiController,
              obscureText: _obscure,
              decoration: const InputDecoration(
                labelText: 'Konfirmasi Password Baru',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (v) {
                if (v != _passwordBaruController.text) {
                  return 'Password tidak cocok';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _simpan,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appColors.primary,
                foregroundColor: context.appColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.appColors.onPrimary,
                      ),
                    )
                  : const Text('Ubah Password'),
            ),
          ],
        ),
      ),
    );
  }
}
