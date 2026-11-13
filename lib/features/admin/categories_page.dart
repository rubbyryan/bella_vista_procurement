import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/state.dart';
import '../../core/theme/bv_theme.dart';
import '../../core/widgets.dart';

/// Item category management.
///
/// Tabs: Categories (list, search, filter by department), Add category,
/// Edit category (including deactivate). Categories are never deleted; a
/// deactivated category keeps its history. Only the Stores Controller can add,
/// edit or deactivate (the backend enforces the same).
class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> with SingleTickerProviderStateMixin {
  late final bool _canManage;
  late final TabController _tabs;
  int? _editId; // category chosen on the Edit tab

  @override
  void initState() {
    super.initState();
    _canManage = ref.read(sessionProvider)?.role == Role.stores;
    _tabs = TabController(length: _canManage ? 3 : 1, vsync: this)..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _goEdit(int id) {
    setState(() => _editId = id);
    _tabs.animateTo(2);
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionProvider) == null) return const SizedBox();

    final Widget body = switch (_tabs.index) {
      0 => _ListTab(canManage: _canManage, onEdit: _goEdit),
      1 => _AddTab(onAdded: () => _tabs.animateTo(0)),
      _ => _EditTab(selectedId: _editId, onSelect: (id) => setState(() => _editId = id)),
    };

    return PageBody(
      title: 'Categories',
      subtitle: _canManage
          ? 'Categories group items inside a department. They can be edited or deactivated, never deleted.'
          : 'Item categories (view only).',
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
                const Tab(icon: Icon(Icons.folder_copy_rounded), text: 'Categories'),
                if (_canManage) const Tab(icon: Icon(Icons.create_new_folder_rounded), text: 'Add category'),
                if (_canManage) const Tab(icon: Icon(Icons.edit_rounded), text: 'Edit category'),
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
// Tab 1: list
// ---------------------------------------------------------------------------
enum _Filter { all, active, inactive }

class _ListTab extends ConsumerStatefulWidget {
  const _ListTab({required this.canManage, required this.onEdit});
  final bool canManage;
  final void Function(int id) onEdit;

  @override
  ConsumerState<_ListTab> createState() => _ListTabState();
}

class _ListTabState extends ConsumerState<_ListTab> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;
  int? _deptFilter; // null = all departments

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final depts = ref.watch(departmentsP).valueOrNull ?? [];
    // Picking a department uses GET /categories/department/{id}.
    final AsyncValue<List<Category>> cats =
        _deptFilter == null ? ref.watch(categoriesP) : ref.watch(categoriesByDeptP(_deptFilter!));

    return cats.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => _LoadError(message: '$e', onRetry: () => refreshAll(ref)),
      data: (all) {
        final q = _search.text.trim().toLowerCase();
        final list = all.where((c) {
          if (_filter == _Filter.active && !c.active) return false;
          if (_filter == _Filter.inactive && c.active) return false;
          return q.isEmpty ||
              c.name.toLowerCase().contains(q) ||
              c.description.toLowerCase().contains(q) ||
              c.departmentName.toLowerCase().contains(q);
        }).toList()
          ..sort((a, b) {
            final byDept = a.departmentName.toLowerCase().compareTo(b.departmentName.toLowerCase());
            return byDept != 0 ? byDept : a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        final activeCount = all.where((c) => c.active).length;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 260,
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search categories',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<int?>(
                value: depts.any((d) => d.id == _deptFilter) ? _deptFilter : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Department', isDense: true),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('All departments')),
                  for (final d in depts) DropdownMenuItem<int?>(value: d.id, child: Text(d.name)),
                ],
                onChanged: (id) => setState(() => _deptFilter = id),
              ),
            ),
            ChoiceChip(
              label: Text('All (${all.length})'),
              selected: _filter == _Filter.all,
              onSelected: (_) => setState(() => _filter = _Filter.all),
            ),
            ChoiceChip(
              label: Text('Active ($activeCount)'),
              selected: _filter == _Filter.active,
              onSelected: (_) => setState(() => _filter = _Filter.active),
            ),
            ChoiceChip(
              label: Text('Inactive (${all.length - activeCount})'),
              selected: _filter == _Filter.inactive,
              onSelected: (_) => setState(() => _filter = _Filter.inactive),
            ),
          ]),
          const SizedBox(height: 8),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(all.isEmpty ? 'No categories here yet.' : 'No categories match your search.'),
            )
          else
            for (final c in list) ...[
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => _showDetails(context, c.id),
                leading: const CircleAvatar(radius: 18, child: Icon(Icons.folder_copy_rounded, size: 18)),
                title: Text(c.name),
                subtitle: Text(c.description.isEmpty ? c.departmentName : '${c.departmentName} | ${c.description}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  _statusChip(c.active),
                  if (widget.canManage)
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () => widget.onEdit(c.id),
                      icon: const Icon(Icons.edit_rounded),
                    ),
                ]),
              ),
            ],
        ]);
      },
    );
  }

  /// Opens a dialog that loads the category by id (GET /categories/{id}).
  Future<void> _showDetails(BuildContext context, int id) {
    final repo = ref.read(repoProvider);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Category details'),
        content: BVSurface(
          child: SizedBox(
            width: 380,
            child: FutureBuilder<Category>(
              future: repo.category(id),
              builder: (_, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
                }
                if (snap.hasError) return Text('${snap.error}');
                final c = snap.data!;
                return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.name, style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Department: ${c.departmentName}'),
                  const SizedBox(height: 8),
                  Text(c.description.isEmpty ? 'No description' : c.description),
                  const SizedBox(height: 12),
                  Row(children: [
                    _statusChip(c.active),
                    const SizedBox(width: 12),
                    Text('ID ${c.id}', style: Theme.of(ctx).textTheme.labelMedium),
                  ]),
                ]);
              },
            ),
          ),
        ),
        actions: [
          if (widget.canManage)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onEdit(id);
              },
              child: const Text('Edit'),
            ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: add
