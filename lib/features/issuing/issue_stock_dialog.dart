import 'package:flutter/material.dart';

import '../../core/models.dart';

/// What the Stores Controller entered in the issue dialog.
class IssueSubmission {
  IssueSubmission(this.receivedBy, this.remarks, this.lines);
  final String receivedBy;
  final String remarks;

  /// Body for POST /stock-issues/requisition/{id}.
  final List<Map<String, dynamic>> lines;
}

/// How much of a requisition line can still be issued: the smaller of the
/// requested and the Stores-recommended quantity, minus what was already issued.
/// This is the same rule the backend applies.
double remainingToIssue(ReqLine l, double alreadyIssued) {
  final recommended = (l.recommended ?? 0).toDouble();
  final cap = recommended < l.quantity ? recommended : l.quantity.toDouble();
  return cap - alreadyIssued;
}

/// Issue stock against an approved requisition.
///
/// Each line can only be issued from a location that holds stock of that item,
/// and the quantity is limited to what is still owed and what is on hand there.
Future<IssueSubmission?> showIssueStockDialog(
  BuildContext context, {
  required Requisition requisition,
  required Map<int, double> issuedByLine,
  required List<Balance> balances,
}) {
  return showDialog<IssueSubmission>(
    context: context,
    builder: (_) => _IssueDialog(requisition: requisition, issuedByLine: issuedByLine, balances: balances),
  );
}

class _Row {
  _Row(this.line, this.remaining, this.options);
  final ReqLine line;
  final double remaining;
  final List<Balance> options; // locations holding stock of this item, most stock first
  final qty = TextEditingController();
  int? locationId;

  double get available {
    for (final b in options) {
      if (b.location.id == locationId) return b.qty;
    }
    return 0;
  }

  double get max => remaining < available ? remaining : available;
}

class _IssueDialog extends StatefulWidget {
  const _IssueDialog({required this.requisition, required this.issuedByLine, required this.balances});
  final Requisition requisition;
  final Map<int, double> issuedByLine;
  final List<Balance> balances;

  @override
  State<_IssueDialog> createState() => _IssueDialogState();
}

class _IssueDialogState extends State<_IssueDialog> {
  late final List<_Row> _rows;
  final _received = TextEditingController();
  final _remarks = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rows = [];
    for (final l in widget.requisition.lines) {
      final remaining = remainingToIssue(l, widget.issuedByLine[l.id] ?? 0);
      if (remaining <= 0) continue;
      final options = widget.balances.where((b) => b.item.id == l.item.id && b.qty > 0).toList()
        ..sort((a, b) => b.qty.compareTo(a.qty));
      final row = _Row(l, remaining, options);
      if (options.isNotEmpty) {
        row.locationId = options.first.location.id;
        row.qty.text = qty(row.max);
      }
      _rows.add(row);
    }
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.qty.dispose();
    }
    _received.dispose();
    _remarks.dispose();
    super.dispose();
  }

  /// Null when the row is fine (or skipped), otherwise a message.
  String? _error(_Row r) {
    final text = r.qty.text.trim();
    if (text.isEmpty) return null; // skipped
    final q = double.tryParse(text);
    if (q == null || q < 0) return 'Enter a number';
    if (q > r.max + 1e-9) {
      return r.remaining < r.available
          ? 'At most ${qty(r.remaining)} is still owed'
          : 'Only ${qty(r.available)} on hand here';
    }
    return null;
  }

  double _entered(_Row r) => double.tryParse(r.qty.text.trim()) ?? 0;

  bool get _valid =>
      _received.text.trim().isNotEmpty &&
      _rows.any((r) => _entered(r) > 0) &&
      _rows.every((r) => _error(r) == null);

  void _submit() {
    final lines = <Map<String, dynamic>>[
      for (final r in _rows)
        if (_entered(r) > 0 && r.locationId != null)
          {'requisitionLineId': r.line.id, 'stockLocationId': r.locationId, 'quantityIssued': _entered(r)},
    ];
    Navigator.pop(context, IssueSubmission(_received.text.trim(), _remarks.text.trim(), lines));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final nothingInStock = _rows.isNotEmpty && _rows.every((r) => r.options.isEmpty);

    return AlertDialog(
      title: Text('Issue stock: ${widget.requisition.number}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_rows.isEmpty)
              const Text('Nothing is left to issue on this requisition.')
            else ...[
              Text('Leave a quantity empty to skip that item.', style: t.labelMedium),
              const SizedBox(height: 12),
              if (nothingInStock)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('None of these items is in stock at any location, so nothing can be issued yet.'),
                ),
              for (final r in _rows) ...[
                Text(r.line.item.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  'Requested ${r.line.quantity} | Recommended ${r.line.recommended ?? 0} | '
                  'Still to issue ${qty(r.remaining)} ${r.line.uom}',
                  style: t.labelMedium,
                ),
                const SizedBox(height: 6),
                if (r.options.isEmpty)
                  const Text('No stock of this item at any location.')
                else
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: r.locationId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'From location'),
                        items: [
                          for (final b in r.options)
                            DropdownMenuItem(
                              value: b.location.id,
                              child: Text('${b.location.name} (${qty(b.qty)} on hand)', overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (v) => setState(() {
                          r.locationId = v ?? r.locationId;
                          r.qty.text = qty(r.max);
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: r.qty,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'Quantity', errorText: _error(r), errorMaxLines: 2),
                      ),
                    ),
                  ]),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _received,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Received by (who collected the items) *'),
              ),
              const SizedBox(height: 12),
              TextField(controller: _remarks, decoration: const InputDecoration(labelText: 'Remarks')),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _valid ? _submit : null, child: const Text('Issue')),
      ],
    );
  }
}
