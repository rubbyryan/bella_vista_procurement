import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/state.dart';
import '../../core/widgets.dart';

class PoDetailPage extends ConsumerStatefulWidget {
  const PoDetailPage({super.key, required this.id});
  final int id;
  @override
  ConsumerState<PoDetailPage> createState() => _PoDetailPageState();
}

class _PoDetailPageState extends ConsumerState<PoDetailPage> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() f, String ok) async {
    setState(() => _busy = true);
    await act(context, ref, f, ok);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _receive(Session me, PurchaseOrder o, Map<int, double> received) async {
    final locs = await ref.read(locationsP.future);
    if (!mounted) return;
    if (locs.isEmpty) {
      snack(context, 'No stock locations exist yet.');
      return;
    }
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _GrvDialog(po: o, received: received, locations: locs, me: me),
    );
    if (body == null || !mounted) return;
    await _run(() => ref.read(repoProvider).createGrv(body), 'Goods received voucher created (draft).');
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider);
    if (me == null) return const SizedBox();
    final grvs = ref.watch(grvsP).valueOrNull ?? <Grv>[];
    final repo = ref.read(repoProvider);

    return PageBody(
      title: 'Purchase order',
      actions: [
        OutlinedButton.icon(
          style: canvasOutlined(context),
          onPressed: () => context.go('/app/purchases?tab=orders'),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Back'),
        ),
      ],
      children: [
        AsyncBody<List<PurchaseOrder>>(
          value: ref.watch(posP),
          onRetry: () => ref.invalidate(posP),
          builder: (all) {
            final o = all.where((x) => x.id == widget.id).firstOrNull;
            if (o == null) return const Panel(child: Text('Purchase order not found.'));
            final myGrvs = grvs.where((g) => g.poId == o.id).toList();
            final received = <int, double>{};
            for (final g in myGrvs.where((g) => g.stockAdded)) {
              for (final l in g.lines) {
                received[l.poLineId] = (received[l.poLineId] ?? 0) + l.accepted;
              }
            }
            final canReceive = (me.role == Role.stores || me.role == Role.security) &&
                (o.status == 'ISSUED' || o.status == 'PARTIALLY_RECEIVED') &&
                o.lines.any((l) => l.quantity - (received[l.id] ?? 0) > 0);
            return Column(children: [
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(o.number, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                    StatePill(o.status),
                    Text('Total ${money(o.total)} (tax ${money(o.tax)})'),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 32, runSpacing: 8, children: [
                    Fact('Supplier', o.supplier),
                    Fact('Contact', o.contact),
                    Fact('Purchase request', o.prNumber),
                    Fact('Order date', o.orderDate == null ? '' : dmy(o.orderDate!)),
                    Fact('Expected', o.expected == null ? '' : dmy(o.expected!)),
                    Fact('Deliver to', o.deliveryLocation),
                    Fact('Prepared by', o.preparedBy),
                    Fact('Issued by', o.issuedBy),
                  ]),
                  if (o.terms.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Payment terms: ${o.terms}')),
                  TextButton(onPressed: () => context.go('/app/purchase-requests/${o.prId}'), child: Text('Open ${o.prNumber}')),
                ]),
              ),
              const SizedBox(height: 16),
              Panel(
                title: 'Order lines',
                child: Column(children: [
                  for (final l in o.lines)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.item.label),
                      subtitle: Text('${qty(l.quantity)} ${l.uom} at ${money(l.unitPrice)} | received ${qty(received[l.id] ?? 0)}'),
                      trailing: Text(money(l.total)),
                    ),
                ]),
              ),
              if (o.status == 'DRAFT' && (me.role == Role.stores || me.role == Role.om)) ...[
                const SizedBox(height: 16),
                Panel(
                  title: 'Issue the order',
                  child: Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.end, children: [
                    Builder(builder: (c) => OutlinedButton(
                        style: dangerOutlined(c),
                        onPressed: _busy
                            ? null
                            : () async {
                          final v = await askFields(context,
                              title: 'Cancel purchase order', labels: const ['Reason'], required: const [true], confirm: 'Cancel order', danger: true);
                          if (v != null && mounted) await _run(() => repo.cancelPo(o.id, me.name, v[0]), 'Purchase order cancelled.');
                        },
                        child: const Text('Cancel order'))),
                    Builder(builder: (c) => FilledButton(
                        style: ctaStyle(c),
                        onPressed: _busy ? null : () => _run(() => repo.issuePo(o.id, me.name), 'Purchase order issued.'),
                        child: const Text('Issue to supplier'))),
                  ]),
                ),
              ],
              if (canReceive) ...[
                const SizedBox(height: 16),
                Panel(
                  title: 'Delivery',
                  child: Row(children: [
                    const Expanded(child: Text('Goods arrived? Record the delivery on a Goods Received Voucher (GRV).')),
                    Builder(builder: (c) => FilledButton(
                        style: ctaStyle(c), onPressed: _busy ? null : () => _receive(me, o, received), child: const Text('Receive delivery'))),
                  ]),
                ),
              ],
              if (myGrvs.isNotEmpty) ...[
                const SizedBox(height: 16),
                Panel(
                  title: 'Goods received vouchers',
                  child: Column(children: [
                    for (final g in myGrvs)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => context.go('/app/deliveries/${g.id}'),
                        title: Text('${g.number} | ${g.deliveryNote.isEmpty ? 'no delivery note' : g.deliveryNote}'),
                        subtitle: Text('received by ${g.receivedBy}'),
                        trailing: StatePill(g.status),
                      ),
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

// ---------------------------------------------------------------------------
class _GrvDialog extends StatefulWidget {
  const _GrvDialog({required this.po, required this.received, required this.locations, required this.me});
  final PurchaseOrder po;
  final Map<int, double> received;
  final List<Location> locations;
  final Session me;
  @override
  State<_GrvDialog> createState() => _GrvDialogState();
}

class _GrvDialogState extends State<_GrvDialog> {
  late final _receivedBy = TextEditingController(text: widget.me.role == Role.security ? widget.me.name : '');
  final _dn = TextEditingController();
  final _vehicle = TextEditingController();
  final _driver = TextEditingController();
  final _remarks = TextEditingController();
  DateTime _date = DateTime.now();
  late final Map<int, TextEditingController> _delivered = {};
  late final Map<int, TextEditingController> _accepted = {};
  late final Map<int, TextEditingController> _damaged = {};
  late final Map<int, TextEditingController> _note = {};
  late final Map<int, int> _loc = {};

  @override
  void initState() {
    super.initState();
    for (final l in widget.po.lines) {
      final left = l.quantity - (widget.received[l.id] ?? 0);
      _delivered[l.id] = TextEditingController(text: left > 0 ? qty(left) : '0');
      _accepted[l.id] = TextEditingController(text: left > 0 ? qty(left) : '0');
      _damaged[l.id] = TextEditingController(text: '0');
      _note[l.id] = TextEditingController();
      _loc[l.id] = widget.locations.first.id;
    }
  }

  @override
  void dispose() {
    for (final c in [_receivedBy, _dn, _vehicle, _driver, _remarks, ..._delivered.values, ..._accepted.values, ..._damaged.values, ..._note.values]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _build(List<Map<String, dynamic>> out) {
    for (final l in widget.po.lines) {
      final left = l.quantity - (widget.received[l.id] ?? 0);
      final d = double.tryParse(_delivered[l.id]!.text) ?? 0;
      final a = double.tryParse(_accepted[l.id]!.text) ?? 0;
      final dm = double.tryParse(_damaged[l.id]!.text) ?? 0;
      if (d <= 0) continue;
      if (d > left) return '${l.item.name}: delivered ${qty(d)} is more than the outstanding ${qty(left)}.';
      if (a > d) return '${l.item.name}: accepted cannot exceed delivered.';
      final rej = d - a;
      if (dm > rej) return '${l.item.name}: damaged cannot exceed rejected (${qty(rej)}).';
      if (rej > 0 && _note[l.id]!.text.trim().isEmpty) return '${l.item.name}: say why items were rejected.';
      out.add({
        'purchaseOrderLineId': l.id,
        'stockLocationId': _loc[l.id],
        'quantityDelivered': d,
        'quantityAccepted': a,
        'quantityRejected': rej,
        'quantityDamaged': dm,
        'inspectionRemarks': _note[l.id]!.text.trim(),
        if (rej > 0) 'rejectionReason': _note[l.id]!.text.trim(),
      });
    }
    return out.isEmpty ? 'Enter the delivered quantity for at least one line.' : null;
  }

  @override
  Widget build(BuildContext context) {
    final ok = _receivedBy.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('Receive delivery'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: _receivedBy,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Received by (security / receiving officer) *'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _dn, decoration: const InputDecoration(labelText: 'Delivery note no.'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _vehicle, decoration: const InputDecoration(labelText: 'Vehicle reg.'))),
            ]),
            const SizedBox(height: 8),
            TextField(controller: _driver, decoration: const InputDecoration(labelText: 'Driver name')),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2026), lastDate: DateTime.now().add(const Duration(days: 30)));
                if (d != null) setState(() => _date = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Delivery date', suffixIcon: Icon(Icons.calendar_today_rounded)),
                child: Text(dmy(_date)),
              ),
            ),
            const Divider(height: 24),
            for (final l in widget.po.lines) ...[
              Text('${l.item.label} (ordered ${qty(l.quantity)}, received ${qty(widget.received[l.id] ?? 0)})', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: TextField(controller: _delivered[l.id], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Delivered'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _accepted[l.id], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Accepted'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _damaged[l.id], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Damaged'))),
              ]),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                value: _loc[l.id],
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Store into'),
                items: [for (final x in widget.locations) DropdownMenuItem(value: x.id, child: Text(x.name))],
                onChanged: (v) => setState(() => _loc[l.id] = v ?? _loc[l.id]!),
              ),
              const SizedBox(height: 6),
              TextField(controller: _note[l.id], decoration: const InputDecoration(labelText: 'Inspection remarks / reason if rejected')),
              const SizedBox(height: 14),
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
            final lines = <Map<String, dynamic>>[];
            final err = _build(lines);
            if (err != null) {
              snack(context, err);
              return;
            }
            Navigator.pop(context, {
              'purchaseOrderId': widget.po.id,
              'createdBy': widget.me.name,
              'receivedBy': _receivedBy.text.trim(),
              'deliveryNoteNumber': _dn.text.trim(),
              'deliveryDate': '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
              'vehicleRegistration': _vehicle.text.trim(),
              'driverName': _driver.text.trim(),
              'remarks': _remarks.text.trim(),
              'items': lines,
            });
          },
          child: const Text('Create GRV'),
        ),
      ],
    );
  }
}