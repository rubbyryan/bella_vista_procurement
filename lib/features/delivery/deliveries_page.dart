import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/widgets.dart';

class DeliveriesPage extends ConsumerWidget {
  const DeliveriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(storeProvider);
    final u = s.currentUser;
    if (u == null) return const SizedBox();
    final mine = s.deliveriesFor(u).toSet();
    final others = s.notes.where((n) => !mine.contains(n)).toList();

    Widget tile(DeliveryNote n) => ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () => context.go('/app/deliveries/${n.no}'),
          title: Text('${n.no} | ${n.supplier}'),
          subtitle: Text('${n.batchRef} | Driver ${n.driver} | ${dmy(n.date)}'),
          trailing: StatusChip(n.stageLabel, n.kind),
        );

    return PageBody(
      title: 'Deliveries',
      subtitle: 'Chain of custody: Driver > Security > Stores Controller, then stock is added',
      children: [
        Panel(
          title: u.role == Role.ho || u.role == Role.om ? 'Open delivery notes' : 'Waiting for you',
          child: mine.isEmpty
              ? const Text('Nothing is waiting for you. Delivery notes appear here once Head Office releases funds for a voucher.')
              : Column(children: [for (final n in mine) tile(n)]),
        ),
        if (others.isNotEmpty) Panel(title: 'Other delivery notes', child: Column(children: [for (final n in others) tile(n)])),
      ],
    );
  }
}
