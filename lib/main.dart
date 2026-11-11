import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router.dart';
import 'core/state.dart';
import 'core/theme/bv_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: const BellaVistaApp(),
  ));
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
