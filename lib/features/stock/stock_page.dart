import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/state.dart';
import '../../core/theme/bv_theme.dart';
import '../../core/widgets.dart';

enum StockLvl { healthy, reorder, critical, out }

StockLvl levelOf(Item i, double onHand) {
  if (onHand <= 0) return StockLvl.out;
  if (onHand <= i.minLevel) return StockLvl.critical;
  if (onHand <= i.reorderLevel) return StockLvl.reorder;
  return StockLvl.healthy;
}

StatusChip levelChip(StockLvl l) => switch (l) {
      StockLvl.healthy => const StatusChip('Healthy', StatusKind.success),
      StockLvl.reorder => const StatusChip('Reorder', StatusKind.pending),
      StockLvl.critical => const StatusChip('Critical', StatusKind.danger),
      StockLvl.out => const StatusChip('Out of stock', StatusKind.danger),
    };

/// Number of items at or below reorder level (used by the dashboard).
int lowStockCount(List<Item> items, List<Balance> balances) {
  final m = onHandByItem(balances);
  return items.where((i) => levelOf(i, m[i.id] ?? 0) != StockLvl.healthy).length;
}

class StockPage extends ConsumerStatefulWidget {
  const StockPage({super.key});
  @override
  ConsumerState<StockPage> createState() => _StockPageState();
}

class _StockPageState extends ConsumerState<StockPage> {
  String _f = 'All';

  Future<void> _add(Session me, List<Item> items) async {
    final locs = await ref.read(locationsP.future);
    if (!mounted) return;
    final res = await showDialog<Map<String, String>>(context: context, builder: (_) => _AddStockDialog(items: items, locations: locs));
    if (res == null || !mounted) return;
    await act(
        context,
        ref,
        () => ref.read(repoProvider).addToStock(
            itemId: int.parse(res['item']!),
            locationId: int.parse(res['loc']!),
            quantity: double.parse(res['qty']!),
            reference: res['ref']!,
            remarks: res['remarks']!,
            by: me.name),
        'Added to stock.');
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider);
    if (me == null) return const SizedBox();
    final items = ref.watch(itemsP);
    final bal = ref.watch(balancesP);
    final mv = ref.watch(movementsP);

