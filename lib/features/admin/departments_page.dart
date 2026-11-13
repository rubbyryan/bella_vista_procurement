import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/state.dart';
import '../../core/theme/bv_theme.dart';
import '../../core/widgets.dart';

/// Item department management.
///
/// Tabs: Departments (list + search), Add department, Edit department.
/// Departments are never deleted, so there is no delete button anywhere.
/// Only the Stores Controller can add or edit (the backend enforces the same).
class DepartmentsPage extends ConsumerStatefulWidget {
  const DepartmentsPage({super.key});

  @override
  ConsumerState<DepartmentsPage> createState() => _DepartmentsPageState();
}

class _DepartmentsPageState extends ConsumerState<DepartmentsPage> with SingleTickerProviderStateMixin {
  late final bool _canManage;
  late final TabController _tabs;
  int? _editId; // department chosen on the Edit tab

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
      title: 'Departments',
      subtitle: _canManage
          ? 'Item departments group categories and items. Departments can be edited but never deleted.'
          : 'Item departments (view only).',
      actions: [
        IconButton(
          tooltip: 'Reload',
          onPressed: () => ref.invalidate(departmentsP),
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
                const Tab(icon: Icon(Icons.apartment_rounded), text: 'Departments'),
                if (_canManage) const Tab(icon: Icon(Icons.add_business_rounded), text: 'Add department'),
                if (_canManage) const Tab(icon: Icon(Icons.edit_rounded), text: 'Edit department'),
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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final depts = ref.watch(departmentsP);
    return depts.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => _LoadError(message: '$e', onRetry: () => ref.invalidate(departmentsP)),
      data: (all) {
        final q = _search.text.trim().toLowerCase();
        final list = all.where((d) {
          if (_filter == _Filter.active && !d.active) return false;
          if (_filter == _Filter.inactive && d.active) return false;
          return q.isEmpty || d.name.toLowerCase().contains(q) || d.description.toLowerCase().contains(q);
        }).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        final activeCount = all.where((d) => d.active).length;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search departments',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
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
              child: Text(all.isEmpty ? 'No departments yet.' : 'No departments match your search.'),
            )
          else
            for (final d in list) ...[
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => _showDetails(context, d.id),
                leading: const CircleAvatar(radius: 18, child: Icon(Icons.apartment_rounded, size: 18)),
                title: Text(d.name),
                subtitle: Text(d.description.isEmpty ? 'No description' : d.description),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  StatusChip(d.active ? 'Active' : 'Inactive', d.active ? StatusKind.success : StatusKind.neutral),
                  if (widget.canManage)
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () => widget.onEdit(d.id),
                      icon: const Icon(Icons.edit_rounded),
                    ),
                ]),
              ),
            ],
        ]);
      },
    );
  }

  /// Opens a dialog that loads the department by id (GET /departments/{id}).
  Future<void> _showDetails(BuildContext context, int id) {
    final repo = ref.read(repoProvider);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Department details'),
        content: BVSurface(
          child: SizedBox(
            width: 380,
            child: FutureBuilder<Dept>(
              future: repo.department(id),
              builder: (_, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
                }
                if (snap.hasError) return Text('${snap.error}');
                final d = snap.data!;
                return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.name, style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(d.description.isEmpty ? 'No description' : d.description),
                  const SizedBox(height: 12),
                  Row(children: [
                    StatusChip(d.active ? 'Active' : 'Inactive', d.active ? StatusKind.success : StatusKind.neutral),
                    const SizedBox(width: 12),
                    Text('ID ${d.id}', style: Theme.of(ctx).textTheme.labelMedium),
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
    final exists = (ref.read(departmentsP).valueOrNull ?? []).any((d) => d.name.toLowerCase() == s.toLowerCase());
    return exists ? 'A department with this name already exists' : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await act(
      context,
      ref,
      () => ref.read(repoProvider).createDepartment(_name.text.trim(), _desc.text.trim()),
      'Department added.',
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
    return Form(
      key: _form,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Department name *', hintText: 'e.g. Food & Kitchen'),
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
            label: const Text('Add department'),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3: edit
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
  Dept? _loaded;
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
      final d = await ref.read(repoProvider).department(id); // GET /departments/{id}
      if (!mounted) return;
      setState(() {
        _loaded = d;
        _name.text = d.name;
        _desc.text = d.description;
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
    final d = _loaded;
    return d != null && (_name.text.trim() != d.name || _desc.text.trim() != d.description);
  }

  String? _nameRule(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Name is required';
    if (s.length > 100) return 'Maximum 100 characters';
    final clash = (ref.read(departmentsP).valueOrNull ?? [])
        .any((d) => d.id != _loaded?.id && d.name.toLowerCase() == s.toLowerCase());
    return clash ? 'Another department already uses this name' : null;
  }

  Future<void> _save() async {
    final d = _loaded;
    if (d == null || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await act(
      context,
      ref,
      () => ref.read(repoProvider).updateDepartment(d.id, _name.text.trim(), _desc.text.trim()),
      'Department updated.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) await _load(d.id);
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(departmentsP).valueOrNull ?? [];
    final sorted = [...all]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final selected = sorted.any((d) => d.id == widget.selectedId) ? widget.selectedId : null;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DropdownButtonFormField<int>(
          value: selected,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Department'),
          hint: const Text('Select a department to edit'),
          items: [for (final d in sorted) DropdownMenuItem(value: d.id, child: Text(d.active ? d.name : '${d.name} (inactive)'))],
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
          const Text('Pick a department above to change its name or description.')
        else
          Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                StatusChip(_loaded!.active ? 'Active' : 'Inactive', _loaded!.active ? StatusKind.success : StatusKind.neutral),
                const SizedBox(width: 12),
                Text('ID ${_loaded!.id}', style: Theme.of(context).textTheme.labelMedium),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Department name *'),
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
