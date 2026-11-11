import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../state/providers.dart';
import '../theme/bv_theme.dart';

class RequisitionDetailScreen extends ConsumerStatefulWidget {
  const RequisitionDetailScreen({super.key, required this.requisitionId});

  final String requisitionId;

  @override
  ConsumerState<RequisitionDetailScreen> createState() =>
      _RequisitionDetailScreenState();
}

class _RequisitionDetailScreenState extends ConsumerState<RequisitionDetailScreen> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _showRejectDialog(BuildContext context, RequisitionModel req) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject Requisition'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'A mandatory comment is required for rejection (minimum 10 characters):',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(labelText: 'Rejection Reason *'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (_commentController.text.trim().length < 10) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Reason must be at least 10 characters long.'),
                  ),
                );
                return;
              }
              ref.read(appStateProvider.notifier).updateStatus(
                    req.id,
                    'Rejected',
                    comment: _commentController.text.trim(),
                  );
              Navigator.pop(dialogContext); // close dialog
              Navigator.pop(context); // close detail screen
            },
            style: FilledButton.styleFrom(backgroundColor: BVColors.error),
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
  }

  String _nextStatus(String current) {
    switch (current) {
      case 'Pending Head':
        return 'Pending OM';
      case 'Pending OM':
        return 'Pending HO';
      case 'Pending HO':
        return 'Approved';
      default:
        return 'Pending Head';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final req = appState.requisitions.firstWhere((r) => r.id == widget.requisitionId);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('Review: ${req.id}')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (req.status == 'Rejected' && req.rejectionComment != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: BVColors.error),
              ),
              child: Text(
                'REJECTED: ${req.rejectionComment}',
                style: const TextStyle(
                  color: BVColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Text(
            '${req.department} Department Requisition',
            style: theme.textTheme.headlineMedium,
          ),
          Text(
            'Status: ${req.status} • Total Value: \$${req.totalValue.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 24),
          Text('Line Items & Stores Decisions', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: req.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final item = req.items[idx];
                return ListTile(
                  title: Text(item.itemName),
                  subtitle: Text(
                    'Requested: ${item.qtyRequested} ${item.unit} • On Hand: ${item.onHand}',
                  ),
                  trailing: Chip(
                    label: Text(item.storesDecision),
                    backgroundColor: BVColors.orangeTint,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRejectDialog(context, req),
                  icon: const Icon(Icons.close, color: BVColors.error),
                  label: const Text(
                    'Reject Requisition',
                    style: TextStyle(color: BVColors.error),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    ref
                        .read(appStateProvider.notifier)
                        .updateStatus(req.id, _nextStatus(req.status));
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Approve & Forward'),
                  style: FilledButton.styleFrom(backgroundColor: BVColors.blue),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
