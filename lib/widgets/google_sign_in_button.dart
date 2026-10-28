import 'package:flutter/material.dart';

import '../services/app_data.dart';
import '../services/api_client.dart';
import '../services/google_auth.dart';

class GoogleSignInButton extends StatefulWidget {
  final bool enabled;
  final ValueChanged<bool>? onBusyChanged;
  final VoidCallback? onSignedIn;
  final GoogleAuthService? service;
  const GoogleSignInButton({
    super.key,
    this.enabled = true,
    this.onBusyChanged,
    this.onSignedIn,
    this.service,
  });
  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  late final GoogleAuthService _service =
      widget.service ?? GoogleAuthService(appData.api);
  bool _busy = false;

  Future<String?> _confirmPassword(String? error) async {
    if (!mounted) return null;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LinkGoogleAccountDialog(error: error),
    );
  }

  Future<void> _signIn() async {
    setState(() => _busy = true);
    widget.onBusyChanged?.call(true);
    try {
      final success = await _service.signIn(confirmPassword: _confirmPassword);
      if (mounted && success) widget.onSignedIn?.call();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login Google belum berhasil. Silakan coba lagi.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: widget.enabled && !_busy ? _signIn : null,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    icon: _busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Image.asset('assets/images/google_g.png', width: 20, height: 20),
    label: const Text('Lanjutkan dengan Google', textAlign: TextAlign.center),
  );
}

class _LinkGoogleAccountDialog extends StatefulWidget {
  final String? error;
  const _LinkGoogleAccountDialog({this.error});
  @override
  State<_LinkGoogleAccountDialog> createState() =>
      _LinkGoogleAccountDialogState();
}

class _LinkGoogleAccountDialogState extends State<_LinkGoogleAccountDialog> {
  final _controller = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Hubungkan akun presensi'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Email Google ini sudah memiliki akun presensi. Masukkan kata sandi presensi agar tetap memakai akun dan data yang sama.',
            ),
            const SizedBox(height: 16),
            if (widget.error != null)
              Text(
                widget.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            TextFormField(
              controller: _controller,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Kata sandi presensi',
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'Isi kata sandi presensi'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _controller.text);
          }
        },
        child: const Text('Hubungkan dan masuk'),
      ),
    ],
  );
}
