// lib/core/theme/bv_theme.dart
// Bella Vista Procurement System: primary (brand), light and dark themes.
// Material 3. Fonts: Poppins (headings, buttons, numbers), Aragon Sans (body).
//
// pubspec.yaml
//   flutter:
//     fonts:
//       - family: Poppins
//         fonts:
//           - asset: assets/fonts/Poppins-Light.ttf
//             weight: 300
//           - asset: assets/fonts/Poppins-Regular.ttf
//           - asset: assets/fonts/Poppins-Medium.ttf
//             weight: 500
//           - asset: assets/fonts/Poppins-Bold.ttf
//             weight: 700
//       - family: AragonSans
//         fonts:
//           - asset: assets/fonts/AragonSans-Regular.ttf
//
// Dependencies: flutter_riverpod, shared_preferences (to remember the choice)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// 1. PRIMARY (BRAND) PALETTE: straight from the brand guide
// ---------------------------------------------------------------------------
class BVColors {
  BVColors._();

  // Brand
  static const blue = Color(0xFF2A3488); // Bella Blue: primary / app bars
  static const orange = Color(0xFFEF7B22); // Vista Orange: accent / CTAs
  static const slate = Color(0xFF4D4D4D); // Slate Grey: secondary text
  static const ink = Color(0xFF1A1A1A); // Ink: primary text

  // Supporting (light)
  static const surface = Color(0xFFF4F5FA);
  static const blueTint = Color(0xFFE8EAF6);
  static const orangeTint = Color(0xFFFDEBDD);
  static const success = Color(0xFF2E9E5B);
  static const error = Color(0xFFD64545);
  static const divider = Color(0xFFDADDEA);

  // Dark-mode derivatives (brand blue is too dark to read on dark surfaces,
  // so dark mode uses a lifted blue and a slightly brighter orange)
  static const darkBackground = Color(0xFF0E1024);
  static const darkSurface = Color(0xFF151833);
  static const darkSurfaceHigh = Color(0xFF232748);
  static const darkBlue = Color(0xFFA8B1F5); // primary on dark
  static const darkOrange = Color(0xFFFF9248); // secondary on dark
  static const darkText = Color(0xFFE6E7F2);
  static const darkMuted = Color(0xFFB0B4D0);
  static const darkOutline = Color(0xFF3A3F66);
  static const darkSuccess = Color(0xFF5FD38F);
  static const darkError = Color(0xFFFF8A8A);
}

// ---------------------------------------------------------------------------
// 2. COLOUR SCHEMES
// ---------------------------------------------------------------------------
const bvLightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: BVColors.blue,
  onPrimary: Colors.white,
  primaryContainer: BVColors.blueTint,
  onPrimaryContainer: BVColors.blue,
  secondary: BVColors.orange,
  onSecondary: BVColors.ink, // white on Vista Orange is only 2.79:1
  secondaryContainer: BVColors.orangeTint,
  onSecondaryContainer: Color(0xFF7A3A05),
  tertiary: BVColors.success,
  onTertiary: Colors.white,
  error: BVColors.error,
  onError: Colors.white,
  errorContainer: Color(0xFFFBE4E4),
  onErrorContainer: Color(0xFF7A1F1F),
  surface: Colors.white,
  onSurface: BVColors.ink,
  onSurfaceVariant: BVColors.slate,
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: BVColors.surface,
  surfaceContainer: BVColors.surface,
  surfaceContainerHigh: BVColors.blueTint,
  surfaceContainerHighest: BVColors.blueTint,
  outline: Color(0xFF7A81A8), // 3.8:1 on white, used for input borders
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
  primaryContainer: BVColors.blue, // brand blue as a container on dark
  onPrimaryContainer: Color(0xFFE0E3FF),
  secondary: BVColors.darkOrange,
  onSecondary: Color(0xFF3A1A00),
  secondaryContainer: Color(0xFF5A2E0A),
  onSecondaryContainer: BVColors.orangeTint,
  tertiary: BVColors.darkSuccess,
  onTertiary: Color(0xFF003919),
  error: BVColors.darkError,
  onError: Color(0xFF5A0F0F),
  errorContainer: Color(0xFF7A2222),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: BVColors.darkSurface,
  onSurface: BVColors.darkText,
  onSurfaceVariant: BVColors.darkMuted,
  surfaceContainerLowest: BVColors.darkBackground,
  surfaceContainerLow: BVColors.darkSurface,
  surfaceContainer: BVColors.darkSurface,
  surfaceContainerHigh: BVColors.darkSurfaceHigh,
  surfaceContainerHighest: BVColors.darkSurfaceHigh,
  outline: Color(0xFF8A8FB5),
  outlineVariant: BVColors.darkOutline,
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: BVColors.darkText,
  onInverseSurface: BVColors.ink,
  inversePrimary: BVColors.blue,
);