    return PageBody(
      title: 'Stock room',
      subtitle: 'Stock changes only through issue notes, approved GRVs and "Add to stock". Every change is logged below (this replaces the bin cards).',
      actions: [
        if (me.role == Role.stores)
          FilledButton.icon(
            style: ctaStyle(context),
            onPressed: items.valueOrNull == null ? null : () => _add(me, items.valueOrNull!),
            icon: const Icon(Icons.add_box_rounded),
            label: const Text('Add to stock'),
          ),
      ],
      children: [
        AsyncBody<List<Item>>(
          value: items,
          onRetry: () => ref.invalidate(itemsP),
          builder: (list) => AsyncBody<List<Balance>>(
            value: bal,
            onRetry: () => ref.invalidate(balancesP),
            builder: (balances) {
              final total = onHandByItem(balances);
              bool match(Item i) {
                final l = levelOf(i, total[i.id] ?? 0);
                return switch (_f) {
                  'Reorder' => l == StockLvl.reorder,
                  'Critical' => l == StockLvl.critical,
                  'Out of stock' => l == StockLvl.out,
                  _ => true,
                };
              }

              final shown = list.where(match).toList();
              return Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final f in const ['All', 'Reorder', 'Critical', 'Out of stock'])
                      ChoiceChip(label: Text(f), selected: _f == f, onSelected: (_) => setState(() => _f = f)),
                  ]),
                  const SizedBox(height: 8),
                  if (shown.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No items.')),
                  for (var k = 0; k < shown.length; k++) ...[
                    if (k > 0) const Divider(height: 1),
                    _row(shown[k], total[shown[k].id] ?? 0, balances.where((b) => b.item.id == shown[k].id && b.qty > 0).toList()),
                  ],
                ]),
              );
            },
          ),
        ),
        Panel(
          title: 'Stock movements',
          child: mv.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e'),
            data: (list) {
              final l = [...list]..sort((a, b) => (b.at ?? DateTime(2000)).compareTo(a.at ?? DateTime(2000)));
              if (l.isEmpty) return const Text('No movements yet.');
              return Column(children: [
                for (final m in l.take(15))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(m.type.contains('ISSUE') || m.type.contains('OUT') ? Icons.north_east_rounded : Icons.south_west_rounded),
                    title: Text('${m.item}: ${qty(m.qty)} (${statusLabel(m.type)})'),
                    subtitle: Text('${m.ref} | ${m.by} | ${m.at == null ? '' : stamp(m.at!)}${m.to.isEmpty ? '' : ' | to ${m.to}'}${m.from.isEmpty ? '' : ' | from ${m.from}'}'),
                  ),
              ]);
            },
          ),
        ),
      ],
    );
  }

  Widget _row(Item i, double total, List<Balance> where) {
    final lvl = levelOf(i, total);
    return Builder(builder: (c) {
      final sc = Theme.of(c).colorScheme;
      final bar = switch (lvl) {
        StockLvl.healthy => sc.tertiary,
        StockLvl.reorder => sc.secondary,
        _ => sc.error,
      };
      final top = i.reorderLevel <= 0 ? (total <= 0 ? 1.0 : total * 2) : i.reorderLevel * 3;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${i.label} (${i.uom})', style: Theme.of(c).textTheme.titleMedium?.copyWith(fontSize: 14))),
            levelChip(lvl),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
                minHeight: 10, value: (total / top).clamp(0.0, 1.0).toDouble(), color: bar, backgroundColor: sc.outlineVariant),
          ),
          const SizedBox(height: 6),
          Text('On hand ${qty(total)} | Minimum ${qty(i.minLevel)} | Reorder at ${qty(i.reorderLevel)}'
              '${where.isEmpty ? '' : '\n${where.map((b) => '${b.location.name}: ${qty(b.qty)}').join('  |  ')}'}',
              style: Theme.of(c).textTheme.labelSmall),
        ]),
      );
    });
  }
}

class _AddStockDialog extends StatefulWidget {
  const _AddStockDialog({required this.items, required this.locations});
  final List<Item> items;
  final List<Location> locations;
  @override
  State<_AddStockDialog> createState() => _AddStockDialogState();
}

class _AddStockDialogState extends State<_AddStockDialog> {
  int? _item;
  late int? _loc = widget.locations.isEmpty ? null : widget.locations.first.id;
  final _qty = TextEditingController();
  final _ref = TextEditingController();
  final _remarks = TextEditingController();

  @override
  void dispose() {
    _qty.dispose();
    _ref.dispose();
    _remarks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _item != null && _loc != null && (double.tryParse(_qty.text) ?? 0) > 0;
    return AlertDialog(
      title: const Text('Add to stock'),
      content: BVSurface(
        child: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<int>(
                value: _item,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Item *'),
                items: [for (final i in widget.items) DropdownMenuItem(value: i.id, child: Text('${i.label} (${i.uom})'))],
                onChanged: (v) => setState(() => _item = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _loc,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Location *'),
                items: [for (final l in widget.locations) DropdownMenuItem(value: l.id, child: Text(l.name))],
                onChanged: (v) => setState(() => _loc = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _qty,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Quantity *'),
              ),
              const SizedBox(height: 12),
              TextField(controller: _ref, decoration: const InputDecoration(labelText: 'Reference (e.g. opening balance, invoice no.)')),
              const SizedBox(height: 12),
              TextField(controller: _remarks, decoration: const InputDecoration(labelText: 'Remarks')),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: !ok
              ? null
              : () => Navigator.pop(context, {
                    'item': '$_item',
                    'loc': '$_loc',
                    'qty': _qty.text.trim(),
                    'ref': _ref.text.trim(),
                    'remarks': _remarks.text.trim(),
                  }),
          child: const Text('Add to stock'),
        ),
      ],
    );
  }
}
