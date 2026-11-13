import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/state.dart';
import '../../core/theme/bv_theme.dart';
import '../../core/widgets.dart';

/// Stock item catalogue.
///
/// Tabs: Items (lazy-loaded list with department / category filters) and
/// Register item. Only the Stores Controller can register items (the backend
/// enforces the same). The list is loaded lazily: rows are built on demand and
/// revealed [_pageSize] at a time as you scroll.
const _pageSize = 25;

class ItemsPage extends ConsumerStatefulWidget {
  const ItemsPage({super.key});

  @override
  ConsumerState<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends ConsumerState<ItemsPage> with SingleTickerProviderStateMixin {
  late final bool _canManage;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _canManage = ref.read(sessionProvider)?.role == Role.stores;
    _tabs = TabController(length: _canManage ? 2 : 1, vsync: this)..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionProvider) == null) return const SizedBox();

    final Widget body = _tabs.index == 0 ? const _ListTab() : _AddTab(onAdded: () => _tabs.animateTo(0));

    return PageBody(
      title: 'Items',
      subtitle: _canManage ? 'The stock item catalogue. Register new items here.' : 'The stock item catalogue (view only).',
      actions: [
        IconButton(
          tooltip: 'Reload',
          onPressed: () => refreshAll(ref),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      children: [
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                const Tab(icon: Icon(Icons.list_alt_rounded), text: 'Items'),
                if (_canManage) const Tab(icon: Icon(Icons.add_box_rounded), text: 'Register item'),
              ],
            ),
            const SizedBox(height: 16),
            body,
          ]),
        ),
      ],
    );
  }
}

StatusChip _statusChip(bool active) =>
    StatusChip(active ? 'Active' : 'Inactive', active ? StatusKind.success : StatusKind.neutral);

// ---------------------------------------------------------------------------
// Tab 1: lazy list
// ---------------------------------------------------------------------------
enum _Filter { all, active, inactive }

class _ListTab extends ConsumerStatefulWidget {
  const _ListTab();

  @override
  ConsumerState<_ListTab> createState() => _ListTabState();
}