// ---------------------------------------------------------------------------
// 3. STATUS CHIP COLOURS (theme extension)
//    Amber = waiting, Blue = in progress, Green = done/healthy, Red = rejected.
//    Usage: Theme.of(context).extension<BVStatusColors>()!.pending
// ---------------------------------------------------------------------------
@immutable
class StatusStyle {
  const StatusStyle(this.background, this.foreground);
  final Color background;
  final Color foreground;
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

  final StatusStyle pending; // Pending Head / OM / HO, Reorder, Awaiting
  final StatusStyle inProgress; // Stores Review, In Transit, Partial
  final StatusStyle success; // Approved, Delivered, Completed, Healthy
  final StatusStyle danger; // Rejected, Critical, Out of stock
  final StatusStyle neutral; // Draft

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
  BVStatusColors lerp(ThemeExtension<BVStatusColors>? other, double t) =>
      t < 0.5 ? this : (other as BVStatusColors? ?? this);
}

// ---------------------------------------------------------------------------
// 4. TEXT THEME: Poppins for headings / buttons / numbers, Aragon Sans body
// ---------------------------------------------------------------------------
TextTheme _textTheme(ColorScheme s, Color headingColor) {
  TextStyle poppins(double size, FontWeight w, {Color? color}) => TextStyle(
        fontFamily: 'Poppins',
        fontSize: size,
        fontWeight: w,
        color: color ?? headingColor,
      );
  TextStyle body(double size) => TextStyle(
        fontFamily: 'AragonSans',
        fontFamilyFallback: const ['Poppins'],
        fontSize: size,
        color: s.onSurface,
      );

  return TextTheme(
    displaySmall: poppins(32, FontWeight.w700), // Display 32 Bold
    headlineMedium: poppins(24, FontWeight.w700), // Headline 24 Bold
    titleMedium: poppins(16, FontWeight.w500), // Title 16 Medium
    labelLarge: poppins(14, FontWeight.w500, color: s.onSurface),
    bodyLarge: body(16), // Body L
    bodyMedium: body(14), // Body M
    labelSmall: body(12), // Label 12 Regular
  );
}

// ---------------------------------------------------------------------------
// 5. THEME BUILDER (shared by light and dark so they never drift apart)
// ---------------------------------------------------------------------------
ThemeData _build(ColorScheme s, BVStatusColors status) {
  final isDark = s.brightness == Brightness.dark;
  // App bars: brand blue in light mode, dark surface in dark mode
  final appBarBg = isDark ? BVColors.darkSurface : BVColors.blue;
  final appBarFg = isDark ? BVColors.darkText : Colors.white;

  return ThemeData(
    useMaterial3: true,
    colorScheme: s,
    brightness: s.brightness,
    scaffoldBackgroundColor: isDark ? BVColors.darkBackground : BVColors.surface,
    dividerColor: s.outlineVariant,
    textTheme: _textTheme(s, isDark ? BVColors.darkBlue : BVColors.blue),
    fontFamily: 'AragonSans',
    extensions: [status],

    appBarTheme: AppBarTheme(
      backgroundColor: appBarBg,
      foregroundColor: appBarFg,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: appBarFg,
      ),
    ),

    // Cards: radius 12, elevation level 1
    cardTheme: CardThemeData(
      color: s.surface,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDark ? BorderSide(color: s.outlineVariant) : BorderSide.none,
      ),
    ),

    // Buttons: pill shape. Blue = normal actions, orange = ONE main CTA.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(88, 44),
        textStyle: const TextStyle(
            fontFamily: 'Poppins', fontWeight: FontWeight.w500, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(88, 44),
        side: BorderSide(color: s.primary),
        foregroundColor: s.primary,
        textStyle: const TextStyle(
            fontFamily: 'Poppins', fontWeight: FontWeight.w500, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: s.primary,
        textStyle: const TextStyle(
            fontFamily: 'Poppins', fontWeight: FontWeight.w500, fontSize: 14),
      ),
    ),

    // Inputs: outlined, radius 8, red border on error
    inputDecorationTheme: InputDecorationTheme(
      filled: isDark,
      fillColor: isDark ? BVColors.darkSurfaceHigh : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: s.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: s.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: s.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: s.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: s.error, width: 2),
      ),
    ),

    // Segmented control for the Sign in / Register toggle
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: isDark ? BVColors.blue : BVColors.blue,
        selectedForegroundColor: Colors.white,
        shape: const StadiumBorder(),
      ),
    ),

    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      labelStyle: const TextStyle(fontSize: 12),
    ),

    dialogTheme: DialogThemeData(
      elevation: 3, // level 3 for dialogs
      backgroundColor: s.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: s.surface,
      indicatorColor: s.primaryContainer,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: s.surface,
      indicatorColor: s.primaryContainer,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: s.inverseSurface,
      contentTextStyle: TextStyle(color: s.onInverseSurface),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: s.primary,
      linearTrackColor: s.outlineVariant,
    ),
  );
}

// Public themes
ThemeData bvLightTheme() => _build(bvLightScheme, BVStatusColors.light);
ThemeData bvDarkTheme() => _build(bvDarkScheme, BVStatusColors.dark);

