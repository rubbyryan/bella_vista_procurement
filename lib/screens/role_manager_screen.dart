import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../state/providers.dart';

class RoleManagerScreen extends ConsumerWidget {
  const RoleManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Switch User Role for Testing', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 16),
        ...UserRole.values.map(
          (role) => RadioListTile<UserRole>(
            title: Text(role.name.toUpperCase()),
            value: role,
            groupValue: appState.currentRole,
            onChanged: (val) {
              if (val != null) ref.read(appStateProvider.notifier).setRole(val);
            },
          ),
        ),
      ],
    );
  }
}
