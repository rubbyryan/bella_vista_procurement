import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/state.dart';
import '../../core/user_store.dart';
import '../../core/widgets.dart';

/// Dashboard for SUPER_ADMIN and SYSTEM_ADMIN. It only shows information about
/// user accounts (from GET /api/procurement/users) and nothing about requisitions,
/// purchasing or stock.
class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider);
    if (me == null) return const SizedBox();
    final async = ref.watch(usersP);

    PageBody wrap(List<Widget> children) => PageBody(
      title: '${me.roleTitle} Dashboard',
      subtitle: '${_greeting()}, ${me.name.split(' ').first}',
      actions: [
        OutlinedButton.icon(
          style: canvasOutlined(context),
          onPressed: () => ref.invalidate(usersP),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
        ),
      ],
      children: children,
    );

    if (async.hasError && !async.hasValue) {
      return wrap([
        Panel(
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
        ),
      ]);
    }
    if (!async.hasValue) {
      return wrap(const [
        Panel(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))),
      ]);
    }

    final users = async.requireValue;
    final statusKnown = users.isNotEmpty && users.any((u) => u.active != null);
    final active = users.where((u) => u.active == true).length;
    final waiting = users.where((u) => u.active == false).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    final locked = users.where((u) => u.accountLocked == true).length;
    final admins = users.where((u) => u.roleCode == kSuperAdmin || u.roleCode == kSystemAdmin).length;

    final byRole = <String, int>{};
    final byDept = <String, int>{};
    for (final u in users) {
      byRole[u.roleName] = (byRole[u.roleName] ?? 0) + 1;
      final d = u.department.trim().isEmpty ? 'No department' : u.department.trim();
      byDept[d] = (byDept[d] ?? 0) + 1;
    }

    void goUsers() => context.go('/app/users');

    final kpis = <Widget>[
      KpiCard(label: 'Total users', value: '${users.length}', icon: Icons.people_alt_rounded, onTap: goUsers),
      if (statusKnown)
        KpiCard(label: 'Active users', value: '$active', icon: Icons.verified_user_rounded, onTap: goUsers),
      if (statusKnown)
        KpiCard(
          label: 'Awaiting activation',
          value: '${waiting.length}',
          icon: Icons.pending_actions_rounded,
          warn: waiting.isNotEmpty,
          onTap: goUsers,
        ),
      if (statusKnown && locked > 0)
        KpiCard(label: 'Locked accounts', value: '$locked', icon: Icons.lock_rounded, warn: true, onTap: goUsers),
      KpiCard(label: 'Administrators', value: '$admins', icon: Icons.admin_panel_settings_rounded, onTap: goUsers),
    ];

    final waitingPanel = Panel(
      title: 'Waiting for activation (${waiting.length})',
      child: !statusKnown
          ? const Text('Account status is not available from the server yet.')
          : waiting.isEmpty
          ? const Text('No accounts are waiting for activation.')
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final u in waiting.take(8)) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            onTap: goUsers,
            leading: CircleAvatar(
              radius: 16,
              child: Text(u.firstName.isEmpty ? '?' : u.firstName[0].toUpperCase()),
            ),
            title: Text(u.name),
            subtitle: Text(
              '${u.username} | ${u.roleName} | ${u.department.isEmpty ? 'No department' : u.department}',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ],
        if (waiting.length > 8)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton(onPressed: goUsers, child: Text('View all ${waiting.length}')),
          ),
      ]),
    );

    final rolePanel = Panel(title: 'Users by role', child: _CountList(counts: byRole));
    final deptPanel = Panel(title: 'Users by department', child: _CountList(counts: byDept));

    return wrap([
      ResponsiveGrid(children: kpis),
      const SizedBox(height: 16),
      TwoCol(left: waitingPanel, right: rolePanel),
      const SizedBox(height: 16),
      deptPanel,
    ]);
  }
}

/// Label, count and a small proportion bar per row, largest first.
class _CountList extends StatelessWidget {
  const _CountList({required this.counts});
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    if (counts.isEmpty) return const Text('No users yet.');
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.first.value;
    return Column(children: [
      for (final e in entries)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(flex: 4, child: Text(e.key, overflow: TextOverflow.ellipsis)),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: LinearProgressIndicator(value: max == 0 ? 0 : e.value / max, minHeight: 8),
              ),
            ),
            SizedBox(width: 32, child: Text('${e.value}', textAlign: TextAlign.end)),
          ]),
        ),
    ]);
  }
}