// ---------------------------------------------------------------------------
class _AddTab extends ConsumerStatefulWidget {
  const _AddTab({required this.onAdded});
  final VoidCallback onAdded;

  @override
  ConsumerState<_AddTab> createState() => _AddTabState();
}

class _AddTabState extends ConsumerState<_AddTab> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  int? _deptId;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  String? _nameRule(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Name is required';
    if (s.length > 100) return 'Maximum 100 characters';
    final clash = (ref.read(categoriesP).valueOrNull ?? [])
        .any((c) => c.departmentId == _deptId && c.name.toLowerCase() == s.toLowerCase());
    return clash ? 'This department already has a category with this name' : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await act(
      context,
      ref,
      () => ref.read(repoProvider).createCategory(_name.text.trim(), _desc.text.trim(), _deptId!),
      'Category added.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _name.clear();
      _desc.clear();
      widget.onAdded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final depts = (ref.watch(departmentsP).valueOrNull ?? []).where((d) => d.active).toList()
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
            validator: (v) => v == null ? 'Please select an item department' : null,
            onChanged: (id) => setState(() => _deptId = id),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Category name *', hintText: 'e.g. Cleaning Chemicals'),
            validator: _nameRule,
          ),
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
            label: const Text('Add category'),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3: edit / deactivate
// ---------------------------------------------------------------------------
class _EditTab extends ConsumerStatefulWidget {
  const _EditTab({required this.selectedId, required this.onSelect});
  final int? selectedId;
  final void Function(int? id) onSelect;

  @override
  ConsumerState<_EditTab> createState() => _EditTabState();
}

class _EditTabState extends ConsumerState<_EditTab> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  Category? _loaded;
  int? _deptId;
  String? _error;
  bool _loading = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final id = widget.selectedId;
    if (id != null) Future.microtask(() => _load(id));
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _load(int id) async {
    setState(() {
      _loading = true;
      _error = null;
      _loaded = null;
    });
    try {
      final c = await ref.read(repoProvider).category(id); // GET /categories/{id}
      if (!mounted) return;
      setState(() {
        _loaded = c;
        _deptId = c.departmentId;
        _name.text = c.name;
        _desc.text = c.description;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  bool get _dirty {
    final c = _loaded;
    return c != null &&
        (_name.text.trim() != c.name || _desc.text.trim() != c.description || _deptId != c.departmentId);
  }

  String? _nameRule(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Name is required';
    if (s.length > 100) return 'Maximum 100 characters';
    final clash = (ref.read(categoriesP).valueOrNull ?? []).any((c) =>
        c.id != _loaded?.id && c.departmentId == _deptId && c.name.toLowerCase() == s.toLowerCase());
    return clash ? 'This department already has a category with this name' : null;
  }

  Future<void> _save() async {
    final c = _loaded;
    if (c == null || _deptId == null || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await act(
      context,
      ref,
      () => ref.read(repoProvider).updateCategory(c.id, _name.text.trim(), _desc.text.trim(), _deptId!),
      'Category updated.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) await _load(c.id);
  }

  Future<void> _deactivate() async {
    final c = _loaded;
    if (c == null) return;
    final yes = await confirmDialog(
      context,
      title: 'Deactivate "${c.name}"?',
      message: 'The category stays in the system for past records but can no longer be used. '
          'This app cannot reactivate it. A category that still has active items cannot be deactivated.',
      confirmLabel: 'Deactivate',
    );
    if (!yes || !mounted) return;
    setState(() => _busy = true);
    final ok = await act(
      context,
      ref,
      () => ref.read(repoProvider).deactivateCategory(c.id),
      'Category deactivated.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) await _load(c.id);
  }

  @override
  Widget build(BuildContext context) {
    final cats = [...(ref.watch(categoriesP).valueOrNull ?? <Category>[])]
      ..sort((a, b) {
        final byDept = a.departmentName.toLowerCase().compareTo(b.departmentName.toLowerCase());
        return byDept != 0 ? byDept : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final selected = cats.any((c) => c.id == widget.selectedId) ? widget.selectedId : null;
    // Active departments, plus the category's current one even if it is inactive.
    final depts = (ref.watch(departmentsP).valueOrNull ?? <Dept>[])
        .where((d) => d.active || d.id == _loaded?.departmentId)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final t = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DropdownButtonFormField<int>(
          value: selected,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Category'),
          hint: const Text('Select a category to edit'),
          items: [
            for (final c in cats)
              DropdownMenuItem(
                value: c.id,
                child: Text('${c.departmentName}: ${c.name}${c.active ? '' : ' (inactive)'}', overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (id) {
            widget.onSelect(id);
            if (id != null) _load(id);
          },
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          _LoadError(message: _error!, onRetry: () => widget.selectedId == null ? null : _load(widget.selectedId!))
        else if (_loaded == null)
          const Text('Pick a category above to change its name, description or department.')
        else
          Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _statusChip(_loaded!.active),
                const SizedBox(width: 12),
                Text('ID ${_loaded!.id}', style: t.textTheme.labelMedium),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: depts.any((d) => d.id == _deptId) ? _deptId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Department *'),
                items: [for (final d in depts) DropdownMenuItem(value: d.id, child: Text(d.name))],
                validator: (v) => v == null ? 'Please select an item department' : null,
                onChanged: (id) => setState(() => _deptId = id),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Category name *'),
                validator: _nameRule,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                onChanged: (_) => setState(() {}),
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: (_dirty && !_busy) ? _save : null,
                icon: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                label: const Text('Save changes'),
              ),
              const Divider(height: 32),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Category active'),
                subtitle: Text(_loaded!.active
                    ? 'Switch off to deactivate. Not possible while it has active items, and this app cannot reactivate it.'
                    : 'This category is inactive. Reactivating is not available yet.'),
                value: _loaded!.active,
                // Only on -> off is possible: the backend has no reactivate endpoint.
                onChanged: (_loaded!.active && !_busy)
                    ? (on) {
                        if (!on) _deactivate();
                      }
                    : null,
              ),
            ]),
          ),
      ]),
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
