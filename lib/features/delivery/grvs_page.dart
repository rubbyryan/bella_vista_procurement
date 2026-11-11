import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/state.dart';
import '../../core/widgets.dart';

class GrvsPage extends ConsumerWidget {
  const GrvsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(sessionProvider) == null) return const SizedBox();
    return PageBody(
      title: 'Deliveries (GRV)',
      subtitle: 'Security / receiving officer records the delivery, the Stores Controller verifies, the Operations Manager approves. Approval adds the stock.',
      children: [
        AsyncBody<List<Grv>>(
          value: ref.watch(grvsP),
          onRetry: () => ref.invalidate(grvsP),
          builder: (list) {
            final l = [...list]..sort((a, b) => b.id.compareTo(a.id));
            return Panel(
              child: Column(children: [
                const RowHeader(['Reference', 'Supplier', 'Purchase order', '', 'Date', 'Status']),
                if (l.isEmpty)
                  const Padding(padding: EdgeInsets.all(16), child: Text('No deliveries yet. Open a purchase order and choose "Receive delivery".')),
                for (var i = 0; i < l.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListRow(
                    path: '/app/deliveries/${l[i].id}',
                    ref: l[i].number,
                    a: l[i].supplier,
                    b: '${l[i].poNumber} | received by ${l[i].receivedBy}',
                    date: l[i].deliveryDate,
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
