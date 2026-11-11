import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/bv_theme.dart';
import '../../core/widgets.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  Color _heroColor(BuildContext c) {
    if (isPrimaryMode(c)) return BVColors.blue;
    if (isDarkMode(c)) return BVColors.darkSurface;
    return BVColors.blueTint;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final w = MediaQuery.sizeOf(context).width;
    final wide = w >= 900;
    final canvas = onCanvas(context);

    final heroText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StatusChip('Procurement Portal', StatusKind.neutral),
        const SizedBox(height: 16),
        Text('Bella Vista\nProcurement System',
            style: t.displaySmall?.copyWith(fontSize: wide ? 48 : 32, height: 1.1)),
        const SizedBox(height: 12),
        Text('Thinking Beyond Clear Vision',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                color: isPrimaryMode(context)
                    ? BVColors.orange
                    : (isDarkMode(context) ? BVColors.darkOrange : const Color(0xFFA3470A)))),
        const SizedBox(height: 4),
        Text('Bella Vista College', style: t.bodyLarge),
        const SizedBox(height: 12),
        Text('Request, approve, buy, receive and track school supplies in one place.',
            style: t.bodyLarge?.copyWith(color: canvas.withValues(alpha: 0.85))),
        const SizedBox(height: 24),
        Wrap(spacing: 12, runSpacing: 12, children: [
          FilledButton(
              style: ctaStyle(context),
              onPressed: () => context.go('/auth?mode=login'),
              child: const Text('Sign in')),
          OutlinedButton(
              style: canvasOutlined(context),
              onPressed: () => context.go('/auth?mode=register'),
              child: const Text('Register')),
        ]),
      ],
    );

    final hero = Container(
      color: _heroColor(context),
      padding: EdgeInsets.symmetric(horizontal: wide ? 64 : 20, vertical: wide ? 56 : 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: heroText),
                    const SizedBox(width: 48),
                    const LogoBadge(size: 300),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(child: LogoBadge(size: 140)),
                    const SizedBox(height: 20),
                    heroText,
                  ],
                ),
        ),
      ),
    );

    const steps = ['Request', 'Stores check', 'Head', 'Operations', 'Head Office', 'Deliver & stock'];

    return Scaffold(
      body: ListView(children: [
        // nav bar
        Container(
          color: isPrimaryMode(context)
              ? const Color(0xFF1F2870)
              : Theme.of(context).colorScheme.surface,
          padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 12, vertical: 10),
          child: Row(children: [
            const LogoBadge(size: 40),
            const SizedBox(width: 10),
            Flexible(
              child: Text('Bella Vista College',
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium?.copyWith(
                      color: isPrimaryMode(context) ? Colors.white : null)),
            ),
            const Spacer(),
            const AppearanceMenuButton(),
            const SizedBox(width: 4),
            OutlinedButton(
              style: isPrimaryMode(context)
                  ? OutlinedButton.styleFrom(
                      foregroundColor: Colors.white, side: const BorderSide(color: Colors.white))
                  : null,
              onPressed: () => context.go('/auth?mode=login'),
              child: const Text('Sign in'),
            ),
          ]),
        ),
        hero,
        Padding(
          padding: EdgeInsets.symmetric(horizontal: wide ? 64 : 20, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ResponsiveGrid(minWidth: 280, children: const [
                  _ValueCard(Icons.description_rounded, 'Requisitions',
                      'Raise and track requests from any department'),
                  _ValueCard(Icons.check_circle_rounded, 'Approvals',
                      'Clear approve / reject chain with comments'),
                  _ValueCard(Icons.local_shipping_rounded, 'Stock & delivery',
                      'Signed deliveries and automatic reorder alerts'),
                ]),
                const SizedBox(height: 32),
                Text('How it works', style: t.titleMedium),
                const SizedBox(height: 16),
                Wrap(spacing: 24, runSpacing: 16, children: [
                  for (var i = 0; i < steps.length; i++)
                    SizedBox(
                      width: 120,
                      child: Column(children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: i == 0
                              ? Theme.of(context).colorScheme.secondary
                              : (isDarkMode(context) ? BVColors.darkBlue : BVColors.blue),
                          foregroundColor: i == 0
                              ? Theme.of(context).colorScheme.onSecondary
                              : (isDarkMode(context) ? BVColors.ink : Colors.white),
                          child: Text('${i + 1}', style: const TextStyle(fontFamily: 'Poppins')),
                        ),
                        const SizedBox(height: 6),
                        Text(steps[i], textAlign: TextAlign.center, style: t.labelSmall),
                      ]),
                    ),
                ]),
              ]),
            ),
          ),
        ),
        Container(
          color: BVColors.ink,
          padding: const EdgeInsets.all(16),
          child: const Center(
            child: Text('Copyright 2026 Bella Vista College | Mazowe, Zimbabwe',
                style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ),
      ]),
    );
  }
}

class _ValueCard extends StatelessWidget {
  const _ValueCard(this.icon, this.title, this.text);
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Builder(builder: (c) {
        final t = Theme.of(c);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
              backgroundColor: t.colorScheme.primaryContainer,
              child: Icon(icon, color: t.colorScheme.onPrimaryContainer)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(text),
            ]),
          ),
        ]);
      }),
    );
  }
}
