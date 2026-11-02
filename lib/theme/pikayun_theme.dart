import 'package:flutter/material.dart';
import 'pikayun_typography.dart';

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
    canvasStart: Color(0xFFF8F6EF),
    canvasEnd: Color(0xFFF8F6EF),
    signalGlow: Color(0xFFFFD43B),
    signalGrid: Color(0xFF705716),
    heroStart: Color(0xFF252822),
    heroEnd: Color(0xFF252822),
    heroAccent: Color(0xFFFFD43B),
    brandSurface: Color(0xFFFFD43B),
    onBrandSurface: Color(0xFF27251F),
    onBrandSurfaceMuted: Color(0xFF705716),
    success: Color(0xFF087A61),
    successContainer: Color(0xFFDDF5EC),
    warning: Color(0xFF936000),
    warningContainer: Color(0xFFFFEEC5),
    separator: Color(0xFFE5DFCF),
  );

  static const dark = PikayunColors(
    canvasStart: Color(0xFF181917),
    canvasEnd: Color(0xFF181917),
    signalGlow: Color(0xFFFFD43B),
    signalGrid: Color(0xFFE4CD84),
    heroStart: Color(0xFF262923),
    heroEnd: Color(0xFF262923),
    heroAccent: Color(0xFFFFD43B),
    brandSurface: Color(0xFFFFD43B),
    onBrandSurface: Color(0xFF27251F),
    onBrandSurfaceMuted: Color(0xFF705716),
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
      seedColor: const Color(0xFFFFD43B),
      brightness: brightness,
    ).copyWith(
      primary: isDark ? const Color(0xFFFFDF70) : const Color(0xFF705716),
      onPrimary: isDark ? const Color(0xFF27251F) : Colors.white,
      primaryContainer:
          isDark ? const Color(0xFF494126) : const Color(0xFFFFF0AC),
      onPrimaryContainer:
          isDark ? const Color(0xFFFFE793) : const Color(0xFF302D26),
      surface: isDark ? const Color(0xFF262723) : Colors.white,
      onSurface: isDark ? const Color(0xFFFAF8F1) : const Color(0xFF242321),
      onSurfaceVariant:
          isDark ? const Color(0xFFC6C1B2) : const Color(0xFF6D695E),
      surfaceContainerLowest: isDark ? const Color(0xFF20211E) : Colors.white,
      surfaceContainerLow:
          isDark ? const Color(0xFF2C2E28) : const Color(0xFFF3F0E6),
      surfaceContainer:
          isDark ? const Color(0xFF30322B) : const Color(0xFFF1EFE5),
      surfaceContainerHighest:
          isDark ? const Color(0xFF3B3E35) : const Color(0xFFECE6D7),
      outlineVariant:
          isDark ? const Color(0xFF484B40) : const Color(0xFFE5DFCF),
      error: isDark ? const Color(0xFFFFAAA1) : const Color(0xFFB93B41),
      errorContainer:
          isDark ? const Color(0xFF4B2628) : const Color(0xFFFCEDEE),
      onErrorContainer:
          isDark ? const Color(0xFFFFDAD6) : const Color(0xFF872A30),
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
    );
    final textTheme = PikayunTypography.build(base.textTheme, base.platform);

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme:
          PikayunTypography.build(base.primaryTextTheme, base.platform),
      scaffoldBackgroundColor:
          isDark ? PikayunColors.dark.canvasEnd : PikayunColors.light.canvasEnd,
      extensions: [isDark ? PikayunColors.dark : PikayunColors.light],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        titleSpacing: 16,
        toolbarHeight: 72,
        backgroundColor: isDark
            ? PikayunColors.dark.canvasStart
            : PikayunColors.light.canvasStart,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFFD43B),
          foregroundColor: const Color(0xFF27251F),
          minimumSize: const Size(44, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
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
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
              size: 22,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 11,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
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
