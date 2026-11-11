import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/theme/bv_theme.dart';
import '../../core/widgets.dart';

class VouchersPage extends ConsumerWidget {
  const VouchersPage({super.key});

  void _view(BuildContext context, Voucher v) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: BVSurface(
            child: Builder(builder: (c) {
              final t = Theme.of(c);
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const LogoBadge(size: 48),
                    const SizedBox(width: 12),
                    Expanded(child: Text('BELLA VISTA COLLEGE\nMazowe, Zimbabwe', style: t.textTheme.titleMedium)),
                    Text('PURCHASE VOUCHER', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: accentText(c))),
                  ]),
                  const Divider(height: 24),
                  Wrap(spacing: 32, runSpacing: 8, children: [
                    Text('Voucher no.\n${v.no}'),
                    Text('Date\n${dmy(v.date)}'),
                    Text('Requisition\n${v.batchRef}'),
                    Text('Payee / supplier\n${v.supplier}'),
                    Text('Payment method\n${v.method}'),
                  ]),
                  const SizedBox(height: 16),
                  Container(
                    color: t.colorScheme.primaryContainer,
                    padding: const EdgeInsets.all(8),
                    child: const Row(children: [
                      Expanded(flex: 3, child: Text('Description')),
                      Expanded(child: Text('Qty')),
                      Expanded(child: Text('Unit \$')),
                      Expanded(child: Text('Total \$', textAlign: TextAlign.right)),
                    ]),
                  ),
                  for (final l in v.lines)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(children: [
                        Expanded(flex: 3, child: Text(l.name)),
                        Expanded(child: Text('${l.qty}')),
                        Expanded(child: Text(l.unitPrice.toStringAsFixed(2))),
                        Expanded(child: Text(l.total.toStringAsFixed(2), textAlign: TextAlign.right)),
                      ]),
                    ),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('TOTAL REQUESTED (USD)  ${v.amount.toStringAsFixed(2)}',
                        style: t.textTheme.titleMedium),
                  ),
                  const SizedBox(height: 12),
                  Text('Prepared by ${v.raisedBy} (Head Office Admin)', style: t.textTheme.labelSmall),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
                  ),
                ]),
              );
            }),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(storeProvider);
    final u = s.currentUser;
    if (u == null) return const SizedBox();
    return PageBody(
      title: 'Purchase vouchers',
      subtitle: 'Request for funds. One voucher per fulfilment batch; numbers are sequential.',
      children: [
        Panel(
          child: s.vouchers.isEmpty
              ? const Text('No vouchers yet. Head Office raises one when releasing a batch on an approved requisition.')
              : Column(children: [
                  for (final v in s.vouchers)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => _view(context, v),
                      title: Text('${v.no} | ${money(v.amount)}'),
                      subtitle: Text('${v.batchRef} | ${v.supplier} | ${dmy(v.date)}'),
                      trailing: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        StatusChip(v.released ? 'Funds released' : 'Raised', v.released ? StatusKind.success : StatusKind.pending),
                        if (u.role == Role.ho && !v.released)
                          FilledButton(
                            style: ctaStyle(context),
                            onPressed: () => snack(context, s.releaseFunds(v) ?? 'Funds released. Delivery note created and driver assigned.'),
                            child: const Text('Release funds'),
                          ),
                      ]),
                    ),
                ]),
        ),
      ],
    );
  }
}
