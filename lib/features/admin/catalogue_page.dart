import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/state.dart';
import '../../core/widgets.dart';

/// Item departments, categories and items (the catalogue requisitions pick from).
class CataloguePage extends ConsumerWidget {
  const CataloguePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(sessionProvider) == null) return const SizedBox();
    final repo = ref.read(repoProvider);
    final depts = ref.watch(departmentsP);
    final cats = ref.watch(categoriesP);
    final items = ref.watch(itemsP);

    return PageBody(
      title: 'Catalogue',
      subtitle: 'Departments > categories > items. Items need a unit of measure, a minimum level and a reorder level.',
      children: [
        Panel(
          title: 'Item departments',
          trailing: TextButton.icon(
            onPressed: () async {
              final v = await askFields(context, title: 'New department', labels: const ['Name', 'Description'], required: const [true, false]);
              if (v != null && context.mounted) await act(context, ref, () => repo.createDepartment(v[0], v[1]), 'Department added.');
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add'),
          ),
          child: depts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e'),
            data: (l) => Wrap(spacing: 8, runSpacing: 8, children: [for (final d in l) Chip(label: Text(d.name))]),
          ),
        ),
        Panel(
          title: 'Categories',
          trailing: TextButton.icon(
            onPressed: () async {
              final d = depts.valueOrNull ?? [];
              if (d.isEmpty) {
                snack(context, 'Add a department first.');
                return;
              }
              final v = await showDialog<(String, String, int)>(context: context, builder: (_) => _CategoryDialog(depts: d));
              if (v != null && context.mounted) await act(context, ref, () => repo.createCategory(v.$1, v.$2, v.$3), 'Category added.');
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add'),
          ),
          child: cats.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e'),
            data: (l) => Wrap(spacing: 8, runSpacing: 8, children: [for (final c in l) Chip(label: Text('${c.name} (${c.departmentName})'))]),
          ),
        ),
        Panel(
          title: 'Items',
          trailing: TextButton.icon(
            onPressed: () async {
              final c = cats.valueOrNull ?? [];
              if (c.isEmpty) {
                snack(context, 'Add a category first.');
                return;
              }
              final v = await showDialog<Map<String, String>>(context: context, builder: (_) => _ItemDialog(cats: c));
              if (v != null && context.mounted) {
                await act(
                    context,
                    ref,
                        () => repo.createItem(
                        code: v['code']!,
                        name: v['name']!,
                        description: v['desc']!,
                        uom: v['uom']!,
                        categoryId: int.parse(v['cat']!),
                        minLevel: double.parse(v['min']!),
                        reorderLevel: double.parse(v['reorder']!)),
                    'Item added.');
              }
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add'),
          ),
          child: items.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e'),
            data: (l) => l.isEmpty
                ? const Text('No items yet. Add your first item.')
                : Column(children: [
              for (final i in l)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${i.label} (${i.uom})'),
                  subtitle: Text('${i.departmentName} > ${i.categoryName} | min ${qty(i.minLevel)} | reorder ${qty(i.reorderLevel)}'),
                ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.depts});
  final List<Dept> depts;
  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  late int _dept = widget.depts.first.id;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New category'),
    content: SizedBox(
      width: 380,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<int>(
          value: _dept,
          decoration: const InputDecoration(labelText: 'Department'),
          items: [for (final d in widget.depts) DropdownMenuItem(value: d.id, child: Text(d.name))],
          onChanged: (v) => setState(() => _dept = v ?? _dept),
        ),
        const SizedBox(height: 12),
        TextField(controller: _name, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Name *')),
        const SizedBox(height: 12),
        TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description')),
      ]),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        onPressed: _name.text.trim().isEmpty ? null : () => Navigator.pop(context, (_name.text.trim(), _desc.text.trim(), _dept)),
        child: const Text('Add'),
      ),
    ],
  );
}

class _ItemDialog extends StatefulWidget {
  const _ItemDialog({required this.cats});
  final List<Category> cats;
  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _uom = TextEditingController(text: 'each');
  final _min = TextEditingController(text: '0');
  final _reorder = TextEditingController(text: '0');
  late int _cat = widget.cats.first.id;

  @override
  void dispose() {
    for (final c in [_code, _name, _desc, _uom, _min, _reorder]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _code.text.trim().isNotEmpty && _name.text.trim().isNotEmpty && _uom.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('New item'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(
              value: _cat,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [for (final c in widget.cats) DropdownMenuItem(value: c.id, child: Text('${c.name} (${c.departmentName})'))],
              onChanged: (v) => setState(() => _cat = v ?? _cat),
            ),
            const SizedBox(height: 10),
            TextField(controller: _code, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Item code *')),
            const SizedBox(height: 10),
            TextField(controller: _name, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Name *')),
            const SizedBox(height: 10),
            TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 10),
            TextField(controller: _uom, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Unit of measure *')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _min, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minimum level'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _reorder, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Reorder level'))),
            ]),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: !ok
              ? null
              : () => Navigator.pop(context, {
            'cat': '$_cat',
            'code': _code.text.trim(),
            'name': _name.text.trim(),
            'desc': _desc.text.trim(),
            'uom': _uom.text.trim(),
            'min': '${double.tryParse(_min.text) ?? 0}',
            'reorder': '${double.tryParse(_reorder.text) ?? 0}',
          }),
          child: const Text('Add'),
        ),
      ],
    );
  }
}