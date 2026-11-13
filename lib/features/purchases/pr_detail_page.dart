import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/state.dart';
import '../../core/widgets.dart';

class PrDetailPage extends ConsumerStatefulWidget {
  const PrDetailPage({super.key, required this.id});
  final int id;
  @override
  ConsumerState<PrDetailPage> createState() => _PrDetailPageState();
}

class _PrDetailPageState extends ConsumerState<PrDetailPage> {
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

  List<StepInfo> _steps(PurchaseRequest p) {
    final s = p.status;
    final returned = s == 'RETURNED_TO_OM';
    final early = s == 'DRAFT' || returned;
    BVStepState od(String? by, String? rej) {
      if (early) return rej != null && returned ? BVStepState.rejected : BVStepState.todo;
      if (s == 'CANCELLED') return BVStepState.todo;
      return by != null ? BVStepState.done : BVStepState.current;
    }

    final steps = <StepInfo>[
      StepInfo('OM', early ? BVStepState.current : BVStepState.done),
      StepInfo('OD1', od(p.od1By, p.od1RejBy)),
      StepInfo('OD2', od(p.od2By, p.od2RejBy)),
    ];
    if (p.needsRa || p.raBy != null || s == 'PENDING_RA_APPROVAL') {
      steps.add(StepInfo(
          'RA',
          s == 'PENDING_RA_APPROVAL'
              ? BVStepState.current
              : (p.raBy != null || s == 'APPROVED' || s == 'CONVERTED_TO_PO' ? BVStepState.done : BVStepState.todo)));
    }
    return steps;
  }

