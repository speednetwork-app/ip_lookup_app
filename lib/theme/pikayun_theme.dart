import 'package:flutter/material.dart';

@immutable
class PikayunColors extends ThemeExtension<PikayunColors> {
  const PikayunColors({
    required this.canvasStart,
    required this.canvasEnd,
    required this.signalGlow,
    required this.signalGrid,
    required this.heroStart,
    required this.heroEnd,
    required this.heroAccent,
    required this.brandSurface,
    required this.onBrandSurface,
    required this.onBrandSurfaceMuted,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.separator,
  });

  final Color canvasStart;
  final Color canvasEnd;
  final Color signalGlow;
  final Color signalGrid;
  final Color heroStart;
  final Color heroEnd;
  final Color heroAccent;
  final Color brandSurface;
  final Color onBrandSurface;
  final Color onBrandSurfaceMuted;
  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color separator;

  static const light = PikayunColors(
    canvasStart: Color(0xFFF0F6FC),
    canvasEnd: Color(0xFFF7F9FC),
    signalGlow: Color(0xFF3A9BD8),
    signalGrid: Color(0xFF285F96),
    heroStart: Color(0xFF0C4F88),
    heroEnd: Color(0xFF0877BA),
    heroAccent: Color(0xFF42B9F0),
    brandSurface: Color(0xFF164D73),
    onBrandSurface: Color(0xFFFFFFFF),
    onBrandSurfaceMuted: Color(0xFFC9DCE8),
    success: Color(0xFF087A61),
    successContainer: Color(0xFFDDF5EC),
    warning: Color(0xFF936000),
    warningContainer: Color(0xFFFFEEC5),
    separator: Color(0x1F1B2833),
  );

  static const dark = PikayunColors(
    canvasStart: Color(0xFF0B1623),
    canvasEnd: Color(0xFF101925),
    signalGlow: Color(0xFF3B9DD6),
    signalGrid: Color(0xFF79B4F2),
    heroStart: Color(0xFF071D30),
    heroEnd: Color(0xFF0B426D),
    heroAccent: Color(0xFF3A9DD8),
    brandSurface: Color(0xFF123B57),
    onBrandSurface: Color(0xFFF7FBFF),
    onBrandSurfaceMuted: Color(0xFFBBD1DE),
    success: Color(0xFF61D6B4),
    successContainer: Color(0xFF123E35),
    warning: Color(0xFFFFC864),
    warningContainer: Color(0xFF493710),
    separator: Color(0x29FFFFFF),
  );

  @override
  PikayunColors copyWith({
    Color? canvasStart,
    Color? canvasEnd,
    Color? signalGlow,
    Color? signalGrid,
    Color? heroStart,
    Color? heroEnd,
    Color? heroAccent,
    Color? brandSurface,
    Color? onBrandSurface,
    Color? onBrandSurfaceMuted,
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? separator,
  }) {
    return PikayunColors(
      canvasStart: canvasStart ?? this.canvasStart,
      canvasEnd: canvasEnd ?? this.canvasEnd,
      signalGlow: signalGlow ?? this.signalGlow,
      signalGrid: signalGrid ?? this.signalGrid,
      heroStart: heroStart ?? this.heroStart,
      heroEnd: heroEnd ?? this.heroEnd,
      heroAccent: heroAccent ?? this.heroAccent,
      brandSurface: brandSurface ?? this.brandSurface,
      onBrandSurface: onBrandSurface ?? this.onBrandSurface,
      onBrandSurfaceMuted: onBrandSurfaceMuted ?? this.onBrandSurfaceMuted,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      separator: separator ?? this.separator,
    );
  }

  @override
  PikayunColors lerp(PikayunColors? other, double t) {
    if (other == null) return this;
    return PikayunColors(
      canvasStart: Color.lerp(canvasStart, other.canvasStart, t)!,
      canvasEnd: Color.lerp(canvasEnd, other.canvasEnd, t)!,
      signalGlow: Color.lerp(signalGlow, other.signalGlow, t)!,
      signalGrid: Color.lerp(signalGrid, other.signalGrid, t)!,
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
      heroAccent: Color.lerp(heroAccent, other.heroAccent, t)!,
      brandSurface: Color.lerp(brandSurface, other.brandSurface, t)!,
      onBrandSurface: Color.lerp(onBrandSurface, other.onBrandSurface, t)!,
      onBrandSurfaceMuted:
          Color.lerp(onBrandSurfaceMuted, other.onBrandSurfaceMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
    );
  }
}

extension PikayunThemeContext on BuildContext {
  PikayunColors get pikayunColors =>
      Theme.of(this).extension<PikayunColors>() ?? PikayunColors.light;
}

class PikayunTheme {
  const PikayunTheme._();

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF246B9B),
      brightness: brightness,
      surface: isDark ? const Color(0xFF101925) : const Color(0xFFF0F6FC),
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
    );
    final textTheme = base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor:
          isDark ? PikayunColors.dark.canvasEnd : PikayunColors.light.canvasEnd,
      extensions: [isDark ? PikayunColors.dark : PikayunColors.light],
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? PikayunColors.dark.canvasStart : PikayunColors.light.canvasStart,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isDark ? const Color(0xFF182434) : const Color(0xFFFCFEFF),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .7)),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF162231) : const Color(0xFFF8FBFE),
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: isDark
            ? PikayunColors.dark.separator
            : PikayunColors.light.separator,
        thickness: .5,
        space: 1,
      ),
    );
  }
}
