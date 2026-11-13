import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/state.dart';
import '../../core/theme/bv_theme.dart';
import '../../core/widgets.dart';

/// Stock balances: quantity on hand per item and location (read only).
///
/// Filters use the server endpoints: by location, by item, or by item and
/// location together. The list is loaded lazily: rows are built on demand and
/// revealed [_pageSize] at a time as you scroll.
const _pageSize = 25;

enum _Level { all, low, out }

enum _Health { ok, low, out }

_Health _healthOf(Balance b) {
  if (b.qty <= 0) return _Health.out;
  if (b.item.reorderLevel > 0 && b.qty <= b.item.reorderLevel) return _Health.low;
  return _Health.ok;
}

StatusChip _healthChip(_Health h) => switch (h) {
      _Health.out => const StatusChip('Out of stock', StatusKind.danger),
      _Health.low => const StatusChip('Low', StatusKind.pending),
      _Health.ok => const StatusChip('In stock', StatusKind.success),
    };

String _stamp(DateTime? d) {
  if (d == null) return 'Never';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

class StockBalancesPage extends ConsumerStatefulWidget {
  const StockBalancesPage({super.key});

  @override
  ConsumerState<StockBalancesPage> createState() => _StockBalancesPageState();
}

class _StockBalancesPageState extends ConsumerState<StockBalancesPage> {
  final _search = TextEditingController();
  TextEditingController? _itemText; // owned by the Autocomplete field
  _Level _level = _Level.all;
  int? _locationId;
  Item? _item;
  int _shown = _pageSize;
  bool _loadingMore = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _resetPaging() => _shown = _pageSize;

  void _loadMore() {
    if (_loadingMore) return;
    _loadingMore = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _shown += _pageSize;
        _loadingMore = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(locationsP).valueOrNull ?? <Location>[];
    final items = ref.watch(itemsP).valueOrNull ?? <Item>[];

    // The server does the filtering: item + location, else location, else item, else all.
    final AsyncValue<List<Balance>> data = (_item != null && _locationId != null)
        ? ref.watch(balanceForP((_item!.id, _locationId!)))
        : _locationId != null
            ? ref.watch(balancesByLocationP(_locationId!))
            : _item != null
                ? ref.watch(balancesByItemP(_item!.id))
                : ref.watch(balancesP);

    final listHeight = (MediaQuery.sizeOf(context).height * 0.55).clamp(320.0, 640.0);

    return PageBody(
      title: 'Stock balances',
      subtitle: 'Quantity on hand for each item at each location.',
      actions: [
        IconButton(tooltip: 'Reload', onPressed: () => refreshAll(ref), icon: const Icon(Icons.refresh_rounded)),
      ],
      children: [
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<int?>(
                  value: locations.any((l) => l.id == _locationId) ? _locationId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Location', isDense: true),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('All locations')),
                    for (final l in locations) DropdownMenuItem<int?>(value: l.id, child: Text(l.name)),
                  ],
                  onChanged: (id) => setState(() {
                    _locationId = id;
                    _resetPaging();
                  }),
                ),
              ),
              SizedBox(
                width: 300,
                child: Autocomplete<Item>(
                  displayStringForOption: (i) => i.label,
                  optionsBuilder: (v) {
                    final q = v.text.trim().toLowerCase();
                    if (q.isEmpty) return const Iterable<Item>.empty();
                    return items
                        .where((i) => i.code.toLowerCase().contains(q) || i.name.toLowerCase().contains(q))
                        .take(20);
                  },
                  onSelected: (i) => setState(() {
                    _item = i;
                    _resetPaging();
                  }),
                  fieldViewBuilder: (ctx, controller, focus, onSubmit) {
                    _itemText = controller;
                    return TextField(
                      controller: controller,
                      focusNode: focus,
                      decoration: InputDecoration(
                        labelText: 'Item',
                        hintText: 'Type a code or name',
                        isDense: true,
                        prefixIcon: const Icon(Icons.inventory_2_rounded),
                        suffixIcon: _item == null
                            ? null
                            : IconButton(
                                tooltip: 'Clear item',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => setState(() {
                                  _item = null;
                                  _itemText?.clear();
                                  _resetPaging();
                                }),
                              ),
                      ),
                      // Typing again after picking an item drops the old pick.
                      onChanged: (_) {
                        if (_item != null && controller.text != _item!.label) {
                          setState(() {
                            _item = null;
                            _resetPaging();
                          });
                        }
                      },
                    );
                  },
                ),
              ),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(_resetPaging),
                  decoration: const InputDecoration(
                    hintText: 'Search the list',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
              ),
              for (final l in _Level.values)
                ChoiceChip(
                  label: Text(switch (l) {
                    _Level.all => 'All',
                    _Level.low => 'Low',
                    _Level.out => 'Out of stock',
                  }),
                  selected: _level == l,
                  onSelected: (_) => setState(() {
                    _level = l;
                    _resetPaging();
                  }),
                ),
            ]),
            const SizedBox(height: 12),
            data.when(
              loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => _LoadError(message: '$e', onRetry: () => refreshAll(ref)),
              data: (all) => _results(context, all, listHeight),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _results(BuildContext context, List<Balance> all, double listHeight) {
    final q = _search.text.trim().toLowerCase();
    final list = all.where((b) {
      final h = _healthOf(b);
      if (_level == _Level.low && h != _Health.low) return false;
      if (_level == _Level.out && h != _Health.out) return false;
      return q.isEmpty ||
          b.item.name.toLowerCase().contains(q) ||
          b.item.code.toLowerCase().contains(q) ||
          b.location.name.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        final byItem = a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase());
        return byItem != 0 ? byItem : a.location.name.toLowerCase().compareTo(b.location.name.toLowerCase());
      });

    final lowCount = all.where((b) => _healthOf(b) == _Health.low).length;
    final outCount = all.where((b) => _healthOf(b) == _Health.out).length;
    final distinctItems = all.map((b) => b.item.id).toSet().length;

    if (all.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(_item != null && _locationId != null
            ? 'No stock record for this item at this location yet.'
            : 'No stock balances here yet.'),
      );
    }

    final shown = math.min(_shown, list.length);
    final hasMore = shown < list.length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ResponsiveGrid(children: [
        KpiCard(label: 'Stock lines', value: '${all.length}', icon: Icons.list_alt_rounded),
        KpiCard(label: 'Different items', value: '$distinctItems', icon: Icons.inventory_2_rounded),
        KpiCard(label: 'Low stock', value: '$lowCount', icon: Icons.warning_amber_rounded, warn: lowCount > 0),
        KpiCard(label: 'Out of stock', value: '$outCount', icon: Icons.remove_shopping_cart_rounded, warn: outCount > 0),
      ]),
      const SizedBox(height: 12),
      if (list.isEmpty)
        const Padding(padding: EdgeInsets.all(16), child: Text('No stock lines match your filters.'))
      else ...[
        Text('Showing $shown of ${list.length} lines', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        SizedBox(
          height: listHeight,
          // ListView.builder only builds the rows that are on screen.
          child: ListView.builder(
            itemCount: shown + (hasMore ? 1 : 0),
            itemBuilder: (ctx, index) {
              if (index >= shown) {
                _loadMore();
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
                );
              }
              final b = list[index];
              return Column(mainAxisSize: MainAxisSize.min, children: [
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => _showDetails(ctx, b.id),
                  leading: const CircleAvatar(radius: 18, child: Icon(Icons.inventory_2_rounded, size: 18)),
                  title: Text(b.item.name),
                  subtitle: Text('${b.item.code} | ${b.location.name}\nUpdated ${_stamp(b.updated)}'),
                  isThreeLine: true,
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${qty(b.qty)} ${b.item.uom}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    _healthChip(_healthOf(b)),
                  ]),
                ),
              ]);
            },
          ),
        ),
      ],
    ]);
  }

  /// Opens a dialog that loads the balance by id (GET /stock-balances/{id}).
  Future<void> _showDetails(BuildContext context, int id) {
    final repo = ref.read(repoProvider);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stock balance'),
        content: BVSurface(
          child: SizedBox(
            width: 400,
            child: FutureBuilder<Balance>(
              future: repo.balance(id),
              builder: (_, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
                }
                if (snap.hasError) return Text('${snap.error}');
                final b = snap.data!;
                final t = Theme.of(ctx).textTheme;
                return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.item.name, style: t.titleLarge),
                  const SizedBox(height: 4),
                  Text('Code: ${b.item.code}'),
                  Text('${b.item.departmentName} > ${b.item.categoryName}'),
                  Text('Location: ${b.location.name}'),
                  const SizedBox(height: 8),
                  Text('On hand: ${qty(b.qty)} ${b.item.uom}', style: t.titleMedium),
                  Text('Minimum stock: ${qty(b.item.minLevel)} | Reorder level: ${qty(b.item.reorderLevel)}'),
                  Text('Last updated: ${_stamp(b.updated)}'),
                  const SizedBox(height: 12),
                  Row(children: [
                    _healthChip(_healthOf(b)),
                    const SizedBox(width: 12),
                    Text('ID ${b.id}', style: t.labelMedium),
                  ]),
                ]);
              },
            ),
          ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
      ]);
}
