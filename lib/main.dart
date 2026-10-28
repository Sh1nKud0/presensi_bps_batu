import 'package:flutter/material.dart';

import 'pages/login_page.dart';
import 'pages/main_shell.dart';
import 'notification_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/glass_surface.dart';
import 'widgets/app_splash_screen.dart';
import 'services/app_data.dart';
export 'services/app_data.dart' show appData;

final appNavigatorKey = GlobalKey<NavigatorState>();

/// Menyiapkan layanan lokal yang dibutuhkan sebelum widget aplikasi dibuat.
///
/// Inisialisasi binding dilakukan lebih dahulu karena konfigurasi notifikasi
/// dan penyimpanan dapat menggunakan kanal platform sebelum `runApp`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.instance.init();
  await appThemeController.load();
  appData.api.addListener(() {
    if (!appData.loggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!appData.loggedIn) {
          appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
      });
    }
  });

  runApp(const MyApp());
}

/// Root aplikasi yang memasang tema, navigasi awal, dan gerbang autentikasi.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeController,
      builder: (context, mode, _) => MaterialApp(
        navigatorKey: appNavigatorKey,
        title: 'magang presensi bps Batu',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        darkTheme: buildAppTheme(brightness: Brightness.dark),
        themeMode: mode,
        scrollBehavior: const _NoStretchScrollBehavior(),
        builder: (context, child) =>
            GlassBackground(child: child ?? const SizedBox.shrink()),
        home: const AuthGate(),
      ),
    );
  }
}

/// Memulihkan sesi tersimpan sebelum memilih halaman yang dapat diakses.
///
/// Pemeriksaan sesi dipisahkan dari splash screen agar animasi pembuka tidak
/// menjadi syarat untuk memulai pemulihan autentikasi.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<void> _restore;
  bool _introCompleted = false;
  @override
  void initState() {
    super.initState();
    _restore = appData.api.restore();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _restore,
      builder: (context, snapshot) {
        if (!_introCompleted ||
            snapshot.connectionState != ConnectionState.done) {
          return AppSplashScreen(
            onIntroCompleted: () {
              if (mounted) setState(() => _introCompleted = true);
            },
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Server belum dapat dihubungi.'),
                  TextButton(
                    onPressed: () =>
                        setState(() => _restore = appData.api.restore()),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          );
        }
        return ListenableBuilder(
          listenable: appData.api,
          builder: (context, _) =>
              appData.loggedIn ? const MainShell() : const LoginPage(),
        );
      },
    );
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