// Kept so existing code that calls bvTheme() still works (light = default)
ThemeData bvTheme() => bvLightTheme();

// ---------------------------------------------------------------------------
// 6. PRIMARY MODE: Bella Blue canvas with white card "islands"
//    Text placed directly on the canvas is white. Cards, tables, forms and
//    dialogs are wrapped in BVSurface, which re-applies the light theme inside
//    so their text stays Ink on white.
// ---------------------------------------------------------------------------
ThemeData? _lightCache;
ThemeData get _light => _lightCache ??= bvLightTheme();

ThemeData bvPrimaryTheme() {
  final base = bvLightTheme();
  const deepBlue = Color(0xFF1F2870);
  return base.copyWith(
    scaffoldBackgroundColor: BVColors.blue,
    textTheme: base.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    appBarTheme: base.appBarTheme.copyWith(backgroundColor: deepBlue),
    dividerColor: const Color(0xFF5A65B8),
    // Dialogs and sheets are white, so give them Ink text
    dialogTheme: base.dialogTheme.copyWith(
      titleTextStyle: base.textTheme.titleMedium?.copyWith(color: BVColors.ink),
      contentTextStyle: base.textTheme.bodyMedium?.copyWith(color: BVColors.ink),
    ),
  );
}

/// White island for use on Primary-mode screens. In Light and Dark mode it is
/// a no-op, so screens can use it everywhere.
class BVSurface extends StatelessWidget {
  const BVSurface({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final onBlueCanvas = Theme.of(context).scaffoldBackgroundColor == BVColors.blue;
    final inner = padding == null ? child : Padding(padding: padding!, child: child);
    if (!onBlueCanvas) return inner;
    return Theme(
      data: _light,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: inner,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. APPEARANCE: System / Light / Dark / Primary, remembered on the device
// ---------------------------------------------------------------------------
enum AppAppearance { system, light, dark, primary }

class AppearanceNotifier extends Notifier<AppAppearance> {
  static const _key = 'bv_appearance';

  @override
  AppAppearance build() {
    _load();
    return AppAppearance.system; // follow the device until the user chooses
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      state = AppAppearance.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => AppAppearance.system,
      );
    }
  }

  Future<void> set(AppAppearance a) async {
    state = a;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, a.name);
    // TODO: also save to the user profile so it follows them across devices
  }
}

final appearanceProvider =
    NotifierProvider<AppearanceNotifier, AppAppearance>(AppearanceNotifier.new);

// ---------------------------------------------------------------------------
// 8. WIRING IT UP (lib/main.dart)
// ---------------------------------------------------------------------------
// class BellaVistaApp extends ConsumerWidget {
//   const BellaVistaApp({super.key});
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final a = ref.watch(appearanceProvider);
//     return MaterialApp.router(
//       title: 'Bella Vista Procurement',
//       theme: a == AppAppearance.primary ? bvPrimaryTheme() : bvLightTheme(),
//       darkTheme: bvDarkTheme(),
//       themeMode: switch (a) {
//         AppAppearance.dark => ThemeMode.dark,
//         AppAppearance.system => ThemeMode.system,
//         _ => ThemeMode.light,
//       },
//       routerConfig: ref.watch(routerProvider),
//     );
//   }
// }

// ---------------------------------------------------------------------------
// 8b. APPEARANCE PICKER (put it on the "Me" / Settings screen)
// ---------------------------------------------------------------------------
class AppearancePicker extends ConsumerWidget {
  const AppearancePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(appearanceProvider);
    return SegmentedButton<AppAppearance>(
      segments: const [
        ButtonSegment(
            value: AppAppearance.system,
            icon: Icon(Icons.brightness_auto_rounded),
            label: Text('System')),
        ButtonSegment(
            value: AppAppearance.light,
            icon: Icon(Icons.light_mode_rounded),
            label: Text('Light')),
        ButtonSegment(
            value: AppAppearance.dark,
            icon: Icon(Icons.dark_mode_rounded),
            label: Text('Dark')),
        ButtonSegment(
            value: AppAppearance.primary,
            icon: Icon(Icons.palette_rounded),
            label: Text('Primary')),
      ],
      selected: {a},
      onSelectionChanged: (s) =>
          ref.read(appearanceProvider.notifier).set(s.first),
    );
  }
}

// ---------------------------------------------------------------------------
// 9. STATUS CHIP (always shows the text label, never colour alone)
// ---------------------------------------------------------------------------
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, this.kind, {super.key});
  final String label;
  final StatusKind kind;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<BVStatusColors>()!;
    final style = switch (kind) {
      StatusKind.pending => c.pending,
      StatusKind.inProgress => c.inProgress,
      StatusKind.success => c.success,
      StatusKind.danger => c.danger,
      StatusKind.neutral => c.neutral,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: style.foreground,
        ),
      ),
    );
  }
}

enum StatusKind { pending, inProgress, success, danger, neutral }
