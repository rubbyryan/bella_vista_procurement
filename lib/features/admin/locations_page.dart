import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/state.dart';
import '../../core/theme/bv_theme.dart';
import '../../core/widgets.dart';

/// Stock location management.
///
/// Tabs: Locations (list + search), Add location, Edit location (including
/// deactivate). Locations are never deleted; a deactivated location keeps its
/// history. Only the Stores Controller can add, edit or deactivate (the
/// backend enforces the same).
class LocationsPage extends ConsumerStatefulWidget {
  const LocationsPage({super.key});

  @override
  ConsumerState<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends ConsumerState<LocationsPage> with SingleTickerProviderStateMixin {
  late final bool _canManage;
  late final TabController _tabs;
  int? _editId; // location chosen on the Edit tab

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
      title: 'Stock locations',
      subtitle: _canManage
          ? 'Places where stock is kept. Locations can be edited or deactivated, never deleted.'
          : 'Stock locations (view only).',
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
                const Tab(icon: Icon(Icons.place_rounded), text: 'Locations'),
                if (_canManage) const Tab(icon: Icon(Icons.add_location_alt_rounded), text: 'Add location'),
                if (_canManage) const Tab(icon: Icon(Icons.edit_location_alt_rounded), text: 'Edit location'),
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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locs = ref.watch(locationsP);
    return locs.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => _LoadError(message: '$e', onRetry: () => refreshAll(ref)),
      data: (all) {
        final q = _search.text.trim().toLowerCase();
        final list = all.where((l) {
          if (_filter == _Filter.active && !l.active) return false;
          if (_filter == _Filter.inactive && l.active) return false;
          return q.isEmpty || l.name.toLowerCase().contains(q) || l.description.toLowerCase().contains(q);
        }).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        final activeCount = all.where((l) => l.active).length;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search locations',
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
              child: Text(all.isEmpty ? 'No stock locations yet.' : 'No locations match your search.'),
            )
          else
            for (final l in list) ...[
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => _showDetails(context, l.id),
                leading: const CircleAvatar(radius: 18, child: Icon(Icons.place_rounded, size: 18)),
                title: Text(l.name),
                subtitle: Text(l.description.isEmpty ? 'No description' : l.description),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  _statusChip(l.active),
                  if (widget.canManage)
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () => widget.onEdit(l.id),
                      icon: const Icon(Icons.edit_rounded),
                    ),
                ]),
              ),
            ],
        ]);
      },
    );
  }

  /// Opens a dialog that loads the location by id (GET /stock-locations/{id}).
  Future<void> _showDetails(BuildContext context, int id) {
    final repo = ref.read(repoProvider);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Location details'),
        content: BVSurface(
          child: SizedBox(
            width: 380,
            child: FutureBuilder<Location>(
              future: repo.location(id),
              builder: (_, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
                }
                if (snap.hasError) return Text('${snap.error}');
                final l = snap.data!;
                return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.name, style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(l.description.isEmpty ? 'No description' : l.description),
                  const SizedBox(height: 12),
                  Row(children: [
                    _statusChip(l.active),
                    const SizedBox(width: 12),
                    Text('ID ${l.id}', style: Theme.of(ctx).textTheme.labelMedium),
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
    final exists = (ref.read(locationsP).valueOrNull ?? <Location>[]).any((l) => l.name.toLowerCase() == s.toLowerCase());
    return exists ? 'A stock location with this name already exists' : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await act(
      context,
      ref,
      () => ref.read(repoProvider).createLocation(_name.text.trim(), _desc.text.trim()),
      'Stock location added.',
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
    ref.watch(locationsP); // loaded so the duplicate-name check has data
    return Form(
      key: _form,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Location name *', hintText: 'e.g. Main Store'),
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
            label: const Text('Add location'),
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
  Location? _loaded;
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
      final l = await ref.read(repoProvider).location(id); // GET /stock-locations/{id}
      if (!mounted) return;
      setState(() {
        _loaded = l;
        _name.text = l.name;
        _desc.text = l.description;
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
    final l = _loaded;
    return l != null && (_name.text.trim() != l.name || _desc.text.trim() != l.description);
  }

  String? _nameRule(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Name is required';
    if (s.length > 100) return 'Maximum 100 characters';
    final clash = (ref.read(locationsP).valueOrNull ?? <Location>[])
        .any((l) => l.id != _loaded?.id && l.name.toLowerCase() == s.toLowerCase());
    return clash ? 'Another stock location already uses this name' : null;
  }

  Future<void> _save() async {
    final l = _loaded;
    if (l == null || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await act(
      context,
      ref,
      () => ref.read(repoProvider).updateLocation(l.id, _name.text.trim(), _desc.text.trim()),
      'Stock location updated.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) await _load(l.id);
  }

  Future<void> _deactivate() async {
    final l = _loaded;
    if (l == null) return;

    // The backend lets a location be deactivated even if it holds stock, so
    // warn when there is stock on hand here.
    var warning = '';
    try {
      final balances = await ref.read(balancesP.future);
      final here = balances.where((b) => b.location.id == l.id && b.qty > 0).length;
      if (here > 0) {
        warning = '\n\nWarning: this location still holds stock for $here item${here == 1 ? '' : 's'}. '
            'Move or issue it first if it should not stay here.';
      }
    } catch (_) {
      // Stock balances could not be checked; carry on without the warning.
    }
    if (!mounted) return;

    final yes = await confirmDialog(
      context,
      title: 'Deactivate "${l.name}"?',
      message: 'The location stays in the system for past records. This app cannot reactivate it.$warning',
      confirmLabel: 'Deactivate',
    );
    if (!yes || !mounted) return;
    setState(() => _busy = true);
    final ok = await act(
      context,
      ref,
      () => ref.read(repoProvider).deactivateLocation(l.id),
      'Stock location deactivated.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) await _load(l.id);
  }

  @override
  Widget build(BuildContext context) {
    final locs = [...(ref.watch(locationsP).valueOrNull ?? <Location>[])]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final selected = locs.any((l) => l.id == widget.selectedId) ? widget.selectedId : null;
    final t = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DropdownButtonFormField<int>(
          value: selected,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Stock location'),
          hint: const Text('Select a location to edit'),
          items: [
            for (final l in locs)
              DropdownMenuItem(value: l.id, child: Text(l.active ? l.name : '${l.name} (inactive)')),
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
          const Text('Pick a location above to change its name or description.')
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
              TextFormField(
                controller: _name,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Location name *'),
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
                title: const Text('Location active'),
                subtitle: Text(_loaded!.active
                    ? 'Switch off to deactivate. Its history is kept, and this app cannot reactivate it.'
                    : 'This location is inactive. Reactivating is not available yet.'),
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
