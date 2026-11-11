import 'package:flutter/material.dart';

import '../theme/bv_theme.dart';

class DeliveryVoucherScreen extends StatelessWidget {
  const DeliveryVoucherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Purchase Vouchers & Delivery Notes',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Voucher No: PV-2026-0087',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Text('Supplier: Chikore Scientific Supplies • Amount: \$246.50'),
                const Divider(height: 24),
                const Text(
                  'Delivery Chain of Custody (3 Signatures):',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const LinearProgressIndicator(value: 0.66),
                const SizedBox(height: 12),
                const Text('1. Driver Collection: Farai Ndlovu (Signed) ✓'),
                const Text('2. Gate Security: S. Mhlanga (Inspected & Signed) ✓'),
                const Text('3. Stores Controller: Pending Final Goods Receipt'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Stores Controller signed and stock added successfully!'),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(backgroundColor: BVColors.success),
                  child: const Text('Sign & Add to Stock'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
