import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass_surface.dart';
import 'app_logo.dart';

/// A single, finite intro; session restoration runs independently in AuthGate.
class AppSplashScreen extends StatefulWidget {
  final VoidCallback onIntroCompleted;
  const AppSplashScreen({super.key, required this.onIntroCompleted});

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2200),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onIntroCompleted();
      });
  late final CurvedAnimation _intro = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.45, curve: Curves.easeOutCubic),
  );
  late final CurvedAnimation _textIntro = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.22, 0.7, curve: Curves.easeOutCubic),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_controller.isCompleted) _controller.value = 1;
      });
    } else if (_controller.status == AnimationStatus.dismissed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _textIntro.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 48).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: FadeTransition(
                  opacity: _intro,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.88, end: 1).animate(_intro),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                colors.primary.withValues(alpha: 0.12),
                                colors.primary.withValues(alpha: 0),
                              ],
                            ),
                          ),
                          child: GlassSurface(
                            width: 148,
                            height: 148,
                            radius: 40,
                            blur: true,
                            padding: const EdgeInsets.all(24),
                            child: const AppLogo(),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FadeTransition(
                          opacity: _textIntro,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.18),
                              end: Offset.zero,
                            ).animate(_textIntro),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Presensi Magang',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'BPS Kota Batu',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: 104,
                          child: LinearProgressIndicator(
                            minHeight: 3,
                            borderRadius: BorderRadius.circular(4),
                            semanticsLabel: 'Menyiapkan aplikasi',
                            value: MediaQuery.disableAnimationsOf(context)
                                ? 1
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Menyiapkan aplikasi…',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
