import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/state.dart';
import '../../core/theme/bv_theme.dart';
import '../../core/widgets.dart';
import '../issuing/issue_stock_dialog.dart';

/// Item requisition. Backend flow (ItemRequisitionService):
/// NEW > STORES_REVIEW > PENDING_HEAD_APPROVAL > PENDING_OM_APPROVAL > READY_FOR_ISSUE > RESOLVED.
/// Stock is issued (issue note, stock movement) only after Head AND Operations Manager approve.
class RequisitionDetailPage extends ConsumerStatefulWidget {
  const RequisitionDetailPage({super.key, required this.id});
  final int id;
  @override
  ConsumerState<RequisitionDetailPage> createState() => _RequisitionDetailPageState();
}

class _RequisitionDetailPageState extends ConsumerState<RequisitionDetailPage> {
  final _comment = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f, String ok) async {
    setState(() => _busy = true);
    final done = await act(context, ref, f, ok);
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) _comment.clear();
  }

  List<StepInfo> _steps(Requisition r) {
    final s = r.status;
    BVStepState st(int idx, int cur) => idx < cur ? BVStepState.done : (idx == cur ? BVStepState.current : BVStepState.todo);
    if (s == 'REJECTED') {
      final at = r.omBy != null ? 2 : 1;
      return [
        for (var i = 0; i < 4; i++)
          StepInfo(['Stores', 'Head', 'OM', 'Issue'][i], i < at ? BVStepState.done : (i == at ? BVStepState.rejected : BVStepState.todo)),
      ];
    }
    final cur = switch (s) {
      'NEW' || 'STORES_REVIEW' => 0,
      'PENDING_HEAD_APPROVAL' => 1,
      'PENDING_OM_APPROVAL' => 2,
      'READY_FOR_ISSUE' || 'PARTIALLY_ISSUED' => 3,
      _ => 4,
    };
    return [for (var i = 0; i < 4; i++) StepInfo(['Stores', 'Head', 'OM', 'Issue'][i], st(i, cur))];
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider);
    if (me == null) return const SizedBox();
    final one = ref.watch(requisitionByIdP(widget.id));
    final issues = ref.watch(issuesByRequisitionP(widget.id)).valueOrNull ?? <StockIssue>[]; // GET /stock-issues/requisition/{id}
    final prs = ref.watch(prsP).valueOrNull ?? <PurchaseRequest>[];
    final bal = ref.watch(balancesP).valueOrNull ?? <Balance>[];

    return PageBody(
      title: 'Requisition',
      actions: [
        OutlinedButton.icon(
          style: canvasOutlined(context),
          onPressed: () => context.go('/app/requisitions'),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Back'),
        ),
      ],
      children: [
        AsyncBody<Requisition>(
          value: one,
          onRetry: () => ref.invalidate(requisitionByIdP(widget.id)),
          builder: (r) {
            if (me.role == Role.requester && r.officer.trim().toLowerCase() != me.name.trim().toLowerCase()) {
              return const Panel(child: Text('You can only view your own requisitions.'));
            }
            return _body(me, r, issues,
                prs.where((p) => p.requisitionId == r.id).firstOrNull, onHandByItem(bal));
          },
        ),
      ],
    );
  }

  Widget _body(Session me, Requisition r, List<StockIssue> issues, PurchaseRequest? pr, Map<int, double> onHand) {
    final issuedByLine = <int, double>{};
    for (final i in issues) {
      for (final l in i.lines) {
        issuedByLine[l.requisitionLineId] = (issuedByLine[l.requisitionLineId] ?? 0) + l.qty;
      }
    }
    double remaining(ReqLine l) => remainingToIssue(l, issuedByLine[l.id] ?? 0);

    final reviewing = r.status == 'NEW' || r.status == 'STORES_REVIEW';
    final canIssue = (r.status == 'READY_FOR_ISSUE' || r.status == 'PARTIALLY_ISSUED') &&
        r.lines.any((l) => remaining(l) > 0);

    return Column(children: [
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(r.number, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            StatePill(r.status),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 32, runSpacing: 8, children: [
            Fact('Department', r.department),
            Fact('Requested by', r.officer),
            Fact('Date', r.date == null ? '' : dmy(r.date!)),
            Fact('Stock controller', r.stockController),
          ]),
          const SizedBox(height: 12),
          Text(r.purpose),
        ]),
      ),
      const SizedBox(height: 16),
      Panel(title: 'Progress', child: ChainStepper(_steps(r))),
      if (r.headBy != null || r.omBy != null) ...[
        const SizedBox(height: 16),
        Panel(
          title: 'Approvals',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (r.headBy != null)
              Text('Headmaster: ${r.headBy}${r.headDate == null ? '' : ' (${stamp(r.headDate!)})'}${r.headComments == null ? '' : ' - "${r.headComments}"'}'),
            if (r.omBy != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Operations Manager: ${r.omBy}${r.omDate == null ? '' : ' (${stamp(r.omDate!)})'}${r.omComments == null ? '' : ' - "${r.omComments}"'}'),
              ),
          ]),
        ),
      ],
      const SizedBox(height: 16),
      Panel(
        title: 'Items',
        child: Column(children: [
          for (var i = 0; i < r.lines.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _lineRow(r.lines[i], issuedByLine[r.lines[i].id] ?? 0, onHand[r.lines[i].item.id]),
          ],
        ]),
      ),
      if (reviewing && me.role == Role.stores) ...[
        const SizedBox(height: 16),
        _ReviewPanel(r: r, onHand: onHand, me: me),
      ],
      if (r.status == 'PENDING_HEAD_APPROVAL' && me.role == Role.head) ...[
        const SizedBox(height: 16),
        _decision('Headmaster decision', 'Approve & send to OM',
                (c) => ref.read(repoProvider).headApprove(r.id, me.name, c),
                (c) => ref.read(repoProvider).headReject(r.id, me.name, c)),
      ],
      if (r.status == 'PENDING_OM_APPROVAL' && me.role == Role.om) ...[
        const SizedBox(height: 16),
        _decision('Operations Manager decision', 'Approve for issue',
                (c) => ref.read(repoProvider).omApprove(r.id, me.name, c),
                (c) => ref.read(repoProvider).omReject(r.id, me.name, c)),
      ],
      if (me.role == Role.stores) ...[
        const SizedBox(height: 16),
        Panel(
          title: 'Issue from stock',
          child: Row(children: [
            Expanded(child: Text(_issueNote(r, canIssue))),
            // The button only works once the Headmaster and the Operations Manager have approved.
            Builder(builder: (c) => FilledButton.icon(
                style: ctaStyle(c),
                onPressed: (_busy || !canIssue) ? null : () => _issue(me, r, issuedByLine),
                icon: const Icon(Icons.outbox_rounded),
                label: const Text('Issue stock'))),
          ]),
        ),
      ],
      if (r.hasShortage && r.allVerified) ...[
        const SizedBox(height: 16),
        Panel(
          title: 'Purchase request (items not in stock)',
          child: pr != null
              ? Row(children: [
            Expanded(child: Text('${pr.number} | ${money(pr.total)}')),
            StatePill(pr.status),
            TextButton(onPressed: () => context.go('/app/purchase-requests/${pr.id}'), child: const Text('Open')),
          ])
              : Row(children: [
            const Expanded(child: Text('Some items are not in stock. The Stores Controller raises a purchase request that references this requisition.')),
            if (me.role == Role.stores)
              Builder(builder: (c) => FilledButton(
                  style: ctaStyle(c), onPressed: _busy ? null : () => _raisePr(me, r), child: const Text('Raise purchase request'))),
          ]),
        ),
      ],
      if (issues.isNotEmpty) ...[
        const SizedBox(height: 16),
        Panel(
          title: 'Issue notes',
          child: Column(children: [
            for (final i in issues)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${i.number} | issued by ${i.issuedBy}, received by ${i.receivedBy}'),
                subtitle: Text('${i.date == null ? '' : stamp(i.date!)} | ${i.lines.map((l) => '${qty(l.qty)} ${l.item.name} (${l.location})').join(', ')}'),
              ),
          ]),
        ),
      ],
    ]);
  }

  Widget _lineRow(ReqLine l, double issued, double? have) {
    return Builder(builder: (c) {
      final t = Theme.of(c);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(l.item.label, style: t.textTheme.titleMedium?.copyWith(fontSize: 14))),
            Text('x${l.quantity} ${l.uom}'),
          ]),
          if (l.description.isNotEmpty) Text(l.description, style: t.textTheme.labelSmall),
          const SizedBox(height: 4),
          Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (l.verified) ...[
              Text('Available ${l.available}', style: t.textTheme.labelSmall),
              StatusChip('Recommended ${l.recommended}', StatusKind.inProgress),
              if ((l.shortage ?? 0) > 0) StatusChip('Shortage ${l.shortage}', StatusKind.danger),
            ] else
              Text(have == null ? '' : 'On hand ${qty(have)}', style: t.textTheme.labelSmall),
            if (issued > 0) StatusChip('Issued ${qty(issued)}', StatusKind.success),
            if (l.remarks.isNotEmpty) Text('Stores: ${l.remarks}', style: t.textTheme.labelSmall),
          ]),
        ]),
      );
    });
  }

  Widget _decision(String title, String approveLabel, Future<void> Function(String) approve, Future<void> Function(String) reject) {
    return Panel(
      title: title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _comment,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Your comment (optional for approval)'),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.end, children: [
          Builder(builder: (c) => OutlinedButton(
              style: dangerOutlined(c),
              onPressed: _busy
                  ? null
                  : () async {
                final v = await showCommentDialog(context,
                    title: 'Reject requisition',
                    message: 'Tell the requester why. A comment is required.',
                    quickReasons: const ['Budget not available', 'Duplicate request', 'Need more information', 'Not a priority now']);
                if (v != null && mounted) await _run(() => reject(v), 'Rejected.');
              },
              child: const Text('Reject'))),
          Builder(builder: (c) => FilledButton(
              style: ctaStyle(c),
              onPressed: _busy ? null : () => _run(() => approve(_comment.text), 'Approved.'),
              child: Text(approveLabel))),
        ]),
      ]),
    );
  }

  /// Why the issue button is on or off.
  String _issueNote(Requisition r, bool canIssue) {
    if (canIssue) {
      return 'Approved by the Headmaster and the Operations Manager. Issue the items and record who received them (issue note).';
    }
    return switch (r.status) {
      'NEW' || 'STORES_REVIEW' => 'Review the stock and submit the requisition for approval first.',
      'PENDING_HEAD_APPROVAL' => 'Waiting for the Headmaster to approve. Stock can only be issued after approval.',
      'PENDING_OM_APPROVAL' => 'Waiting for the Operations Manager to approve. Stock can only be issued after approval.',
      'REJECTED' => 'This requisition was rejected, so nothing can be issued.',
      'RESOLVED' => 'Everything on this requisition has been issued.',
      'READY_FOR_ISSUE' || 'PARTIALLY_ISSUED' => 'Nothing is left to issue on this requisition.',
      _ => 'Stock cannot be issued for this requisition.',
    };
  }

  Future<void> _issue(Session me, Requisition r, Map<int, double> issuedByLine) async {
    final List<Balance> balances;
    try {
      balances = await ref.read(balancesP.future);
    } catch (e) {
      if (mounted) snack(context, 'Could not load stock balances: $e');
      return;
    }
    if (!mounted) return;
    final res = await showIssueStockDialog(context, requisition: r, issuedByLine: issuedByLine, balances: balances);
    if (res == null || !mounted) return;
    await _run(() => ref.read(repoProvider).issueStock(r.id, me.name, res.receivedBy, res.remarks, res.lines),
        'Stock issued. The issue note is listed below.');
  }

  Future<void> _raisePr(Session me, Requisition r) async {
    // group shortages by item (the backend allows one line per item)
    final short = <int, (Item, int)>{};
    for (final l in r.lines) {
      final s = l.shortage ?? 0;
      if (s > 0) short[l.item.id] = (l.item, (short[l.item.id]?.$2 ?? 0) + s);
    }
    final res = await showDialog<_PrResult>(
      context: context,
      builder: (_) => _PrDialog(short: short.values.toList(), purpose: r.purpose),
    );
    if (res == null || !mounted) return;
    await _run(
            () => ref.read(repoProvider).createPurchaseRequest(
            requisitionId: r.id, by: me.name, justification: res.justification, items: res.items),
        'Purchase request raised. The Operations Manager now submits it for directorate approval.');
  }
}

