import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models.dart';
import 'state.dart';
import 'theme/bv_theme.dart';
import 'widgets.dart';

class NavItem {
  const NavItem(this.path, this.label, this.icon);
  final String path;
  final String label;
  final IconData icon;
}

const _dash = NavItem('/app/dashboard', 'Dashboard', Icons.dashboard_rounded);
const _req = NavItem('/app/requisitions', 'Requisitions', Icons.description_rounded);
const _pur = NavItem('/app/purchases', 'Purchases', Icons.shopping_cart_rounded);
const _del = NavItem('/app/deliveries', 'Deliveries', Icons.local_shipping_rounded);
<<<<<<< HEAD
const _vou = NavItem('/app/vouchers', 'Vouchers', Icons.receipt_long_rounded, mobile: false);
const _usr = NavItem('/app/users', 'Users', Icons.group_rounded);
=======
const _stock = NavItem('/app/stock', 'Stock', Icons.inventory_2_rounded);
const _cat = NavItem('/app/catalogue', 'Catalogue', Icons.category_rounded);
>>>>>>> 644b51d7db41bc6a7eda86fbababccd98d16d8fb
const _set = NavItem('/app/settings', 'Settings', Icons.settings_rounded);

/// Menu items depend on the role picked at sign-in.
List<NavItem> navFor(Role r) => switch (r) {
      Role.requester => const [_dash, _req, _set],
      Role.stores => const [_dash, _req, _pur, _del, _stock, _cat, _set],
      Role.head => const [_dash, _req, _set],
<<<<<<< HEAD
      Role.om => const [_dash, _req, _stock, _vou, _set],
      Role.od1 => const [_dash, _req, _set],
      Role.od2 => const [_dash, _req, _set],
      Role.responsibleAuthority => const [_dash, _req, _set],
      Role.ho => const [_dash, _req, _stock, _del, _vou, _set],
      Role.driver => const [_dash, _del, _set],
=======
      Role.om => const [_dash, _req, _pur, _del, _stock, _set],
      Role.od1 || Role.od2 || Role.ra => const [_dash, _pur, _set],
>>>>>>> 644b51d7db41bc6a7eda86fbababccd98d16d8fb
      Role.security => const [_dash, _del, _set],
      Role.admin => const [_dash, _usr, _set],
    };

bool canOpen(Role r, String path) {
  if (path.startsWith('/app/purchase-')) return navFor(r).any((n) => n.path == '/app/purchases');
  return navFor(r).any((n) => path.startsWith(n.path));
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  Color _sidebarColor(BuildContext c) {
    if (isPrimaryMode(c)) return const Color(0xFF1F2870);
    if (isDarkMode(c)) return const Color(0xFF0A0B1B);
    return BVColors.blue;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider);
    if (me == null) return const Scaffold(body: SizedBox());
    final w = MediaQuery.sizeOf(context).width;
    final items = navFor(me.role);
    final mobileItems = <NavItem>[
      ...items.where((n) => !n.path.endsWith('settings')).take(4),
      items.last, // Settings = "Me"
    ];

    String normalised() {
      if (location.startsWith('/app/purchase-')) return '/app/purchases';
      return location;
    }

    int selected(List<NavItem> list) {
      var best = -1, len = -1;
      for (var i = 0; i < list.length; i++) {
        if (normalised().startsWith(list[i].path) && list[i].path.length > len) {
          best = i;
          len = list[i].path.length;
        }
      }
      return best;
    }

    final appBar = AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      title: Row(children: [
        const LogoBadge(size: 34),
        const SizedBox(width: 10),
        Flexible(child: Text(w < 420 ? 'Procurement' : 'Bella Vista Procurement', overflow: TextOverflow.ellipsis)),
      ]),
      actions: [
        IconButton(
          tooltip: 'Refresh data',
          onPressed: () {
            refreshAll(ref);
            snack(context, 'Refreshed.');
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
        PopupMenuButton<String>(
          tooltip: me.name,
          onSelected: (v) {
            if (v == 'settings') context.go('/app/settings');
            if (v == 'out') ref.read(sessionProvider.notifier).logout();
          },
          itemBuilder: (_) => [
            PopupMenuItem(enabled: false, child: Text('${me.name}\n${me.role.label}')),
            const PopupMenuItem(value: 'settings', child: Text('Settings')),
            const PopupMenuItem(value: 'out', child: Text('Switch user')),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: Text(me.name.isEmpty ? '?' : me.name[0].toUpperCase(),
                  style: TextStyle(fontFamily: 'Poppins', color: Theme.of(context).colorScheme.onSecondary)),
            ),
          ),
        ),
      ],
    );

    Widget nav;
    if (w >= 1024) {
      final sel = selected(items);
      nav = Container(
        width: 220,
        color: _sidebarColor(context),
        child: Column(children: [
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.go(items[i].path),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: i == sel ? Colors.white.withValues(alpha: 0.16) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Icon(items[i].icon, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text(items[i].label, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 14)),
                ]),
              ),
            ),
          const Spacer(),
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: BVColors.orange,
                child: Text(me.name.isEmpty ? '?' : me.name[0].toUpperCase(), style: const TextStyle(color: BVColors.ink, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(me.role.label, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ]),
          ),
        ]),
      );
    } else if (w >= 600) {
      final sel = selected(items);
      nav = SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height - 56),
          child: IntrinsicHeight(
            child: NavigationRail(
              selectedIndex: sel < 0 ? null : sel,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (i) => context.go(items[i].path),
              destinations: [for (final n in items) NavigationRailDestination(icon: Icon(n.icon), label: Text(n.label))],
            ),
          ),
        ),
      );
    } else {
      nav = const SizedBox.shrink();
    }

    final sel = selected(mobileItems);
    return Scaffold(
      appBar: appBar,
      body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [nav, Expanded(child: child)]),
      bottomNavigationBar: w < 600
          ? NavigationBar(
              selectedIndex: sel < 0 ? 0 : sel,
              onDestinationSelected: (i) => context.go(mobileItems[i].path),
              destinations: [
                for (final n in mobileItems)
                  NavigationDestination(icon: Icon(n.icon), label: n.path.endsWith('settings') ? 'Me' : n.label),
              ],
            )
          : null,
    );
  }
}
