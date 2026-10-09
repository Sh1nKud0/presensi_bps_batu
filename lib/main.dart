import 'package:flutter/material.dart';

import 'pages/login_page.dart';
import 'pages/main_shell.dart';
import 'notification_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/glass_surface.dart';
import 'services/app_data.dart';
export 'services/app_data.dart' show appData;

final appNavigatorKey = GlobalKey<NavigatorState>();

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeController,
      builder: (context, mode, _) => MaterialApp(
        navigatorKey: appNavigatorKey,
        title: 'Presensi BPS Kota Batu',
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

// Widget ini mengecek: kalau user sudah login -> MainShell, kalau belum -> LoginPage
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<void> _restore;
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
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
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