class _ListTabState extends ConsumerState<_ListTab> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;
  int? _deptId;
  int? _catId;
  int _shown = _pageSize; // how many rows are revealed so far
  bool _loadingMore = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _resetPaging() => _shown = _pageSize;

  /// Called when the "loading more" row scrolls into view.
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
    final depts = ref.watch(departmentsP).valueOrNull ?? <Dept>[];
    final cats = (_deptId == null ? ref.watch(categoriesP) : ref.watch(categoriesByDeptP(_deptId!))).valueOrNull ??
        <Category>[];

    // The server does the filtering: by category, else by department, else all.
    final AsyncValue<List<Item>> items = _catId != null
        ? ref.watch(itemsByCategoryP(_catId!))
        : _deptId != null
            ? ref.watch(itemsByDeptP(_deptId!))
            : ref.watch(itemsP);

    final listHeight = (MediaQuery.sizeOf(context).height * 0.6).clamp(320.0, 640.0);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(_resetPaging),
            decoration: const InputDecoration(
              hintText: 'Search code, name or description',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<int?>(
            value: depts.any((d) => d.id == _deptId) ? _deptId : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Department', isDense: true),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('All departments')),
              for (final d in depts) DropdownMenuItem<int?>(value: d.id, child: Text(d.name)),
            ],
            onChanged: (id) => setState(() {
              _deptId = id;
              _catId = null; // categories belong to a department
              _resetPaging();
            }),
          ),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<int?>(
            value: cats.any((c) => c.id == _catId) ? _catId : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Category', isDense: true),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('All categories')),
              for (final c in cats)
                DropdownMenuItem<int?>(
                  value: c.id,
                  child: Text(_deptId == null ? '${c.name} (${c.departmentName})' : c.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (id) => setState(() {
              _catId = id;
              _resetPaging();
            }),
          ),
        ),
        for (final f in _Filter.values)
          ChoiceChip(
            label: Text(switch (f) {
              _Filter.all => 'All',
              _Filter.active => 'Active',
              _Filter.inactive => 'Inactive',
            }),
            selected: _filter == f,
            onSelected: (_) => setState(() {
              _filter = f;
              _resetPaging();
            }),
          ),
      ]),
      const SizedBox(height: 8),
      items.when(
        loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => _LoadError(message: '$e', onRetry: () => refreshAll(ref)),
        data: (all) {
          final q = _search.text.trim().toLowerCase();
          final list = all.where((i) {
            if (_filter == _Filter.active && !i.active) return false;
            if (_filter == _Filter.inactive && i.active) return false;
            return q.isEmpty ||
                i.code.toLowerCase().contains(q) ||
                i.name.toLowerCase().contains(q) ||
                i.description.toLowerCase().contains(q) ||
                i.categoryName.toLowerCase().contains(q);
          }).toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          if (list.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(all.isEmpty ? 'No items here yet.' : 'No items match your search.'),
            );
          }

          final shown = math.min(_shown, list.length);
          final hasMore = shown < list.length;

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('Showing $shown of ${list.length} items', style: Theme.of(context).textTheme.labelMedium),
            ),
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
                  final i = list[index];
                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => _showDetails(ctx, i.id),
                      leading: const CircleAvatar(radius: 18, child: Icon(Icons.inventory_2_rounded, size: 18)),
                      title: Text(i.name),
                      subtitle: Text(
                        '${i.code} | ${i.departmentName} > ${i.categoryName} | ${i.uom}\n'
                        'Min ${qty(i.minLevel)} | Reorder ${qty(i.reorderLevel)}',
                      ),
                      isThreeLine: true,
                      trailing: _statusChip(i.active),
                    ),
                  ]);
                },
              ),
            ),
          ]);
        },
      ),
    ]);
  }

  /// Opens a dialog that loads the item by id (GET /items/{id}).
  Future<void> _showDetails(BuildContext context, int id) {
    final repo = ref.read(repoProvider);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Item details'),
        content: BVSurface(
          child: SizedBox(
            width: 400,
            child: FutureBuilder<Item>(
              future: repo.item(id),
              builder: (_, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
                }
                if (snap.hasError) return Text('${snap.error}');
                final i = snap.data!;
                final t = Theme.of(ctx).textTheme;
                return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.name, style: t.titleLarge),
                  const SizedBox(height: 4),
                  Text('Code: ${i.code}'),
                  Text('${i.departmentName} > ${i.categoryName}'),
                  Text('Unit of measure: ${i.uom}'),
                  Text('Minimum stock: ${qty(i.minLevel)} | Reorder level: ${qty(i.reorderLevel)}'),
                  const SizedBox(height: 8),
                  Text(i.description.isEmpty ? 'No description' : i.description),
                  const SizedBox(height: 12),
                  Row(children: [
                    _statusChip(i.active),
                    const SizedBox(width: 12),
                    Text('ID ${i.id}', style: t.labelMedium),
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

// ---------------------------------------------------------------------------
// Tab 2: register
// ---------------------------------------------------------------------------
class _AddTab extends ConsumerStatefulWidget {
  const _AddTab({required this.onAdded});
  final VoidCallback onAdded;

  @override
  ConsumerState<_AddTab> createState() => _AddTabState();
}

class _AddTabState extends ConsumerState<_AddTab> {
  static const _commonUnits = ['Each', 'Box', 'Packet', 'Carton', 'Litre', 'Kg', 'Roll', 'Bottle'];

  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _uom = TextEditingController();
  final _min = TextEditingController(text: '0');
  final _reorder = TextEditingController(text: '0');
  int? _deptId;
  int? _catId;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_code, _name, _desc, _uom, _min, _reorder]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _codeRule(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Item code is required';
    if (s.length > 30) return 'Maximum 30 characters';
    final exists = (ref.read(itemsP).valueOrNull ?? <Item>[]).any((i) => i.code.toLowerCase() == s.toLowerCase());
    return exists ? 'This item code already exists' : null;
  }

  String? _levelRule(String? v) {
    final n = double.tryParse((v ?? '').trim());
    if (n == null) return 'Enter a number';
    if (n < 0) return 'Cannot be negative';
    return null;
  }

  String? _reorderRule(String? v) {
    final base = _levelRule(v);
    if (base != null) return base;
    final min = double.tryParse(_min.text.trim()) ?? 0;
    if (double.parse(v!.trim()) < min) return 'Cannot be lower than the minimum stock level';
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await act(
      context,
      ref,
      () => ref.read(repoProvider).createItem(
            code: _code.text.trim(),
            name: _name.text.trim(),
            description: _desc.text.trim(),
            uom: _uom.text.trim(),
            categoryId: _catId!,
            minLevel: double.parse(_min.text.trim()),
            reorderLevel: double.parse(_reorder.text.trim()),
          ),
      'Item registered.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      for (final c in [_code, _name, _desc, _uom]) {
        c.clear();
      }
      _min.text = '0';
      _reorder.text = '0';
      widget.onAdded();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(itemsP); // loaded so the duplicate-code check has data
    final depts = (ref.watch(departmentsP).valueOrNull ?? <Dept>[]).where((d) => d.active).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final cats = (ref.watch(categoriesP).valueOrNull ?? <Category>[])
        .where((c) => c.active && c.departmentId == _deptId)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Form(
      key: _form,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DropdownButtonFormField<int>(
            value: depts.any((d) => d.id == _deptId) ? _deptId : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Department *'),
            hint: const Text('Select a department'),
            items: [for (final d in depts) DropdownMenuItem(value: d.id, child: Text(d.name))],
            validator: (v) => v == null ? 'Select a department first' : null,
            onChanged: (id) => setState(() {
              _deptId = id;
              _catId = null;
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: cats.any((c) => c.id == _catId) ? _catId : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Category *'),
            hint: Text(_deptId == null ? 'Select a department first' : 'Select a category'),
            items: [for (final c in cats) DropdownMenuItem(value: c.id, child: Text(c.name))],
            validator: (v) => v == null ? 'Please select an item category' : null,
            onChanged: (id) => setState(() => _catId = id),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Item code *', hintText: 'e.g. STN-0001'),
            validator: _codeRule,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Item name *'),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return 'Name is required';
              if (s.length > 150) return 'Maximum 150 characters';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _uom,
            decoration: const InputDecoration(labelText: 'Unit of measure *', hintText: 'e.g. Box'),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return 'Unit of measure is required';
              if (s.length > 50) return 'Maximum 50 characters';
              return null;
            },
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final u in _commonUnits) ActionChip(label: Text(u), onPressed: () => setState(() => _uom.text = u)),
          ]),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextFormField(
                controller: _min,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Minimum stock level *'),
                validator: _levelRule,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _reorder,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Reorder level *'),
                validator: _reorderRule,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextFormField(
            controller: _desc,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_rounded),
            label: const Text('Register item'),
          ),
        ]),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
      ]);
}
