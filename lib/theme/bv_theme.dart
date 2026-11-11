import 'package:flutter/material.dart';

class BVColors {
  BVColors._();
  static const blue = Color(0xFF2A3488);
  static const orange = Color(0xFFEF7B22);
  static const slate = Color(0xFF4D4D4D);
  static const ink = Color(0xFF1A1A1A);
  static const surface = Color(0xFFF4F5FA);
  static const blueTint = Color(0xFFE8EAF6);
  static const orangeTint = Color(0xFFFDEBDD);
  static const success = Color(0xFF2E9E5B);
  static const error = Color(0xFFD64545);
  static const divider = Color(0xFFDADDEA);
  static const darkBackground = Color(0xFF0E1024);
  static const darkSurface = Color(0xFF151833);
  static const darkSurfaceHigh = Color(0xFF232748);
  static const darkBlue = Color(0xFFA8B1F5);
  static const darkOrange = Color(0xFFFF9248);
  static const darkText = Color(0xFFE6E7F2);
  static const darkMuted = Color(0xFFB0B4D0);
  static const darkOutline = Color(0xFF3A3F66);
}

const bvLightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: BVColors.blue,
  onPrimary: Colors.white,
  primaryContainer: BVColors.blueTint,
  onPrimaryContainer: BVColors.blue,
  secondary: BVColors.orange,
  onSecondary: BVColors.ink,
  secondaryContainer: BVColors.orangeTint,
  onSecondaryContainer: Color(0xFF7A3A05),
  tertiary: BVColors.success,
  onTertiary: Colors.white,
  error: BVColors.error,
  onError: Colors.white,
  surface: Colors.white,
  onSurface: BVColors.ink,
  onSurfaceVariant: BVColors.slate,
  outline: Color(0xFF7A81A8),
  outlineVariant: BVColors.divider,
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: BVColors.ink,
  onInverseSurface: Colors.white,
  inversePrimary: BVColors.darkBlue,
);

const bvDarkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: BVColors.darkBlue,
  onPrimary: Color(0xFF141A4D),
  primaryContainer: BVColors.blue,
  onPrimaryContainer: Color(0xFFE0E3FF),
  secondary: BVColors.darkOrange,
  onSecondary: Color(0xFF3A1A00),
  secondaryContainer: Color(0xFF5A2E0A),
  onSecondaryContainer: BVColors.orangeTint,
  tertiary: BVColors.success,
  onTertiary: Color(0xFF003919),
  error: Color(0xFFFF8A8A),
  onError: Color(0xFF5A0F0F),
  surface: BVColors.darkSurface,
  onSurface: BVColors.darkText,
  onSurfaceVariant: BVColors.darkMuted,
  outline: Color(0xFF8A8FB5),
  outlineVariant: BVColors.darkOutline,
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: BVColors.darkText,
  onInverseSurface: BVColors.ink,
  inversePrimary: BVColors.blue,
);

@immutable
class StatusStyle {
  const StatusStyle(this.background, this.foreground);
  final Color background;
  final Color foreground;

  static StatusStyle lerp(StatusStyle a, StatusStyle b, double t) => StatusStyle(
        Color.lerp(a.background, b.background, t)!,
        Color.lerp(a.foreground, b.foreground, t)!,
      );
}

@immutable
class BVStatusColors extends ThemeExtension<BVStatusColors> {
  const BVStatusColors({
    required this.pending,
    required this.inProgress,
    required this.success,
    required this.danger,
    required this.neutral,
  });

  final StatusStyle pending;
  final StatusStyle inProgress;
  final StatusStyle success;
  final StatusStyle danger;
  final StatusStyle neutral;

  static const light = BVStatusColors(
    pending: StatusStyle(Color(0xFFFDEBDD), Color(0xFF97480A)),
    inProgress: StatusStyle(Color(0xFFE8EAF6), Color(0xFF2A3488)),
    success: StatusStyle(Color(0xFFE3F4EA), Color(0xFF1F7A45)),
    danger: StatusStyle(Color(0xFFFBE4E4), Color(0xFFB02F2F)),
    neutral: StatusStyle(Color(0xFFECEDF3), Color(0xFF4D4D4D)),
  );

  static const dark = BVStatusColors(
    pending: StatusStyle(Color(0xFF4A2A10), Color(0xFFFFB27A)),
    inProgress: StatusStyle(Color(0xFF262C66), Color(0xFFC3CAFF)),
    success: StatusStyle(Color(0xFF16402B), Color(0xFF7FE3A8)),
    danger: StatusStyle(Color(0xFF5A2020), Color(0xFFFFB0B0)),
    neutral: StatusStyle(Color(0xFF2B2F52), Color(0xFFB0B4D0)),
  );

  @override
  BVStatusColors copyWith({
    StatusStyle? pending,
    StatusStyle? inProgress,
    StatusStyle? success,
    StatusStyle? danger,
    StatusStyle? neutral,
  }) =>
      BVStatusColors(
        pending: pending ?? this.pending,
        inProgress: inProgress ?? this.inProgress,
        success: success ?? this.success,
        danger: danger ?? this.danger,
        neutral: neutral ?? this.neutral,
      );

  @override
  BVStatusColors lerp(ThemeExtension<BVStatusColors>? other, double t) {
    if (other is! BVStatusColors) return this;
    return BVStatusColors(
      pending: StatusStyle.lerp(pending, other.pending, t),
      inProgress: StatusStyle.lerp(inProgress, other.inProgress, t),
      success: StatusStyle.lerp(success, other.success, t),
      danger: StatusStyle.lerp(danger, other.danger, t),
      neutral: StatusStyle.lerp(neutral, other.neutral, t),
    );
  }
}

ThemeData _buildTheme(ColorScheme s, BVStatusColors status) {
  final isDark = s.brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: s,
    brightness: s.brightness,
    scaffoldBackgroundColor: isDark ? BVColors.darkBackground : BVColors.surface,
    dividerColor: s.outlineVariant,
    extensions: [status],
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? BVColors.darkSurface : BVColors.blue,
      foregroundColor: isDark ? BVColors.darkText : Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: s.surface,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDark ? BorderSide(color: s.outlineVariant) : BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(88, 44),
      ),
    ),
  );
}

ThemeData bvLightTheme() => _buildTheme(bvLightScheme, BVStatusColors.light);
ThemeData bvDarkTheme() => _buildTheme(bvDarkScheme, BVStatusColors.dark);
ThemeData bvPrimaryTheme() => bvLightTheme().copyWith(
      scaffoldBackgroundColor: BVColors.blue,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1F2870),
        foregroundColor: Colors.white,
      ),
    );
