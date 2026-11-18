import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/state.dart';
import '../../core/theme/bv_theme.dart';
import '../../core/user_store.dart';
import '../../core/widgets.dart';

/// User management, backed by the server:
///   GET    /api/procurement/users          list
///   GET    /api/procurement/users/{id}     details (loaded when a user is opened)
///   POST   /api/procurement/users          create
///   PUT    /api/procurement/users/{id}     update
///   DELETE /api/procurement/users/{id}     deactivate
///   PATCH  /api/procurement/users/{id}/activate   activate an account (e.g. a new registration)
/// Only SUPER_ADMIN and SYSTEM_ADMIN can call these; the server enforces it.
/// Activation: SUPER_ADMIN can activate anyone; SYSTEM_ADMIN can activate regular users only.
class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  static const _wide = 900.0;
  final _search = TextEditingController();
  bool _inactiveOnly = false;
  int? _selectedId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AppUser> _filtered(List<AppUser> all) {
    final q = _search.text.trim().toLowerCase();
    final list = all.where((u) {
      if (_inactiveOnly && u.active != false) return false;
      if (q.isEmpty) return true;
      return u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.username.toLowerCase().contains(q) ||
          u.employeeNumber.toLowerCase().contains(q) ||
          u.department.toLowerCase().contains(q) ||
          u.roleName.toLowerCase().contains(q);
    }).toList();
    // Inactive accounts first so they are easy to find, then by name.
    list.sort((a, b) {
      final ai = a.active == false, bi = b.active == false;
      if (ai != bi) return ai ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
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
            child: _UserEditor(key: ValueKey(u.id), userId: u.id, onDone: () => Navigator.of(ctx).pop()),
          ),
        ),
      ),
    );
  }

  void _create() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _UserForm(onDone: () => Navigator.of(ctx).pop()),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider);
    if (me == null) return const SizedBox();
    final wide = MediaQuery.sizeOf(context).width >= _wide;
    final async = ref.watch(usersP);

    Widget body;
    if (async.hasError && !async.hasValue) {
      body = Panel(
        title: 'Users',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${async.error}', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(usersP),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ]),
      );
    } else if (!async.hasValue) {
      body = const Panel(
        title: 'Users',
        child: Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
      );
    } else {
      final all = async.requireValue;
      final users = _filtered(all);
      final inactive = all.where((u) => u.active == false).length;
      final statusMissing = all.isNotEmpty && all.every((u) => u.active == null);

      final list = Panel(
        title: 'Users (${users.length})',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (statusMissing) ...[
            Text(
              'The server did not send account status (active / locked), so it cannot be shown. '
                  'Apply backend_patch/UserResponse.java to see it.',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
          ],
          if (!statusMissing && inactive > 0) ...[
            Text(
              inactive == 1 ? '1 account is waiting for activation.' : '$inactive accounts are waiting for activation.',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
          ],
          Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search name, username, email, role...',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
            if (!statusMissing)
              FilterChip(
                label: Text('Awaiting activation / inactive ($inactive)'),
                selected: _inactiveOnly,
                onSelected: (v) => setState(() => _inactiveOnly = v),
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
                  '${u.username} | ${u.email}\n${u.roleName} | ${u.department.isEmpty ? 'No department' : u.department}',
                ),
                isThreeLine: true,
                trailing: _statusChip(u),
              ),
            ],
        ]),
      );

      final editor = Panel(
        title: 'User details',
        child: _selectedId == null
            ? const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Pick a user from the list to view or edit the account, or use New user.'),
        )
            : _UserEditor(key: ValueKey(_selectedId), userId: _selectedId!),
      );
      body = wide ? TwoCol(left: list, right: editor) : list;
    }

    return PageBody(
      title: 'Users & roles',
      subtitle: 'Create accounts, assign roles and departments, and deactivate users.',
      actions: [
        OutlinedButton.icon(
          style: canvasOutlined(context),
          onPressed: () => ref.invalidate(usersP),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
        ),
        FilledButton.icon(
          style: ctaStyle(context),
          onPressed: _create,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('New user'),
        ),
      ],
      children: [body],
    );
  }
}

Widget? _statusChip(AppUser u) {
  if (u.accountLocked == true) return const StatusChip('Locked', StatusKind.danger);
  if (u.active == true) return const StatusChip('Active', StatusKind.success);
  if (u.active == false) return const StatusChip('Inactive', StatusKind.pending);
  return null;
}