  Future<void> _createPo(Session me, PurchaseRequest p, Map<int, double> ordered) async {
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PoDialog(pr: p, ordered: ordered, me: me.name),
    );
    if (res == null || !mounted) return;
    await _run(() => ref.read(repoProvider).createPurchaseOrder(res), 'Purchase order created (draft). Issue it to send it to the supplier.');
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider);
    if (me == null) return const SizedBox();
    final orders = ref.watch(posP).valueOrNull ?? <PurchaseOrder>[];

    return PageBody(
      title: 'Purchase request',
      actions: [
        OutlinedButton.icon(
          style: canvasOutlined(context),
          onPressed: () => context.go('/app/purchases'),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Back'),
        ),
      ],
      children: [
        AsyncBody<List<PurchaseRequest>>(
          value: ref.watch(prsP),
          onRetry: () => ref.invalidate(prsP),
          builder: (all) {
            final p = all.where((x) => x.id == widget.id).firstOrNull;
            if (p == null) return const Panel(child: Text('Purchase request not found.'));
            final myOrders = orders.where((o) => o.prId == p.id && o.status != 'CANCELLED').toList();
            // quantity already ordered per PR line
            final ordered = <int, double>{};
            for (final o in myOrders) {
              for (final l in o.lines) {
                ordered[l.prLineId] = (ordered[l.prLineId] ?? 0) + l.quantity;
              }
            }
            final canPo = me.role == Role.stores &&
                (p.status == 'APPROVED' || p.status == 'CONVERTED_TO_PO') &&
                p.lines.any((l) => l.quantity - (ordered[l.id] ?? 0) > 0);
            return _body(me, p, myOrders, ordered, canPo);
          },
        ),
      ],
    );
  }

  Widget _body(Session me, PurchaseRequest p, List<PurchaseOrder> myOrders, Map<int, double> ordered, bool canPo) {
    Widget decision(String title, Future<void> Function(String) approve, Future<void> Function(String) reject) => Panel(
      title: title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: _comment, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Your comment (optional for approval)')),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.end, children: [
          Builder(builder: (c) => OutlinedButton(
              style: dangerOutlined(c),
              onPressed: _busy
                  ? null
                  : () async {
                final v = await showCommentDialog(context,
                    title: 'Reject purchase request', message: 'A comment is required. The request goes back to the Operations Manager.');
                if (v != null && mounted) await _run(() => reject(v), 'Rejected. Returned to the Operations Manager.');
              },
              child: const Text('Reject'))),
          Builder(builder: (c) => FilledButton(
              style: ctaStyle(c),
              onPressed: _busy ? null : () => _run(() => approve(_comment.text), 'Approved.'),
              child: const Text('Approve'))),
        ]),
      ]),
    );

    final repo = ref.read(repoProvider);
    return Column(children: [
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(p.number, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            StatePill(p.status),
            Text('Total ${money(p.total)}${p.needsRa ? ' (RA approval needed)' : ''}'),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 32, runSpacing: 8, children: [
            Fact('Requisition', p.requisitionNumber),
            Fact('Requested by', p.requestedBy),
            Fact('Department', p.department),
            Fact('Date', p.date == null ? '' : dmy(p.date!)),
          ]),
          const SizedBox(height: 12),
          Text(p.justification),
          if (p.requisitionId != 0)
            TextButton(onPressed: () => context.go('/app/requisitions/${p.requisitionId}'), child: Text('Open ${p.requisitionNumber}')),
        ]),
      ),
      const SizedBox(height: 16),
      Panel(
        title: 'Approvals',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ChainStepper(_steps(p)),
          const SizedBox(height: 8),
          if (p.omBy != null) Text('Operations Manager: ${p.omBy}${p.omDate == null ? '' : ' (${stamp(p.omDate!)})'}${p.omComments == null ? '' : ' - "${p.omComments}"'}'),
          if (p.od1By != null) Text('OD1: ${p.od1By}${p.od1Date == null ? '' : ' (${stamp(p.od1Date!)})'}${p.od1Comments == null ? '' : ' - "${p.od1Comments}"'}'),
          if (p.od2By != null) Text('OD2: ${p.od2By}${p.od2Date == null ? '' : ' (${stamp(p.od2Date!)})'}${p.od2Comments == null ? '' : ' - "${p.od2Comments}"'}'),
          if (p.raBy != null) Text('RA: ${p.raBy}${p.raDate == null ? '' : ' (${stamp(p.raDate!)})'}${p.raComments == null ? '' : ' - "${p.raComments}"'}'),
          Builder(builder: (c) {
            final e = Theme.of(c).colorScheme.error;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (p.od1RejBy != null) Text('Rejected by OD1 (${p.od1RejBy}): "${p.od1RejComments ?? ''}"', style: TextStyle(color: e)),
              if (p.od2RejBy != null) Text('Rejected by OD2 (${p.od2RejBy}): "${p.od2RejComments ?? ''}"', style: TextStyle(color: e)),
              if (p.raRejBy != null) Text('Rejected by RA (${p.raRejBy}): "${p.raRejComments ?? ''}"', style: TextStyle(color: e)),
            ]);
          }),
        ]),
      ),
      const SizedBox(height: 16),
      Panel(
        title: 'Items to buy',
        child: Column(children: [
          for (final l in p.lines)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(l.item.label),
              subtitle: Text('${qty(l.quantity)} ${l.uom} at ${money(l.unitPrice)}${(ordered[l.id] ?? 0) > 0 ? ' | ordered ${qty(ordered[l.id]!)}' : ''}'),
              trailing: Text(money(l.total)),
            ),
        ]),
      ),
      if (me.role == Role.om && (p.status == 'DRAFT' || p.status == 'RETURNED_TO_OM')) ...[
        const SizedBox(height: 16),
        Panel(
          title: 'Operations Manager',
          child: Row(children: [
            const Expanded(child: Text('Review the request, then submit it to OD1 and OD2 for approval.')),
            Builder(builder: (c) => FilledButton(
                style: ctaStyle(c),
                onPressed: _busy
                    ? null
                    : () async {
                  final v = await askFields(context, title: 'Submit for directorate approval', labels: const ['Comments (optional)']);
                  if (v != null && mounted) {
                    await _run(() => repo.submitDirectorate(p.id, me.name, v[0]), 'Submitted to OD1 and OD2.');
                  }
                },
                child: const Text('Submit to directorate'))),
          ]),
        ),
      ],
      if (me.role == Role.od1 && p.status == 'PENDING_DIRECTORATE_APPROVAL' && p.od1By == null) ...[
        const SizedBox(height: 16),
        decision('OD1 decision', (c) => repo.od1Approve(p.id, me.name, c), (c) => repo.od1Reject(p.id, me.name, c)),
      ],
      if (me.role == Role.od2 && p.status == 'PENDING_DIRECTORATE_APPROVAL' && p.od2By == null) ...[
        const SizedBox(height: 16),
        decision('OD2 decision', (c) => repo.od2Approve(p.id, me.name, c), (c) => repo.od2Reject(p.id, me.name, c)),
      ],
      if (me.role == Role.ra && p.status == 'PENDING_RA_APPROVAL') ...[
        const SizedBox(height: 16),
        decision('Responsible Authority decision', (c) => repo.raApprove(p.id, me.name, c), (c) => repo.raReject(p.id, me.name, c)),
      ],
      if (canPo) ...[
        const SizedBox(height: 16),
        Panel(
          title: 'Purchase order',
          child: Row(children: [
            const Expanded(child: Text('Approved. Create the purchase order for the supplier.')),
            Builder(builder: (c) => FilledButton(
                style: ctaStyle(c), onPressed: _busy ? null : () => _createPo(me, p, ordered), child: const Text('Create purchase order'))),
          ]),
        ),
      ],
      if (myOrders.isNotEmpty) ...[
        const SizedBox(height: 16),
        Panel(
          title: 'Purchase orders',
          child: Column(children: [
            for (final o in myOrders)
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => context.go('/app/purchase-orders/${o.id}'),
                title: Text('${o.number} | ${o.supplier}'),
                subtitle: Text(money(o.total)),
                trailing: StatePill(o.status),
              ),
          ]),
        ),
      ],
    ]);
  }
}

