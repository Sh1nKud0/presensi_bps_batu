import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass_surface.dart';

class GlassBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool isAdmin;
  const GlassBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    final participantItems = [
      (_NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'Beranda',
      )),
      (_NavItem(
        icon: Icons.fingerprint,
        activeIcon: Icons.fingerprint,
        label: 'Absen',
      )),
      (_NavItem(
        icon: Icons.history,
        activeIcon: Icons.history,
        label: 'Riwayat',
      )),
      (_NavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'Profil',
      )),
    ];
    final items = isAdmin
        ? [participantItems[0], participantItems[3]]
        : participantItems;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: GlassSurface(
              radius: 32,
              blur: true,
              padding: const EdgeInsets.all(6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final labelWidth =
                      ((constraints.maxWidth / items.length) - 10).clamp(
                        1.0,
                        double.infinity,
                      );
                  var navHeight = 62.0;
                  for (final item in items) {
                    final painter = TextPainter(
                      text: TextSpan(
                        text: item.label,
                        style: AppText.labelMd.copyWith(
                          letterSpacing: 0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                    )..layout(maxWidth: labelWidth);
                    final needed = painter.height + 23 + 4 + 16;
                    if (needed > navHeight) navHeight = needed;
                    painter.dispose();
                  }
                  return Row(
                    children: List.generate(items.length, (index) {
                      final item = items[index];
                      final selected = index == selectedIndex;
                      return Expanded(
                        child: Semantics(
                          selected: selected,
                          button: true,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(26),
                              onTap: () => onSelected(index),
                              child: AnimatedContainer(
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 200),
                                height: navHeight,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: selected
                                      ? LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            context.appColors.primary
                                                .withValues(alpha: 0.18),
                                            context.appColors.primary
                                                .withValues(alpha: 0.06),
                                          ],
                                        )
                                      : null,
                                  borderRadius: BorderRadius.circular(26),
                                  border: Border.all(
                                    color: selected
                                        ? context.appColors.primary.withValues(
                                            alpha: 0.10,
                                          )
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      selected ? item.activeIcon : item.icon,
                                      color: selected
                                          ? context.appColors.primary
                                          : context.appColors.secondary,
                                      size: 23,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.label,
                                      textAlign: TextAlign.center,
                                      style: AppText.labelMd.copyWith(
                                        letterSpacing: 0,
                                        color: selected
                                            ? context.appColors.primary
                                            : context.appColors.secondary,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  _NavItem({required this.icon, required this.activeIcon, required this.label});
}
