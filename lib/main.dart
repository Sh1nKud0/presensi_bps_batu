import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/login_page.dart';
import 'pages/main_shell.dart';
import 'notification_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://aoahoufvxreyvirpeeva.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFvYWhvdWZ2eHJleXZpcnBlZXZhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg1NDYzNTksImV4cCI6MjEwNDEyMjM1OX0.mtUhiw03gxTyI8bYvXXG_OmAVNULWmRq5ZW6qKo4yTk',
  );

  await NotificationService.instance.init();
  await appThemeController.load();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeController,
      builder: (context, mode, _) => MaterialApp(
        title: 'Presensi BPS Kota Batu',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        darkTheme: buildAppTheme(brightness: Brightness.dark),
        themeMode: mode,
        scrollBehavior: const _NoStretchScrollBehavior(),
        home: const AuthGate(),
      ),
    );
  }
}

// Widget ini mengecek: kalau user sudah login -> MainShell, kalau belum -> LoginPage
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;
    return session != null ? const MainShell() : const LoginPage();
  }
}

// Matikan efek "stretch" saat overscroll (bawaan Material 3), ganti ke glow halus biasa
class _NoStretchScrollBehavior extends MaterialScrollBehavior {
  const _NoStretchScrollBehavior();

  @override
  AndroidOverscrollIndicator? get androidOverscrollIndicator =>
      AndroidOverscrollIndicator.glow;

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child; // hilangkan efek overscroll sama sekali
  }
}
