import 'package:flutter/material.dart';

class AppIconTile extends StatelessWidget {
  const AppIconTile({
    required this.icon,
    this.size = 42,
    this.iconSize = 21,
    this.backgroundColor,
    this.foregroundColor,
    super.key,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? scheme.primaryContainer,
          borderRadius: BorderRadius.circular(size * .3),
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: foregroundColor ?? scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
