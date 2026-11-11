import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/providers.dart';
import 'theme/bv_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/requisitions_screen.dart';
import 'screens/stock_level_screen.dart';
import 'screens/delivery_voucher_screen.dart';
import 'screens/role_manager_screen.dart';

class BellaVistaApp extends ConsumerWidget {
  const BellaVistaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);

    return MaterialApp(
      title: 'Bella Vista Procurement System',
      debugShowCheckedModeBanner: false,
      theme: appearance == AppAppearance.primary ? bvPrimaryTheme() : bvLightTheme(),
      darkTheme: bvDarkTheme(),
      themeMode: switch (appearance) {
        AppAppearance.dark => ThemeMode.dark,
        AppAppearance.system => ThemeMode.system,
        _ => ThemeMode.light,
      },
      home: const MainScaffoldShell(),
    );
  }
}

class MainScaffoldShell extends ConsumerStatefulWidget {
  const MainScaffoldShell({super.key});

  @override
  ConsumerState<MainScaffoldShell> createState() => _MainScaffoldShellState();
}

class _MainScaffoldShellState extends ConsumerState<MainScaffoldShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 1024;

    final pages = <Widget>[
      const DashboardScreen(),
      const RequisitionsScreen(),
      const StockLevelScreen(),
      const DeliveryVoucherScreen(),
      const RoleManagerScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'BV',
                style: TextStyle(
                  color: BVColors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                'Bella Vista Procurement Portal',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Chip(
                label: Text('Role: ${appState.currentRole.name.toUpperCase()}'),
                backgroundColor: BVColors.orangeTint,
                labelStyle: const TextStyle(
                  color: Color(0xFF97480A),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              theme.brightness == Brightness.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
            onPressed: () {
              final current = ref.read(appearanceProvider);
              ref.read(appearanceProvider.notifier).set(
                    current == AppAppearance.dark
                        ? AppAppearance.light
                        : AppAppearance.dark,
                  );
            },
            tooltip: 'Toggle Theme Mode',
          ),
        ],
      ),
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.dashboard_rounded), label: Text('Dashboard')),
                NavigationRailDestination(icon: Icon(Icons.description_rounded), label: Text('Requisitions')),
                NavigationRailDestination(icon: Icon(Icons.inventory_2_rounded), label: Text('Stock & Levels')),
                NavigationRailDestination(icon: Icon(Icons.local_shipping_rounded), label: Text('Vouchers & Delivery')),
                NavigationRailDestination(icon: Icon(Icons.admin_panel_settings_rounded), label: Text('Switch Role')),
              ],
            ),
          Expanded(child: pages[_currentIndex]),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
                NavigationDestination(icon: Icon(Icons.description_rounded), label: 'Requests'),
                NavigationDestination(icon: Icon(Icons.inventory_2_rounded), label: 'Stock'),
                NavigationDestination(icon: Icon(Icons.local_shipping_rounded), label: 'Delivery'),
                NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Role'),
              ],
            ),
    );
  }
}
