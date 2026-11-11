import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/state.dart';
import '../../core/widgets.dart';

/// Purchase requests and purchase orders in one place.
class PurchasesPage extends ConsumerStatefulWidget {
  const PurchasesPage({super.key, this.initialTab});
  final String? initialTab;
  @override
  ConsumerState<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends ConsumerState<PurchasesPage> {
  late String _tab = widget.initialTab == 'orders' ? 'orders' : 'requests';

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionProvider) == null) return const SizedBox();
    return PageBody(
      title: 'Purchases',
      subtitle: 'Purchase request: OM submits > OD1 + OD2 approve > RA at USD 1,000 or more. Then a purchase order.',
      children: [
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'requests', label: Text('Purchase requests')),
            ButtonSegment(value: 'orders', label: Text('Purchase orders')),
          ],
          selected: {_tab},
          onSelectionChanged: (s) => setState(() => _tab = s.first),
        ),
        if (_tab == 'requests')
          AsyncBody<List<PurchaseRequest>>(
            value: ref.watch(prsP),
            onRetry: () => ref.invalidate(prsP),
            builder: (list) {
              final l = [...list]..sort((a, b) => b.id.compareTo(a.id));
              return Panel(
                child: Column(children: [
                  const RowHeader(['Reference', 'Requisition', 'Items', 'Value', 'Date', 'Status']),
                  if (l.isEmpty)
                    const Padding(padding: EdgeInsets.all(16), child: Text('No purchase requests yet. The Stores Controller raises one from a requisition with items not in stock.')),
                  for (var i = 0; i < l.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListRow(
                      path: '/app/purchase-requests/${l[i].id}',
                      ref: l[i].number,
                      a: l[i].requisitionNumber,
                      b: l[i].summary,
                      amount: l[i].total,
                      date: l[i].date,
                      chip: StatePill(l[i].status),
                    ),
                  ],
                ]),
              );
            },
          )
        else
          AsyncBody<List<PurchaseOrder>>(
            value: ref.watch(posP),
            onRetry: () => ref.invalidate(posP),
            builder: (list) {
              final l = [...list]..sort((a, b) => b.id.compareTo(a.id));
              return Panel(
                child: Column(children: [
                  const RowHeader(['Reference', 'Supplier', 'Purchase request', 'Total', 'Date', 'Status']),
                  if (l.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No purchase orders yet.')),
                  for (var i = 0; i < l.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListRow(
                      path: '/app/purchase-orders/${l[i].id}',
                      ref: l[i].number,
                      a: l[i].supplier,
                      b: l[i].prNumber,
                      amount: l[i].total,
                      date: l[i].orderDate,
                      chip: StatePill(l[i].status),
                    ),
                  ],
                ]),
              );
            },
          ),
      ],
    );
  }
}
