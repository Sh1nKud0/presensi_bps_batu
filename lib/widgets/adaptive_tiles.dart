import 'package:flutter/material.dart';

/// Natural-height tiles wrap into fewer columns when text needs more space.
class AdaptiveTiles extends StatelessWidget {
  final List<Widget> children;
  final double minTileWidth;
  final double spacing;
  final int maxColumns;
  const AdaptiveTiles({
    super.key,
    required this.children,
    this.minTileWidth = 150,
    this.spacing = 12,
    this.maxColumns = 2,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns =
          ((constraints.maxWidth + spacing) / (minTileWidth * scale + spacing))
              .floor()
              .clamp(1, maxColumns);
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: children
            .map((child) => SizedBox(width: width, child: child))
            .toList(),
      );
    },
  );
}
