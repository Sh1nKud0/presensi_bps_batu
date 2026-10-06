import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

class ThemeSwitchTile extends StatefulWidget {
  const ThemeSwitchTile({super.key});

  @override
  State<ThemeSwitchTile> createState() => _ThemeSwitchTileState();
}

class _ThemeSwitchTileState extends State<ThemeSwitchTile> {
  bool _saving = false;

  Future<void> _changeTheme(bool enabled) async {
    setState(() => _saving = true);
    try {
      await appThemeController.setDarkMode(enabled);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan pilihan tema. Coba lagi.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeController,
      builder: (context, mode, _) => SwitchListTile.adaptive(
        secondary: Icon(
          mode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
          color: context.appColors.primary,
        ),
        title: const Text('Mode gelap'),
        subtitle: Text(mode == ThemeMode.dark ? 'Aktif' : 'Nonaktif'),
        value: mode == ThemeMode.dark,
        onChanged: _saving ? null : _changeTheme,
      ),
    );
  }
}
