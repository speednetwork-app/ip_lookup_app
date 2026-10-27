import 'package:flutter/material.dart';

class AppPageTitle extends StatelessWidget {
  const AppPageTitle({
    required this.title,
    required this.icon,
    this.subtitle,
    this.brand = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool brand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final iconColor = brand ? Colors.white : scheme.primary;
    final iconBackground = brand
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, const Color(0xFF24A7D8)],
          )
        : LinearGradient(
            colors: [scheme.primaryContainer, scheme.primaryContainer],
          );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Container(
            width: brand ? 38 : 34,
            height: brand ? 38 : 34,
            decoration: BoxDecoration(
              gradient: iconBackground,
              borderRadius: BorderRadius.circular(brand ? 12 : 11),
              boxShadow: brand
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: .2),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Icon(icon, color: iconColor, size: brand ? 22 : 19),
          ),
        ),
        const SizedBox(width: 11),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge,
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
