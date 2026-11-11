import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/catalogue_page.dart';
import '../features/admin/settings_page.dart';
import '../features/auth/auth_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/delivery/grv_detail_page.dart';
import '../features/delivery/grvs_page.dart';
import '../features/landing/landing_page.dart';
import '../features/purchases/po_detail_page.dart';
import '../features/purchases/pr_detail_page.dart';
import '../features/purchases/purchases_page.dart';
import '../features/requisitions/new_requisition_page.dart';
import '../features/requisitions/requisition_detail_page.dart';
import '../features/requisitions/requisitions_page.dart';
import '../features/stock/stock_page.dart';
import 'shell.dart';
import 'state.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run the redirect only when somebody signs in or out.
  final signedIn = ValueNotifier<bool>(ref.read(sessionProvider) != null);
  ref.listen(sessionProvider, (_, next) => signedIn.value = next != null);
  ref.onDispose(signedIn.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: signedIn,
    redirect: (context, state) {
      final me = ref.read(sessionProvider);
      final loc = state.uri.path;
      if (loc.startsWith('/app')) {
        if (me == null) return '/auth';
        if (!canOpen(me.role, loc)) return '/app/dashboard';
      } else if (loc == '/auth' && me != null) {
        return '/app/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LandingPage()),
      GoRoute(path: '/auth', builder: (_, __) => const AuthPage()),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/app/dashboard', builder: (_, __) => const DashboardPage()),
          GoRoute(path: '/app/requisitions', builder: (_, __) => const RequisitionsPage()),
          GoRoute(path: '/app/requisitions/new', builder: (_, __) => const NewRequisitionPage()),
          GoRoute(
            path: '/app/requisitions/:id',
            builder: (_, s) => RequisitionDetailPage(id: int.tryParse(s.pathParameters['id'] ?? '') ?? 0),
          ),
          GoRoute(path: '/app/purchases', builder: (_, s) => PurchasesPage(initialTab: s.uri.queryParameters['tab'])),
          GoRoute(
            path: '/app/purchase-requests/:id',
            builder: (_, s) => PrDetailPage(id: int.tryParse(s.pathParameters['id'] ?? '') ?? 0),
          ),
          GoRoute(
            path: '/app/purchase-orders/:id',
            builder: (_, s) => PoDetailPage(id: int.tryParse(s.pathParameters['id'] ?? '') ?? 0),
          ),
          GoRoute(path: '/app/deliveries', builder: (_, __) => const GrvsPage()),
          GoRoute(
            path: '/app/deliveries/:id',
            builder: (_, s) => GrvDetailPage(id: int.tryParse(s.pathParameters['id'] ?? '') ?? 0),
          ),
          GoRoute(path: '/app/stock', builder: (_, __) => const StockPage()),
          GoRoute(path: '/app/catalogue', builder: (_, __) => const CataloguePage()),
          GoRoute(path: '/app/settings', builder: (_, __) => const SettingsPage()),
        ],
      ),
    ],
  );
});