// ---------------------------------------------------------------------------
class _PoDialog extends StatefulWidget {
  const _PoDialog({required this.pr, required this.ordered, required this.me});
  final PurchaseRequest pr;
  final Map<int, double> ordered;
  final String me;
  @override
  State<_PoDialog> createState() => _PoDialogState();
}

class _PoDialogState extends State<_PoDialog> {
  final _supplier = TextEditingController();
  final _contact = TextEditingController();
  final _address = TextEditingController();
  final _location = TextEditingController(text: 'Bella Vista College, Mazowe');
  final _terms = TextEditingController();
  final _remarks = TextEditingController();
  final _tax = TextEditingController(text: '0');
  DateTime? _expected;
  late final Map<int, TextEditingController> _qty = {
    for (final l in widget.pr.lines) l.id: TextEditingController(text: qty(l.quantity - (widget.ordered[l.id] ?? 0))),
  };
  late final Map<int, TextEditingController> _price = {
    for (final l in widget.pr.lines) l.id: TextEditingController(text: l.unitPrice.toStringAsFixed(2)),
  };

  @override
  void dispose() {
    for (final c in [_supplier, _contact, _address, _location, _terms, _remarks, _tax, ..._qty.values, ..._price.values]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _supplier.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('Create purchase order'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: _supplier, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Supplier name *')),
            const SizedBox(height: 8),
            TextField(controller: _contact, decoration: const InputDecoration(labelText: 'Supplier contact')),
            const SizedBox(height: 8),
            TextField(controller: _address, decoration: const InputDecoration(labelText: 'Supplier address')),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                    context: context, initialDate: DateTime.now().add(const Duration(days: 7)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) setState(() => _expected = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Expected delivery', suffixIcon: Icon(Icons.calendar_today_rounded)),
                child: Text(_expected == null ? 'Not set' : dmy(_expected!)),
              ),
            ),
            const SizedBox(height: 8),
            TextField(controller: _location, decoration: const InputDecoration(labelText: 'Delivery location')),
            const SizedBox(height: 8),
            TextField(controller: _terms, decoration: const InputDecoration(labelText: 'Payment terms')),
            const SizedBox(height: 8),
            TextField(controller: _tax, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Tax amount (USD)')),
            const Divider(height: 24),
            for (final l in widget.pr.lines) ...[
              Text(l.item.label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: TextField(controller: _qty[l.id], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Quantity (${l.uom})'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _price[l.id], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Unit price'))),
              ]),
              const SizedBox(height: 10),
            ],
            TextField(controller: _remarks, decoration: const InputDecoration(labelText: 'Remarks')),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: !ok
              ? null
              : () {
            final items = <Map<String, dynamic>>[];
            for (final l in widget.pr.lines) {
              final q = double.tryParse(_qty[l.id]!.text) ?? 0;
              if (q > 0) {
                items.add({
                  'purchaseRequestLineId': l.id,
                  'quantity': q,
                  'unitPrice': double.tryParse(_price[l.id]!.text) ?? l.unitPrice,
                });
              }
            }
            Navigator.pop(context, {
              'purchaseRequestId': widget.pr.id,
              'supplierName': _supplier.text.trim(),
              'supplierContact': _contact.text.trim(),
              'supplierAddress': _address.text.trim(),
              if (_expected != null) 'expectedDeliveryDate': '${_expected!.year.toString().padLeft(4, '0')}-${_expected!.month.toString().padLeft(2, '0')}-${_expected!.day.toString().padLeft(2, '0')}',
              'deliveryLocation': _location.text.trim(),
              'paymentTerms': _terms.text.trim(),
              'remarks': _remarks.text.trim(),
              'preparedBy': widget.me,
              'taxAmount': double.tryParse(_tax.text) ?? 0,
              'items': items,
            });
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}