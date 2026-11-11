import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../state/providers.dart';
import '../theme/bv_theme.dart';
import 'requisition_detail_screen.dart';

class RequisitionsScreen extends ConsumerWidget {
  const RequisitionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NewRequisitionForm()),
        ),
        backgroundColor: BVColors.orange,
        icon: const Icon(Icons.add, color: BVColors.ink),
        label: const Text(
          'New Requisition',
          style: TextStyle(color: BVColors.ink, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Requisitions Management', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 16),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Reference')),
                  DataColumn(label: Text('Department')),
                  DataColumn(label: Text('Requester')),
                  DataColumn(label: Text('Value')),
                  DataColumn(label: Text('Status')),
                ],
                rows: appState.requisitions.map((req) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(req.id, style: const TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RequisitionDetailScreen(requisitionId: req.id),
                          ),
                        ),
                      ),
                      DataCell(Text(req.department)),
                      DataCell(Text(req.requesterName)),
                      DataCell(Text('\$${req.totalValue.toStringAsFixed(2)}')),
                      DataCell(
                        Chip(
                          label: Text(req.status, style: const TextStyle(fontSize: 11)),
                          backgroundColor: req.status == 'Rejected'
                              ? Colors.red.shade100
                              : BVColors.blueTint,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NewRequisitionForm extends ConsumerStatefulWidget {
  const NewRequisitionForm({super.key});

  @override
  ConsumerState<NewRequisitionForm> createState() => _NewRequisitionFormState();
}

class _NewRequisitionFormState extends ConsumerState<NewRequisitionForm> {
  final _departmentController = TextEditingController(text: 'Science');
  final _justificationController = TextEditingController();
  final List<RequisitionItemModel> _items = [
    RequisitionItemModel(
      itemName: 'A4 Paper Ream',
      unit: 'ream',
      qtyRequested: 10,
      onHand: 14,
      estPrice: 45.00,
    ),
  ];

  @override
  void dispose() {
    _departmentController.dispose();
    _justificationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Raise New Requisition')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _departmentController,
            decoration: const InputDecoration(labelText: 'Department'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _justificationController,
            decoration: const InputDecoration(labelText: 'Justification / Purpose'),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          Text('Requisition Items & Stock Hints', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._items.map(
            (item) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(item.itemName),
                subtitle: Text(
                  'On Hand: ${item.onHand} (${item.onHand <= 15 ? "LOW STOCK" : "OK"}) • Est: \$${item.estPrice}',
                ),
                trailing: Text('Qty: ${item.qtyRequested} ${item.unit}'),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              final total = _items.fold<double>(0, (sum, i) => sum + i.estPrice);
              final newReq = RequisitionModel(
                id: 'REQ-2026-0150',
                department: _departmentController.text,
                requesterName: 'Current User',
                date: '05 Nov 2026',
                totalValue: total,
                status: 'Stores Review',
                items: _items,
              );
              ref.read(appStateProvider.notifier).addRequisition(newReq);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: BVColors.orange,
              foregroundColor: BVColors.ink,
            ),
            child: const Text('Submit Requisition to Stores'),
          ),
        ],
      ),
    );
  }
}
