import 'dart:ui';

import 'package:flutter/material.dart';

/// Static color fields give translucent surfaces depth without animated shaders.
class GlassBackground extends StatelessWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? const [
                          Color(0xFF101216),
                          Color(0xFF15181D),
                          Color(0xFF1B2027),
                        ]
                      : const [
                          Color(0xFFF8FAFC),
                          Color(0xFFF4F6F9),
                          Color(0xFFEEF2F6),
                        ],
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.95, -0.8),
                    radius: 1.2,
                    colors: [
                      (dark ? const Color(0xFF526174) : const Color(0xFFCBD7E8))
                          .withValues(alpha: dark ? 0.10 : 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Blur is reserved for floating controls; scrolling cards use a lighter tint.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double? width;
  final double? height;
  final bool blur;
  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = 24,
    this.width,
    this.height,
    this.blur = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final borderRadius = BorderRadius.circular(radius);
    final tint = dark ? const Color(0xFF242930) : Colors.white;
    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tint.withValues(
              alpha: highContrast
                  ? 1
                  : dark
                  ? 0.84
                  : 0.62,
            ),
            tint.withValues(
              alpha: highContrast
                  ? 1
                  : dark
                  ? 0.68
                  : 0.32,
            ),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0.22 : 0.85),
        ),
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
    if (blur && !highContrast) {
      content = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: content,
      );
    }
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101820)
                .withValues(alpha: dark ? 0.18 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: borderRadius, child: content),
    );
  }
}
