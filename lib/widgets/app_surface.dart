import 'package:flutter/material.dart';

class AppSurface extends StatelessWidget {
  const AppSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
    if (semanticLabel == null) return card;
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      container: true,
      child: card,
    );
  }
}
