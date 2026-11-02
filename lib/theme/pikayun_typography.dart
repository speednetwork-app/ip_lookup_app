import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Apple-style semantic type scale. Native Apple fonts are never redistributed.
/// Text remains scalable by the system's MediaQuery.textScaler.
abstract final class PikayunTypography {
  static TextTheme build(TextTheme base, TargetPlatform platform) {
    final apple = !kIsWeb &&
        (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS);
    TextStyle role(TextStyle? source, double size,
        {FontWeight weight = FontWeight.w400, bool display = false}) {
      return (source ?? const TextStyle()).copyWith(
        fontFamily: apple
            ? (display ? 'CupertinoSystemDisplay' : 'CupertinoSystemText')
            : base.bodyMedium?.fontFamily,
        fontFamilyFallback: apple
            ? const ['PingFang SC', 'PingFang TC']
            : const ['Noto Sans SC', 'Microsoft YaHei', 'sans-serif'],
        fontSize: size,
        fontWeight: weight,
        letterSpacing: 0,
        height: size >= 20 ? 1.2 : 1.4,
      );
    }

    return base.copyWith(
      displayLarge:
          role(base.displayLarge, 40, weight: FontWeight.w600, display: true),
      displayMedium:
          role(base.displayMedium, 36, weight: FontWeight.w600, display: true),
      displaySmall:
          role(base.displaySmall, 34, weight: FontWeight.w600, display: true),
      headlineLarge:
          role(base.headlineLarge, 34, weight: FontWeight.w700, display: true),
      headlineMedium:
          role(base.headlineMedium, 28, weight: FontWeight.w600, display: true),
      headlineSmall:
          role(base.headlineSmall, 22, weight: FontWeight.w600, display: true),
      titleLarge:
          role(base.titleLarge, 22, weight: FontWeight.w600, display: true),
      titleMedium: role(base.titleMedium, 17, weight: FontWeight.w600),
      titleSmall: role(base.titleSmall, 15, weight: FontWeight.w600),
      bodyLarge: role(base.bodyLarge, 17),
      bodyMedium: role(base.bodyMedium, 15),
      bodySmall: role(base.bodySmall, 13),
      labelLarge: role(base.labelLarge, 17, weight: FontWeight.w600),
      labelMedium: role(base.labelMedium, 12, weight: FontWeight.w500),
      labelSmall: role(base.labelSmall, 11, weight: FontWeight.w500),
    );
  }
}
