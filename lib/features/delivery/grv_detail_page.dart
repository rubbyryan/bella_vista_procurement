import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/state.dart';
import '../../core/widgets.dart';

/// GRV workflow (GoodsReceivedVoucherService):
/// DRAFT > submit > PENDING_STOCK_VERIFICATION > verify > PENDING_OM_APPROVAL > approve (stock added).
class GrvDetailPage extends ConsumerStatefulWidget {
  const GrvDetailPage({super.key, required this.id});
  final int id;
  @override
  ConsumerState<GrvDetailPage> createState() => _GrvDetailPageState();
}

class _GrvDetailPageState extends ConsumerState<GrvDetailPage> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() f, String ok) async {
    setState(() => _busy = true);
    await act(context, ref, f, ok);
    if (mounted) setState(() => _busy = false);
  }

  List<StepInfo> _steps(Grv g) {
    if (g.status == 'REJECTED') {
      return const [
        StepInfo('Received', StepState.done),
        StepInfo('Verified', StepState.done),
        StepInfo('OM', StepState.rejected),
      ];
    }
    final cur = switch (g.status) {
      'DRAFT' => 0,
      'PENDING_STOCK_VERIFICATION' => 1,
      'PENDING_OM_APPROVAL' => 2,
      _ => 3,
    };
    StepState st(int i) => i < cur ? StepState.done : (i == cur ? StepState.current : StepState.todo);
    return [StepInfo('Received', st(0)), StepInfo('Verified', st(1)), StepInfo('OM approves', st(2)), StepInfo('In stock', st(3))];
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider);
    if (me == null) return const SizedBox();
    final repo = ref.read(repoProvider);

    return PageBody(
      title: 'Goods received voucher',
      actions: [
        OutlinedButton.icon(
          style: canvasOutlined(context),
          onPressed: () => context.go('/app/deliveries'),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Back'),
        ),
      ],
      children: [
        AsyncBody<List<Grv>>(
          value: ref.watch(grvsP),
          onRetry: () => ref.invalidate(grvsP),
          builder: (all) {
            final g = all.where((x) => x.id == widget.id).firstOrNull;
            if (g == null) return const Panel(child: Text('GRV not found.'));
            return Column(children: [
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(g.number, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                    StatePill(g.status),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 32, runSpacing: 8, children: [
                    Fact('Purchase order', g.poNumber),
                    Fact('Supplier', g.supplier),
                    Fact('Delivery note', g.deliveryNote),
                    Fact('Delivery date', g.deliveryDate == null ? '' : dmy(g.deliveryDate!)),
                    Fact('Vehicle', g.vehicle),
                    Fact('Driver', g.driver),
                    Fact('Created by', g.createdBy),
                    Fact('Received by (gate)', g.receivedBy),
                    Fact('Submitted by', g.submittedBy ?? ''),
                    Fact('Verified by', g.verifiedBy ?? ''),
                    Fact('Approved by', g.approvedBy ?? ''),
                  ]),
                  if (g.remarks.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(g.remarks)),
                  if (g.verifyRemarks != null) Text('Verification: ${g.verifyRemarks}'),
                  if (g.approvalComments != null) Text('OM comments: ${g.approvalComments}'),
                  if (g.rejectedBy != null)
                    Builder(builder: (c) => Text('Rejected by ${g.rejectedBy}: ${g.rejectionReason ?? ''}', style: TextStyle(color: Theme.of(c).colorScheme.error))),
                  TextButton(onPressed: () => context.go('/app/purchase-orders/${g.poId}'), child: Text('Open ${g.poNumber}')),
                ]),
              ),
              const SizedBox(height: 16),
              Panel(title: 'Progress', child: ChainStepper(_steps(g))),
              const SizedBox(height: 16),
              Panel(
                title: g.stockAdded ? 'Items added to stock' : 'Items',
                child: Column(children: [
                  for (final l in g.lines)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.item.label),
                      subtitle: Text('Ordered ${qty(l.ordered)} | delivered ${qty(l.delivered)} | accepted ${qty(l.accepted)} | rejected ${qty(l.rejected)} | damaged ${qty(l.damaged)}'
                          '${l.location.isEmpty ? '' : ' | into ${l.location}'}${l.remarks.isEmpty ? '' : '\n${l.remarks}'}'),
                    ),
                ]),
              ),
              if (g.status == 'DRAFT' && (me.role == Role.stores || me.role == Role.security)) ...[
                const SizedBox(height: 16),
                Panel(
                  title: 'Submit for verification',
                  child: Row(children: [
                    const Expanded(child: Text('Check the quantities, then submit the GRV to the Stores Controller for verification.')),
                    Builder(builder: (c) => FilledButton(
                        style: ctaStyle(c),
                        onPressed: _busy ? null : () => _run(() => repo.grvSubmit(g.id, me.name), 'Submitted for verification.'),
                        child: const Text('Submit'))),
                  ]),
                ),
              ],
              if (g.status == 'PENDING_STOCK_VERIFICATION' && me.role == Role.stores) ...[
                const SizedBox(height: 16),
                Panel(
                  title: 'Stores Controller verification',
                  child: Row(children: [
                    const Expanded(child: Text('Count the goods against the delivery and confirm the quantities.')),
                    Builder(builder: (c) => FilledButton(
                        style: ctaStyle(c),
                        onPressed: _busy
                            ? null
                            : () async {
                                final v = await askFields(context, title: 'Verify delivery', labels: const ['Remarks (optional)'], confirm: 'Verify');
                                if (v != null && mounted) await _run(() => repo.grvVerify(g.id, me.name, v[0]), 'Verified. Waiting for the Operations Manager.');
                              },
                        child: const Text('Verify'))),
                  ]),
                ),
              ],
              if (g.status == 'PENDING_OM_APPROVAL' && me.role == Role.om) ...[
                const SizedBox(height: 16),
                Panel(
                  title: 'Operations Manager approval',
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Approving adds the accepted quantities to stock. You must be a different person from whoever created, received, submitted or verified this GRV.'),
                    const SizedBox(height: 12),
                    Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.end, children: [
                      Builder(builder: (c) => OutlinedButton(
                          style: dangerOutlined(c),
                          onPressed: _busy
                              ? null
                              : () async {
                                  final v = await showCommentDialog(context, title: 'Reject GRV', message: 'A reason is required.');
                                  if (v != null && mounted) await _run(() => repo.grvReject(g.id, me.name, v), 'GRV rejected.');
                                },
                          child: const Text('Reject'))),
                      Builder(builder: (c) => FilledButton(
                          style: ctaStyle(c),
                          onPressed: _busy
                              ? null
                              : () async {
                                  final v = await askFields(context, title: 'Approve & add to stock', labels: const ['Comments (optional)'], confirm: 'Approve & add to stock');
                                  if (v != null && mounted) await _run(() => repo.grvApprove(g.id, me.name, v[0]), 'Approved. Stock added.');
                                },
                          child: const Text('Approve & add to stock'))),
                    ]),
                  ]),
                ),
              ],
            ]);
          },
        ),
      ],
    );
  }
}
