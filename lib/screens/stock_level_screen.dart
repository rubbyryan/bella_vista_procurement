import 'package:flutter/material.dart';

import '../theme/bv_theme.dart';

class StockLevelScreen extends StatelessWidget {
  const StockLevelScreen({super.key});

  static const List<Map<String, Object>> _inventory = [
    {'name': 'A4 Paper (ream)', 'onHand': 14, 'reorder': 20, 'buffer': 8, 'status': 'Reorder'},
    {'name': 'Marker Pens (box)', 'onHand': 2, 'reorder': 12, 'buffer': 5, 'status': 'Critical'},
    {'name': 'Chalk (box)', 'onHand': 8, 'reorder': 12, 'buffer': 6, 'status': 'Reorder'},
    {'name': 'Toilet Paper (pack)', 'onHand': 0, 'reorder': 15, 'buffer': 8, 'status': 'Out of stock'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Stock Room & Buffer Levels', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 16),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _inventory.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, idx) {
              final item = _inventory[idx];
              final status = item['status'] as String;
              final isCritical = status == 'Critical' || status == 'Out of stock';
              return ListTile(
                title: Text(
                  item['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'On Hand: ${item['onHand']} • Reorder Level: ${item['reorder']} • Buffer: ${item['buffer']}',
                ),
                trailing: Chip(
                  label: Text(status),
                  backgroundColor:
                      isCritical ? Colors.red.shade100 : BVColors.orangeTint,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
