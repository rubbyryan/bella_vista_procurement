import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/state.dart';
import '../../core/widgets.dart';

class RequisitionsPage extends ConsumerStatefulWidget {
  const RequisitionsPage({super.key});
  @override
  ConsumerState<RequisitionsPage> createState() => _RequisitionsPageState();
}

class _RequisitionsPageState extends ConsumerState<RequisitionsPage> {
  String? _filter;
  String _q = '';

  static const _pending = ['NEW', 'STORES_REVIEW', 'PENDING_HEAD_APPROVAL', 'PENDING_OM_APPROVAL'];
  static const _issue = ['READY_FOR_ISSUE', 'PARTIALLY_ISSUED'];

  bool _match(Requisition r, String f) => switch (f) {
        'Pending' => _pending.contains(r.status),
        'To issue' => _issue.contains(r.status),
        'Done' => r.status == 'RESOLVED' || r.status == 'CONVERTED_TO_PURCHASE',
        'Rejected' => r.status == 'REJECTED',
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider);
    if (me == null) return const SizedBox();
    final filter = _filter ?? 'All';
    final data = ref.watch(requisitionsP);
    final isRequester = me.role == Role.requester;
    final canCreate = isRequester; // only a Requester can raise a requisition

    return PageBody(
      title: isRequester ? 'My requisitions' : 'Item requisitions',
      subtitle: isRequester
          ? '${me.department.isEmpty ? '' : 'Department: ${me.department}. '}Only your own requisitions are shown.'
          : 'Requester > Stores check > Headmaster > Operations Manager > Issue. Items not in stock go to a purchase request.',
      actions: [
        if (canCreate)
          FilledButton.icon(
            style: ctaStyle(context),
            onPressed: () => context.go('/app/requisitions/new'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New requisition'),
          ),
      ],
      children: [
        AsyncBody<List<Requisition>>(
          value: data,
          onRetry: () => ref.invalidate(requisitionsP),
          builder: (everything) {
            // A requester only ever sees their own requisitions.
            final all = isRequester
                ? everything.where((r) => r.officer.trim().toLowerCase() == me.name.trim().toLowerCase()).toList()
                : everything;
            final q = _q.trim().toLowerCase();
            final list = all.where((r) => _match(r, filter)).where((r) =>
                q.isEmpty || r.number.toLowerCase().contains(q) || r.department.toLowerCase().contains(q) || r.officer.toLowerCase().contains(q)).toList()
              ..sort((a, b) => b.id.compareTo(a.id));
            return Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  for (final f in const ['All', 'Pending', 'To issue', 'Done', 'Rejected'])
                    ChoiceChip(
                      label: Text('$f ${all.where((r) => _match(r, f)).length}'),
                      selected: filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  SizedBox(
                    width: 240,
                    child: TextField(
                      onChanged: (v) => setState(() => _q = v),
                      decoration: const InputDecoration(isDense: true, hintText: 'Search...', prefixIcon: Icon(Icons.search_rounded)),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                const RowHeader(['Reference', 'Department', 'Items', '', 'Date', 'Status']),
                if (list.isEmpty)
                  const Padding(padding: EdgeInsets.all(16), child: Text('No requisitions here yet.'))
                else
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListRow(
                      path: '/app/requisitions/${list[i].id}',
                      ref: list[i].number,
                      a: list[i].department,
                      b: '${list[i].summary} | ${list[i].officer}',
                      date: list[i].date,
                      chip: StatePill(list[i].status),
                    ),
                  ],
              ]),
            );
          },
        ),
      ],
    );
  }
}
