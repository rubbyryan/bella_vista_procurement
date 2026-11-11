import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme/bv_theme.dart';
import 'requisition_detail_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          '${appState.currentRole.name.toUpperCase()} DASHBOARD',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            _KpiCard(title: 'Awaiting My Review', count: '5', icon: Icons.pending_actions),
            _KpiCard(title: 'Open Requisitions', count: '12', icon: Icons.shopping_cart),
            _KpiCard(title: 'Below Reorder Level', count: '8', icon: Icons.warning_amber),
            _KpiCard(title: 'Deliveries Expected', count: '3', icon: Icons.local_shipping),
          ],
        ),
        const SizedBox(height: 32),
        Text('Active Requisitions Queue', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: appState.requisitions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final req = appState.requisitions[index];
              return ListTile(
                title: Text(
                  '${req.id} • ${req.department} Department',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Requested by ${req.requesterName} on ${req.date} • Total: \$${req.totalValue.toStringAsFixed(2)}',
                ),
                trailing: Chip(
                  label: Text(req.status),
                  backgroundColor: req.status == 'Approved'
                      ? Colors.green.shade100
                      : BVColors.orangeTint,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RequisitionDetailScreen(requisitionId: req.id),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.title, required this.count, required this.icon});

  final String title;
  final String count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: BVColors.blue),
            const Spacer(),
            Text(count, style: theme.textTheme.displaySmall),
            const SizedBox(height: 4),
            Text(title, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