// ---------------------------------------------------------------------------
// Stores review: availability and recommended issue quantity per line
// ---------------------------------------------------------------------------
class _ReviewPanel extends ConsumerStatefulWidget {
  const _ReviewPanel({required this.r, required this.onHand, required this.me});
  final Requisition r;
  final Map<int, double> onHand;
  final Session me;
  @override
  ConsumerState<_ReviewPanel> createState() => _ReviewPanelState();
}

class _ReviewPanelState extends ConsumerState<_ReviewPanel> {
  late final Map<int, TextEditingController> _avail = {};
  late final Map<int, TextEditingController> _rec = {};
  late final Map<int, TextEditingController> _note = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final l in widget.r.lines) {
      final have = (widget.onHand[l.item.id] ?? 0).floor();
      final a = l.available ?? have;
      final rec = l.recommended ?? (a < l.quantity ? a : l.quantity);
      _avail[l.id] = TextEditingController(text: '$a');
      _rec[l.id] = TextEditingController(text: '$rec');
      _note[l.id] = TextEditingController(text: l.remarks);
    }
  }

  @override
  void dispose() {
    for (final c in [..._avail.values, ..._rec.values, ..._note.values]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate() {
    for (final l in widget.r.lines) {
      final a = int.tryParse(_avail[l.id]!.text);
      final c = int.tryParse(_rec[l.id]!.text);
      if (a == null || c == null || a < 0 || c < 0) return 'Enter available and recommended quantities for every item.';
      if (c > a) return 'Recommended quantity cannot exceed available stock (${l.item.name}).';
      if (c > l.quantity) return 'Recommended quantity cannot exceed the requested quantity (${l.item.name}).';
    }
    return null;
  }

  Future<void> _save({required bool submit}) async {
    final err = _validate();
    if (err != null) {
      snack(context, err);
      return;
    }
    setState(() => _busy = true);
    final repo = ref.read(repoProvider);
    final lines = [
      for (final l in widget.r.lines)
        {
          'requisitionLineId': l.id,
          'quantityAvailable': int.parse(_avail[l.id]!.text),
          'quantityRecommended': int.parse(_rec[l.id]!.text),
          'storesRemarks': _note[l.id]!.text.trim(),
        }
    ];
    await act(context, ref, () async {
      await repo.storesReview(widget.r.id, widget.me.name, lines);
      if (submit) await repo.submitRequisition(widget.r.id, widget.me.name);
    }, submit ? 'Sent to the Headmaster for approval.' : 'Stores review saved.');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Stores review',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Check each item against stock. Quantity recommended for issue is what the approvers will see; any shortage becomes a purchase request.'),
        const SizedBox(height: 12),
        for (final l in widget.r.lines)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${l.item.label} | requested ${l.quantity} ${l.uom}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 12, runSpacing: 8, children: [
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _avail[l.id],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Available'),
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _rec[l.id],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Recommended'),
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(controller: _note[l.id], decoration: const InputDecoration(labelText: 'Stores remarks')),
                ),
              ]),
            ]),
          ),
        Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.end, children: [
          OutlinedButton(onPressed: _busy ? null : () => _save(submit: false), child: const Text('Save review')),
          FilledButton(
            style: ctaStyle(context),
            onPressed: _busy ? null : () => _save(submit: true),
            child: const Text('Save & send for approval'),
          ),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Purchase request dialog (shortage lines only)
// ---------------------------------------------------------------------------
class _PrResult {
  _PrResult(this.justification, this.items);
  final String justification;
  final List<Map<String, dynamic>> items;
}

class _PrDialog extends StatefulWidget {
  const _PrDialog({required this.short, required this.purpose});
  final List<(Item, int)> short;
  final String purpose;
  @override
  State<_PrDialog> createState() => _PrDialogState();
}

class _PrDialogState extends State<_PrDialog> {
  late final _just = TextEditingController(text: 'Items not in stock. ${widget.purpose}');
  late final Map<int, TextEditingController> _price = {for (final e in widget.short) e.$1.id: TextEditingController()};

  @override
  void dispose() {
    _just.dispose();
    for (final c in _price.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _price.values.every((c) => double.tryParse(c.text) != null);
    var total = 0.0;
    for (final e in widget.short) {
      total += e.$2 * (double.tryParse(_price[e.$1.id]!.text) ?? 0);
    }
    return AlertDialog(
      title: const Text('Raise purchase request'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final e in widget.short) ...[
              Text('${e.$1.label}: buy ${e.$2} ${e.$1.uom}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _price[e.$1.id],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Estimated unit price (USD) *'),
              ),
              const SizedBox(height: 12),
            ],
            TextField(controller: _just, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Justification')),
            const SizedBox(height: 8),
            Text('Estimated total ${money(total)}${total >= 1000 ? ' (RA approval needed at USD 1,000 or more)' : ''}'),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: !ok
              ? null
              : () => Navigator.pop(
              context,
              _PrResult(_just.text.trim(), [
                for (final e in widget.short)
                  {'itemId': e.$1.id, 'quantity': e.$2, 'estimatedUnitPrice': double.parse(_price[e.$1.id]!.text)}
              ])),
          child: const Text('Raise request'),
        ),
      ],
    );
  }
}