/// Loads one user with GET /users/{id}, then shows the form.
class _UserEditor extends ConsumerWidget {
  const _UserEditor({super.key, required this.userId, this.onDone});
  final int userId;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(userByIdP(userId));
    return a.when(
      skipLoadingOnReload: true,
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$e', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => ref.invalidate(userByIdP(userId)), child: const Text('Try again')),
      ]),
      data: (u) => _UserForm(key: ValueKey(u.id), user: u, onDone: onDone),
    );
  }
}

/// Create (user == null) or edit (user != null) form.
class _UserForm extends ConsumerStatefulWidget {
  const _UserForm({super.key, this.user, this.onDone});
  final AppUser? user;
  final VoidCallback? onDone;

  @override
  ConsumerState<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends ConsumerState<_UserForm> {
  final _form = GlobalKey<FormState>();
  late final _emp = TextEditingController(text: widget.user?.employeeNumber ?? '');
  late final _first = TextEditingController(text: widget.user?.firstName ?? '');
  late final _last = TextEditingController(text: widget.user?.lastName ?? '');
  late final _username = TextEditingController(text: widget.user?.username ?? '');
  late final _email = TextEditingController(text: widget.user?.email ?? '');
  late final _phone = TextEditingController(text: widget.user?.phoneNumber ?? '');
  late final _job = TextEditingController(text: widget.user?.jobTitle ?? '');
  final _password = TextEditingController();
  late String _roleCode = widget.user?.roleCode ?? 'REQUESTER';
  late String _dept = widget.user?.department ?? '';
  bool _showPw = false;
  bool _busy = false;
  String? _error;

  bool get _creating => widget.user == null;
  String get _myRole => ref.read(sessionProvider)?.roleCode ?? '';

  @override
  void dispose() {
    for (final c in [_emp, _first, _last, _username, _email, _phone, _job, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Mirrors the server rules so the form says why a user cannot be edited.
  String? get _readOnlyReason {
    final u = widget.user;
    if (u == null) return null;
    if (u.roleCode == kSuperAdmin) return 'SUPER_ADMIN accounts cannot be changed here.';
    if (u.roleCode == kSystemAdmin && _myRole != kSuperAdmin) {
      return 'Only a SUPER_ADMIN can manage System Administrator accounts.';
    }
    return null;
  }

  List<BackendRole> _allowedRoles() {
    final list = kBackendRoles.where((r) {
      if (r.code == kSuperAdmin) return false; // never assignable
      if (r.code == kSystemAdmin && _myRole != kSuperAdmin) return false;
      return true;
    }).toList();
    final cur = widget.user?.roleCode;
    if (cur != null && !list.any((r) => r.code == cur)) {
      list.add(BackendRole(cur, roleLabel(cur), appRoleFor(cur)));
    }
    return list;
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _emailRule(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Required';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return 'Enter a valid email address';
    return null;
  }

  // The server only requires 8+ characters (and a password when creating).
  String? _passwordRule(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return _creating ? 'Required' : null;
    return s.length < 8 ? 'At least 8 characters' : null;
  }

  UserForm _formValues() => UserForm(
    employeeNumber: _emp.text,
    firstName: _first.text,
    lastName: _last.text,
    username: _username.text,
    email: _email.text,
    phoneNumber: _phone.text,
    password: _password.text,
    roleCode: _roleCode,
    department: _dept,
    jobTitle: _job.text,
  );

  Future<void> _run(Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message = await action();
      ref.invalidate(usersP);
      final id = widget.user?.id;
      if (id != null) ref.invalidate(userByIdP(id));
      if (!mounted) return;
      snack(context, message);
      _password.clear();
      widget.onDone?.call();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = ref.read(userRepoProvider);
    final u = widget.user;
    await _run(() async {
      if (u == null) {
        final saved = await repo.create(_formValues());
        return saved.roleCode == kSystemAdmin
            ? 'Created ${saved.name}. A SUPER_ADMIN must activate this administrator before they can sign in.'
            : 'Created ${saved.name}.';
      }
      final saved = await repo.update(u.id, _formValues());
      return 'Saved ${saved.name}.';
    });
  }

  Future<void> _deactivate() async {
    final u = widget.user!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Deactivate ${u.name}?'),
        content: const Text(
          'They will no longer be able to sign in until an administrator activates the account again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Deactivate')),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(userRepoProvider);
    await _run(() async {
      await repo.deactivate(u.id);
      return '${u.name} deactivated.';
    });
  }

  Future<void> _activate() async {
    final u = widget.user!;
    final repo = ref.read(userRepoProvider);
    await _run(() async {
      await repo.activate(u.id);
      return '${u.name} activated. They can now sign in.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final u = widget.user;
    final reason = _readOnlyReason;
    final enabled = reason == null && !_busy;
    final roles = _allowedRoles();
    final depts = [...kUserDepartments];
    if (_dept.isNotEmpty && !depts.contains(_dept)) depts.insert(0, _dept);
    // Mirrors the server: SUPER_ADMIN activates anyone; SYSTEM_ADMIN activates regular users only.
    final canActivate = u != null &&
        u.active != true &&
        u.roleCode != kSuperAdmin &&
        (_myRole == kSuperAdmin || (_myRole == kSystemAdmin && u.roleCode != kSystemAdmin));
    final canDeactivate = u != null && reason == null && u.active != false;

    return Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(u == null ? 'New user' : u.name, style: t.textTheme.titleLarge)),
          if (u != null && _statusChip(u) != null) _statusChip(u)!,
        ]),
        if (u != null) ...[
          const SizedBox(height: 4),
          Text(
            '${u.createdAt == null ? '' : 'Registered ${_fmt(u.createdAt!)} | '}'
                '${u.lastLogin == null ? 'Never signed in' : 'Last sign-in ${_fmt(u.lastLogin!)}'}',
            style: t.textTheme.labelMedium,
          ),
        ],
        if (u != null && u.active == false) ...[
          const SizedBox(height: 8),
          Text(
            'This account is not active, so the user cannot sign in until it is activated.',
            style: t.textTheme.labelLarge,
          ),
        ],
        if (reason != null) ...[
          const SizedBox(height: 8),
          Text(reason, style: t.textTheme.labelMedium),
        ],
        const SizedBox(height: 16),
        TextFormField(
          controller: _emp,
          enabled: enabled,
          decoration: const InputDecoration(labelText: 'Employee number'),
          validator: _required,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _first,
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'First name'),
          validator: _required,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _last,
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Last name'),
          validator: _required,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _username,
          enabled: enabled,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Username', helperText: 'Used to sign in'),
          validator: _required,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _email,
          enabled: enabled,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email address'),
          validator: _emailRule,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phone,
          enabled: enabled,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone number (optional)', hintText: '+263 77 123 4567'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: roles.any((r) => r.code == _roleCode) ? _roleCode : null,
          decoration: const InputDecoration(labelText: 'Role'),
          items: [for (final r in roles) DropdownMenuItem(value: r.code, child: Text(r.label))],
          onChanged: enabled ? (v) => setState(() => _roleCode = v ?? _roleCode) : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _dept,
          decoration: const InputDecoration(labelText: 'Department'),
          items: [
            const DropdownMenuItem(value: '', child: Text('No department')),
            for (final d in depts) DropdownMenuItem(value: d, child: Text(d)),
          ],
          onChanged: enabled ? (v) => setState(() => _dept = v ?? '') : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _job,
          enabled: enabled,
          decoration: const InputDecoration(labelText: 'Job title (optional)'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _password,
          enabled: enabled,
          obscureText: !_showPw,
          decoration: InputDecoration(
            labelText: _creating ? 'Password' : 'New password (optional)',
            helperText: _creating ? 'At least 8 characters' : 'Leave blank to keep the current password',
            suffixIcon: IconButton(
              tooltip: _showPw ? 'Hide password' : 'Show password',
              onPressed: () => setState(() => _showPw = !_showPw),
              icon: Icon(_showPw ? Icons.visibility_off_rounded : Icons.visibility_rounded),
            ),
          ),
          validator: _passwordRule,
        ),
        if (_creating && _roleCode == kSystemAdmin) ...[
          const SizedBox(height: 8),
          Text('System Administrator accounts start inactive until a SUPER_ADMIN activates them.',
              style: t.textTheme.labelMedium),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: t.colorScheme.error)),
        ],
        const SizedBox(height: 16),
        if (canActivate) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: ctaStyle(context),
              onPressed: _busy ? null : _activate,
              child: Text(u.roleCode == kSystemAdmin ? 'Activate administrator' : 'Activate account'),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (reason == null)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Working...' : (_creating ? 'Create user' : 'Save changes')),
            ),
          ),
        if (canDeactivate) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: dangerOutlined(context),
              onPressed: _busy ? null : _deactivate,
              child: const Text('Deactivate account'),
            ),
          ),
        ],
      ]),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}