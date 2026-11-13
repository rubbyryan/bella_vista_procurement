import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/state.dart';
import '../../core/theme/bv_theme.dart';
import '../../core/widgets.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final _server = TextEditingController(text: ref.read(apiBaseProvider));

  @override
  void dispose() {
    _server.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider);
    if (me == null) return const SizedBox();
    return PageBody(
      title: 'Settings',
      subtitle: 'Me > Appearance',
      children: [
        Panel(
          title: 'Profile',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(me.name),
            Text(me.role.label),
            if (me.department.isNotEmpty) Text('Department: ${me.department}'),
            const SizedBox(height: 8),
            const Text('The backend has no login yet: this name is sent with every action so the record shows who did it.'),
          ]),
        ),
        Panel(
          title: 'Appearance',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Choose how the app looks on this device.'),
            const SizedBox(height: 12),
            const SingleChildScrollView(scrollDirection: Axis.horizontal, child: AppearancePicker()),
          ]),
        ),
        Panel(
          title: 'Server',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: _server, decoration: const InputDecoration(labelText: 'Server address')),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: [
              FilledButton(
                onPressed: () {
                  ref.read(apiBaseProvider.notifier).set(_server.text);
                  refreshAll(ref);
                  snack(context, 'Saved. Data will reload from ${_server.text.trim()}.');
                },
                child: const Text('Save'),
              ),
              OutlinedButton(
                onPressed: () => ref.read(sessionProvider.notifier).logout(),
                child: const Text('Switch user'),
              ),
            ]),
          ]),
        ),
      ],
    );
  }
}