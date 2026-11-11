import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/theme/bv_theme.dart';
import '../../core/widgets.dart';

/// System Administrator page: pick a user from the list, assign a role and a
/// department, and activate / deactivate the account with a toggle.
class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  static const _wide = 900.0;
  final _search = TextEditingController();
  bool _pendingOnly = false;
  String? _selectedId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AppUser> _filtered(List<AppUser> all) {
    final q = _search.text.trim().toLowerCase();
    final list = all.where((u) {
      if (_pendingOnly && u.active) return false;
      if (q.isEmpty) return true;
      return u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.username.toLowerCase().contains(q) ||
          u.department.toLowerCase().contains(q);
    }).toList();
    // Inactive accounts first so new registrations are easy to find.
    list.sort((a, b) {
      if (a.active != b.active) return a.active ? 1 : -1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  void _open(AppUser u) {
    final wide = MediaQuery.sizeOf(context).width >= _wide;
    if (wide) {
      setState(() => _selectedId = u.id);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(
          child: Panel(
            child: _AccessEditor(
              key: ValueKey(u.id),
              userId: u.id,
              onSaved: () => Navigator.of(ctx).pop(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(storeProvider);
    final me = s.currentUser;
    if (me == null) return const SizedBox();
    final wide = MediaQuery.sizeOf(context).width >= _wide;
    final users = _filtered(s.users);
    final pending = s.users.where((u) => !u.active).length;
    final selected = wide && _selectedId != null
        ? s.users.where((u) => u.id == _selectedId).firstOrNull
        : null;

    final list = Panel(
      title: 'Users (${users.length})',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search name, email or department',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
          ),
          FilterChip(
            label: Text('Pending only ($pending)'),
            selected: _pendingOnly,
            onSelected: (v) => setState(() => _pendingOnly = v),
          ),
        ]),
        const SizedBox(height: 8),
        if (users.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('No users match your search.'))
        else
          for (final u in users) ...[
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              selected: wide && u.id == _selectedId,
              onTap: () => _open(u),
              leading: CircleAvatar(
                radius: 18,
                child: Text(u.firstName.isEmpty ? '?' : u.firstName[0].toUpperCase()),
              ),
              title: Text(u.name),
              subtitle: Text(
                '${u.email}\n${u.role.label} | ${u.department.isEmpty ? 'No department' : u.department}',
              ),
              isThreeLine: true,
              trailing: StatusChip(
                u.accountLocked ? 'Locked' : (u.active ? 'Active' : 'Pending'),
                u.accountLocked
                    ? StatusKind.danger
                    : (u.active ? StatusKind.success : StatusKind.pending),
              ),
            ),
          ],
      ]),
    );

    final editor = Panel(
      title: 'Role, department & access',
      child: selected == null
          ? const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Pick a user from the list to assign a role and department and activate the account.'),
            )
          : _AccessEditor(key: ValueKey(selected.id), userId: selected.id),
    );

    return PageBody(
      title: 'Users & roles',
      subtitle: 'New registrations stay inactive until you assign a role and department and activate them.',
      children: [
        if (wide) TwoCol(left: list, right: editor) else list,
      ],
    );
  }
}

/// Edits one user's role, department and active flag, then saves them together.
class _AccessEditor extends ConsumerStatefulWidget {
  const _AccessEditor({super.key, required this.userId, this.onSaved});
  final String userId;
  final VoidCallback? onSaved;

  @override
  ConsumerState<_AccessEditor> createState() => _AccessEditorState();
}

class _AccessEditorState extends ConsumerState<_AccessEditor> {
  late Role _role;
  late String _dept; // empty = not assigned yet
  late bool _active;
  String? _error;

  AppUser? get _user {
    for (final u in ref.read(storeProvider).users) {
      if (u.id == widget.userId) return u;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final u = _user!;
    _role = u.role;
    _dept = u.department;
    _active = u.active;
  }

  void _save() {
    final u = _user;
    if (u == null) return;
    final err = ref.read(storeProvider).updateUserAccess(
          u,
          role: _role,
          department: _dept,
          active: _active,
        );
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() => _error = null);
    snack(context, '${u.name}: ${_role.label}, $_dept, ${_active ? 'active' : 'inactive'}.');
    widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final u = _user;
    if (u == null) return const Text('This user no longer exists.');
    final t = Theme.of(context);
    final isSelf = store.currentUser?.id == u.id;
    final dirty = _role != u.role || _dept != u.department || _active != u.active;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(u.name, style: t.textTheme.titleLarge),
      const SizedBox(height: 4),
      Text(u.email),
      if (u.phoneNumber.isNotEmpty) Text(u.phoneNumber),
      Text('Username: ${u.username}', style: t.textTheme.labelMedium),
      Text('Registered ${_fmt(u.createdAt)}'
          '${u.lastLogin == null ? ' | Never signed in' : ' | Last sign-in ${_fmt(u.lastLogin!)}'}',
          style: t.textTheme.labelMedium),
      const SizedBox(height: 16),
      DropdownButtonFormField<Role>(
        value: _role,
        decoration: const InputDecoration(labelText: 'Role'),
        items: [for (final r in Role.values) DropdownMenuItem(value: r, child: Text(r.label))],
        onChanged: isSelf ? null : (r) => setState(() => _role = r ?? _role),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _dept.isEmpty ? null : _dept,
        decoration: const InputDecoration(labelText: 'Department'),
        hint: const Text('Select a department'),
        items: [for (final d in kDepartments) DropdownMenuItem(value: d, child: Text(d))],
        onChanged: (d) => setState(() => _dept = d ?? _dept),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Account active'),
        subtitle: Text(_active ? 'The user can sign in.' : 'The user cannot sign in.'),
        value: _active,
        onChanged: isSelf ? null : (v) => setState(() => _active = v),
      ),
      if (isSelf)
        Text('You cannot change your own role or deactivate your own account.',
            style: t.textTheme.labelMedium),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, style: TextStyle(color: t.colorScheme.error)),
      ],
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: dirty ? _save : null,
          child: const Text('Save changes'),
        ),
      ),
    ]);
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
