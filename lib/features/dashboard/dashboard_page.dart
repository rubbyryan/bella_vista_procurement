import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/state.dart';
import '../../core/widgets.dart';
import '../stock/stock_page.dart' show lowStockCount;

class _Work {
  _Work(this.kind, this.ref, this.why, this.path, this.status, this.at);
  final String kind;
  final String ref;
  final String why;
  final String path;
  final String status;
  final int at;
}

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  List<_Work> _work(Session me, List<Requisition> reqs, List<PurchaseRequest> prs, List<PurchaseOrder> pos, List<Grv> grvs) {
    final w = <_Work>[];
    final mine = me.name.trim().toLowerCase();
    for (final r in reqs) {
      final p = '/app/requisitions/${r.id}';
      switch (me.role) {
        case Role.stores:
          if (r.status == 'NEW' || r.status == 'STORES_REVIEW') w.add(_Work('Requisition', r.number, 'Check stock and send for approval', p, r.status, r.id));
          if (r.status == 'READY_FOR_ISSUE' || r.status == 'PARTIALLY_ISSUED') w.add(_Work('Requisition', r.number, 'Issue stock', p, r.status, r.id));
        case Role.head:
          if (r.status == 'PENDING_HEAD_APPROVAL') w.add(_Work('Requisition', r.number, 'Approval needed', p, r.status, r.id));
        case Role.om:
          if (r.status == 'PENDING_OM_APPROVAL') w.add(_Work('Requisition', r.number, 'Approval needed', p, r.status, r.id));
        case Role.requester:
          if (r.officer.trim().toLowerCase() == mine && r.status == 'REJECTED') w.add(_Work('Requisition', r.number, 'Rejected: see the comment', p, r.status, r.id));
        default:
          break;
      }
    }
    for (final r in prs) {
      final p = '/app/purchase-requests/${r.id}';
      switch (me.role) {
        case Role.om:
          if (r.status == 'DRAFT' || r.status == 'RETURNED_TO_OM') w.add(_Work('Purchase request', r.number, 'Submit to the directorate', p, r.status, r.id));
        case Role.od1:
          if (r.status == 'PENDING_DIRECTORATE_APPROVAL' && r.od1By == null) w.add(_Work('Purchase request', r.number, 'Approval needed', p, r.status, r.id));
        case Role.od2:
          if (r.status == 'PENDING_DIRECTORATE_APPROVAL' && r.od2By == null) w.add(_Work('Purchase request', r.number, 'Approval needed', p, r.status, r.id));
        case Role.ra:
          if (r.status == 'PENDING_RA_APPROVAL') w.add(_Work('Purchase request', r.number, 'Approval needed', p, r.status, r.id));
        case Role.stores:
          if (r.status == 'APPROVED') w.add(_Work('Purchase request', r.number, 'Create the purchase order', p, r.status, r.id));
        default:
          break;
      }
    }
    for (final o in pos) {
      final p = '/app/purchase-orders/${o.id}';
      if (me.role == Role.stores || me.role == Role.om) {
        if (o.status == 'DRAFT') w.add(_Work('Purchase order', o.number, 'Issue to the supplier', p, o.status, o.id));
      }
      if ((me.role == Role.stores || me.role == Role.security) && (o.status == 'ISSUED' || o.status == 'PARTIALLY_RECEIVED')) {
        w.add(_Work('Purchase order', o.number, 'Receive the delivery when it arrives', p, o.status, o.id));
      }
    }
    for (final g in grvs) {
      final p = '/app/deliveries/${g.id}';
      if (g.status == 'DRAFT' && (me.role == Role.stores || me.role == Role.security)) w.add(_Work('Delivery', g.number, 'Submit for verification', p, g.status, g.id));
      if (g.status == 'PENDING_STOCK_VERIFICATION' && me.role == Role.stores) w.add(_Work('Delivery', g.number, 'Verify the delivery', p, g.status, g.id));
      if (g.status == 'PENDING_OM_APPROVAL' && me.role == Role.om) w.add(_Work('Delivery', g.number, 'Approve and add to stock', p, g.status, g.id));
    }
    return w;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider);
    if (me == null) return const SizedBox();
    final reqsA = ref.watch(requisitionsP);
    final prsA = ref.watch(prsP);
    final posA = ref.watch(posP);
    final grvsA = ref.watch(grvsP);
    final itemsA = ref.watch(itemsP);
    final balA = ref.watch(balancesP);

    final err = [reqsA, prsA, posA, grvsA].where((a) => a.hasError).firstOrNull;
    final loading = [reqsA, prsA, posA, grvsA].any((a) => a.isLoading && !a.hasValue);

    PageBody wrap(List<Widget> c) => PageBody(
      title: '${me.role.label} Dashboard',
      subtitle: '${_greeting()}, ${me.name.split(' ').first}${me.role == Role.requester && me.department.isNotEmpty ? ' | ${me.department}' : ''}',
      children: c,
    );

    if (err != null) {
      return wrap([AsyncBody<int>(value: AsyncError(err.error!, StackTrace.empty), builder: (_) => const SizedBox(), onRetry: () => refreshAll(ref))]);
    }
    if (loading) return wrap(const [Panel(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())))]);

    final reqs = reqsA.value!;
    final prs = prsA.value!;
    final pos = posA.value!;
    final grvs = grvsA.value!;
    final work = _work(me, reqs, prs, pos, grvs)..sort((a, b) => a.at.compareTo(b.at));
    final low = (itemsA.valueOrNull != null && balA.valueOrNull != null) ? lowStockCount(itemsA.valueOrNull!, balA.valueOrNull!) : null;
    void go(String p) => context.go(p);

    final kpis = <Widget>[
      KpiCard(label: 'Waiting for me', value: '${work.length}', icon: Icons.pending_actions_rounded, warn: work.isNotEmpty),
      if (me.role != Role.security && me.role != Role.od1 && me.role != Role.od2 && me.role != Role.ra)
        KpiCard(
          label: me.role == Role.requester ? 'My open requisitions' : 'Open requisitions',
          value: '${reqs.where((r) => !const ['RESOLVED', 'REJECTED', 'CONVERTED_TO_PURCHASE'].contains(r.status) && (me.role != Role.requester || r.officer.trim().toLowerCase() == me.name.trim().toLowerCase())).length}',
          icon: Icons.description_rounded,
          onTap: () => go('/app/requisitions'),
        ),
      if (me.role != Role.requester && me.role != Role.head && me.role != Role.security)
        KpiCard(
          label: 'Open purchase requests',
          value: '${prs.where((p) => !const ['CONVERTED_TO_PO', 'CANCELLED', 'REJECTED'].contains(p.status)).length}',
          icon: Icons.shopping_cart_rounded,
          onTap: () => go('/app/purchases'),
        ),
      if (me.role == Role.stores || me.role == Role.om || me.role == Role.security)
        KpiCard(
          label: 'Deliveries in progress',
          value: '${grvs.where((g) => !g.stockAdded && g.status != 'REJECTED').length}',
          icon: Icons.local_shipping_rounded,
          onTap: () => go('/app/deliveries'),
        ),
      if ((me.role == Role.stores || me.role == Role.om) && low != null)
        KpiCard(label: 'Items at reorder level', value: '$low', icon: Icons.warning_amber_rounded, warn: low > 0, onTap: () => go('/app/stock')),
    ];

    return wrap([
      ResponsiveGrid(children: kpis),
      Panel(
        title: 'Waiting for you',
        child: work.isEmpty
            ? const Padding(padding: EdgeInsets.all(8), child: Text('Nothing is waiting for you. Great work!'))
            : Column(children: [
          for (var i = 0; i < work.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListRow(
              path: work[i].path,
              ref: work[i].ref,
              a: work[i].kind,
              b: work[i].why,
              chip: StatePill(work[i].status),
            ),
          ],
        ]),
      ),
    ]);
  }
}