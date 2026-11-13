import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router.dart';
import 'core/state.dart';
import 'core/theme/bv_theme.dart';

/// Full-screen error page so a failure is visible instead of a blank screen.
class _StartupError extends StatelessWidget {
  const _StartupError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            'App failed to start\n\n$message',
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
          ),
        ),
      ),
    ),
  );
}

Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Errors thrown while building/laying out widgets.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FLUTTER ERROR: ${details.exceptionAsString()}\n${details.stack}');
    };

    // Replace the blank/grey widget shown when a build fails with readable text.
    ErrorWidget.builder = (details) => Material(
      color: const Color(0xFF1B1B1B),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          '${details.exception}\n\n${details.stack}',
          style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
        ),
      ),
    );

    // Errors from the platform / async code outside the Flutter framework.
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('PLATFORM ERROR: $error\n$stack');
      return true;
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      runApp(ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const BellaVistaApp(),
      ));
    } catch (e, s) {
      debugPrint('STARTUP ERROR: $e\n$s');
      runApp(_StartupError('$e\n\n$s'));
    }
  }, (error, stack) {
    debugPrint('UNCAUGHT: $error\n$stack');
  });
}

class BellaVistaApp extends ConsumerWidget {
  const BellaVistaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(appearanceProvider);
    final signedIn = ref.watch(sessionProvider) != null;
    // First-time visitors see the Primary (brand) look before sign-in.
    final a = (!signedIn && chosen == AppAppearance.system) ? AppAppearance.primary : chosen;

    return MaterialApp.router(
      title: 'Bella Vista Procurement',
      debugShowCheckedModeBanner: false,
      theme: a == AppAppearance.primary ? bvPrimaryTheme() : bvLightTheme(),
      darkTheme: bvDarkTheme(),
      themeMode: switch (a) {
        AppAppearance.dark => ThemeMode.dark,
        AppAppearance.system => ThemeMode.system,
        _ => ThemeMode.light,
      },
      routerConfig: ref.watch(routerProvider),
    );
  }
}