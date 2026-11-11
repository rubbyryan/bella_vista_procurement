import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/theme/bv_theme.dart';
import '../../core/widgets.dart';

class DeliveryDetailPage extends ConsumerStatefulWidget {
  const DeliveryDetailPage({super.key, required this.no});
  final String no;
  @override
  ConsumerState<DeliveryDetailPage> createState() => _DeliveryDetailPageState();
}

class _DeliveryDetailPageState extends ConsumerState<DeliveryDetailPage> {
  List<List<Offset>> _strokes = [];
  int _padKey = 0;

  void _sign(Store s, DeliveryNote n, SignStage st) {
    final err = s.signDelivery(n, st, _strokes);
    if (err == null) {
      setState(() {
        _strokes = [];
        _padKey++;
      });
    }
    snack(context, err ?? 'Signed. The next role has been notified.');
  }

  Future<void> _flag(Store s, DeliveryNote n) async {
    final c = await showCommentDialog(context,
        title: 'Flag a problem',
        message: 'Report shortage, damage or a wrong item. A note is required.',
        confirmLabel: 'Flag delivery');
    if (c == null || !mounted) return;
    snack(context, s.flagDelivery(n, c) ?? 'Delivery flagged.');
  }

  Future<void> _receive(Store s, DeliveryNote n) async {
    final r = await showDialog<_Receipt>(context: context, builder: (_) => _ReceiveDialog(n));
    if (r == null || !mounted) return;
    snack(context, s.addToStock(n, r.accepted, r.note) ?? 'Stock updated. Reorder and buffer check has run.');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(storeProvider);
    final u = s.currentUser;
    if (u == null) return const SizedBox();
    final n = s.noteByNo(widget.no);
    if (n == null) {
      return PageBody(title: 'Delivery note not found', children: [
        TextButton(onPressed: () => context.go('/app/deliveries'), child: const Text('Back')),
      ]);
    }
    final next = n.nextStage;

    return PageBody(
      title: n.no,
      subtitle: 'Delivery note | ${n.batchRef}',
      actions: [
        OutlinedButton.icon(
          style: canvasOutlined(context),
          onPressed: () => context.go('/app/deliveries'),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Back'),
        ),
      ],
      children: [
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 32, runSpacing: 8, children: [
              Text('Voucher\n${n.voucherNo}'),
              Text('Requisition\n${n.batchRef}'),
              Text('Supplier\n${n.supplier}'),
              Text('Driver\n${n.driver}'),
              Text('Vehicle\n${n.vehicle}'),
              Text('Date\n${dmy(n.date)}'),
            ]),
            const SizedBox(height: 12),
            StatusChip(n.stageLabel, n.kind),
          ]),
        ),
        if (n.flagNote != null)
          Panel(
            child: Builder(builder: (c) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.warning_amber_rounded, color: Theme.of(c).colorScheme.error),
              const SizedBox(width: 12),
              Expanded(child: Text('Flagged: ${n.flagNote}', style: TextStyle(color: Theme.of(c).colorScheme.error))),
            ])),
          ),
        Panel(
          title: 'Items',
          child: Column(children: [
            for (final d in n.lines)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(d.name),
                subtitle: Text('Ordered ${d.ordered}${n.stockAdded ? ' | Accepted ${d.accepted}' : ''}'),
                trailing: StatusChip(
                    n.stockAdded && d.accepted < d.ordered ? 'Short' : 'Good',
                    n.stockAdded && d.accepted < d.ordered ? StatusKind.danger : StatusKind.success),
              ),
            if (n.receiveNote != null) Align(alignment: Alignment.centerLeft, child: Text('Receiving note: ${n.receiveNote}')),
          ]),
        ),
        for (final st in SignStage.values) _sigBlock(s, u, n, st, next),
        Panel(
          title: 'Rules',
          child: const Text(
              'Sequence is enforced: Security cannot sign before the driver, Stores cannot sign before Security. '
              'Add to stock stays disabled until all three signatures exist. Only the accepted quantity is added; a shortage returns to the requisition as a balance.'),
        ),
        Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.end, children: [
          if ((u.role == Role.security || u.role == Role.stores) && !n.stockAdded)
            OutlinedButton(style: canvasOutlined(context), onPressed: () => _flag(s, n), child: const Text('Flag a problem')),
          if (u.role == Role.stores)
            FilledButton(
              style: ctaStyle(context),
              onPressed: n.fullySigned && !n.stockAdded ? () => _receive(s, n) : null,
              child: const Text('Add to stock'),
            ),
        ]),
      ],
    );
  }

  Widget _sigBlock(Store s, AppUser u, DeliveryNote n, SignStage st, SignStage? next) {
    final sig = n.sigs[st];
    final canSign = sig == null && next == st && u.role == st.role;
    final action = switch (st) {
      SignStage.driver => 'Confirm & dispatch',
      SignStage.security => 'Sign gate inspection',
      SignStage.stores => 'Sign goods received',
    };
    return Panel(
      title: '${st.index + 1}. ${st.title}',
      trailing: sig != null
          ? const StatusChip('Signed', StatusKind.success)
          : const StatusChip('Awaiting', StatusKind.pending),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (sig != null) ...[
          SignatureView(sig.strokes),
          const SizedBox(height: 8),
          Text('${sig.name} (${sig.role}) | ${stamp(sig.at)}'),
        ] else if (canSign) ...[
          SignaturePad(key: ValueKey('$_padKey${st.name}'), onChanged: (v) => setState(() => _strokes = v)),
          const SizedBox(height: 4),
          const Text('Auto-added: name, role and time stamp'),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _strokes.isEmpty ? null : () => _sign(s, n, st),
              child: Text(action),
            ),
          ),
        ] else
          Text(next == st
              ? 'Waiting for the ${st.role.label} to sign.'
              : 'Waiting for the previous signature.'),
      ]),
    );
  }
}

class _Receipt {
  _Receipt(this.accepted, this.note);
  final Map<int, int> accepted;
  final String note;
}

class _ReceiveDialog extends StatefulWidget {
  const _ReceiveDialog(this.n);
  final DeliveryNote n;
  @override
  State<_ReceiveDialog> createState() => _ReceiveDialogState();
}

class _ReceiveDialogState extends State<_ReceiveDialog> {
  late final Map<int, int> _acc = {for (var i = 0; i < widget.n.lines.length; i++) i: widget.n.lines[i].ordered};
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _short => [for (var i = 0; i < widget.n.lines.length; i++) _acc[i]! < widget.n.lines[i].ordered].any((x) => x);

  @override
  Widget build(BuildContext context) {
    final ok = !_short || _note.text.trim().length >= 10;
    return AlertDialog(
      title: const Text('Goods received'),
      content: BVSurface(
        child: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Count against the delivery note. Only the accepted quantity is added to stock.'),
              const SizedBox(height: 8),
              for (var i = 0; i < widget.n.lines.length; i++)
                Row(children: [
                  Expanded(child: Text('${widget.n.lines[i].name} (of ${widget.n.lines[i].ordered})')),
                  QtyStepper(
                    value: _acc[i]!,
                    min: 0,
                    max: widget.n.lines[i].ordered,
                    onChanged: (v) => setState(() => _acc[i] = v),
                  ),
                ]),
              if (_short) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _note,
                  minLines: 2,
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Shortage note *', hintText: 'Min 10 characters'),
                ),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: ok ? () => Navigator.pop(context, _Receipt(Map.of(_acc), _note.text)) : null,
          child: const Text('Add to stock'),
        ),
      ],
    );
  }
}
