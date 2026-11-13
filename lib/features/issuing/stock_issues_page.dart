import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/state.dart';
import '../../core/theme/bv_theme.dart';
import '../../core/widgets.dart';
import 'issue_stock_dialog.dart';

/// Stock issuing.
///
/// Tabs: Requisitions (what can be issued now, with an Issue button for the
/// Stores Controller) and Issue notes (every stock issue, lazy loaded, with a
/// lookup by issue number). Stock can only be issued once the Headmaster and
/// the Operations Manager have approved the requisition.
const _pageSize = 25;

class StockIssuesPage extends ConsumerStatefulWidget {
  const StockIssuesPage({super.key});

  @override
  ConsumerState<StockIssuesPage> createState() => _StockIssuesPageState();
}

class _StockIssuesPageState extends ConsumerState<StockIssuesPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider);
    if (me == null) return const SizedBox();
    final canIssue = me.role == Role.stores;

    return PageBody(
      title: 'Stock issues',
      subtitle: canIssue
          ? 'Issue stock against approved requisitions and look up issue notes.'
          : 'Issue notes and requisitions waiting to be issued (view only).',
      actions: [
        IconButton(tooltip: 'Reload', onPressed: () => refreshAll(ref), icon: const Icon(Icons.refresh_rounded)),
      ],
      children: [
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(icon: Icon(Icons.outbox_rounded), text: 'Requisitions'),
                Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Issue notes'),
              ],
            ),
            const SizedBox(height: 16),
            if (_tabs.index == 0) _RequisitionsTab(canIssue: canIssue) else const _NotesTab(),
          ]),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: requisitions that can be (or will soon be) issued
// ---------------------------------------------------------------------------
const _readyStatuses = ['READY_FOR_ISSUE', 'PARTIALLY_ISSUED'];
const _waitingStatuses = ['PENDING_HEAD_APPROVAL', 'PENDING_OM_APPROVAL'];

enum _Show { ready, waiting, all }

class _RequisitionsTab extends ConsumerStatefulWidget {
  const _RequisitionsTab({required this.canIssue});
  final bool canIssue;

  @override
  ConsumerState<_RequisitionsTab> createState() => _RequisitionsTabState();
}

class _RequisitionsTabState extends ConsumerState<_RequisitionsTab> {
  _Show _show = _Show.ready;
  final _search = TextEditingController();
  int? _busyId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _issue(Requisition listed) async {
    final me = ref.read(sessionProvider);
    if (me == null || me.role != Role.stores) return;
    setState(() => _busyId = listed.id);
    try {
      // Load everything fresh so the quantities are right.
      final repo = ref.read(repoProvider);
      final r = await repo.requisition(listed.id);
      final issues = await repo.issuesForRequisition(listed.id);
      final balances = await ref.read(balancesP.future);
      if (!mounted) return;
      if (!_readyStatuses.contains(r.status)) {
        snack(context, 'This requisition is not approved for issue.');
        return;
      }
      final issued = <int, double>{};
      for (final i in issues) {
        for (final l in i.lines) {
          issued[l.requisitionLineId] = (issued[l.requisitionLineId] ?? 0) + l.qty;
        }
      }
      final res = await showIssueStockDialog(context, requisition: r, issuedByLine: issued, balances: balances);
      if (res == null || !mounted) return;
      await act(context, ref, () => repo.issueStock(r.id, me.name, res.receivedBy, res.remarks, res.lines),
          'Stock issued against ${r.number}.');
    } catch (e) {
      if (mounted) snack(context, '$e');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(requisitionsP);
    return data.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => _LoadError(message: '$e', onRetry: () => refreshAll(ref)),
      data: (all) {
        bool inScope(Requisition r) => switch (_show) {
              _Show.ready => _readyStatuses.contains(r.status),
              _Show.waiting => _waitingStatuses.contains(r.status),
              _Show.all => _readyStatuses.contains(r.status) || _waitingStatuses.contains(r.status),
            };
        final q = _search.text.trim().toLowerCase();
        final list = all
            .where(inScope)
            .where((r) =>
                q.isEmpty ||
                r.number.toLowerCase().contains(q) ||
                r.department.toLowerCase().contains(q) ||
                r.officer.toLowerCase().contains(q))
            .toList()
          ..sort((a, b) => b.id.compareTo(a.id));
        final ready = all.where((r) => _readyStatuses.contains(r.status)).length;
        final waiting = all.where((r) => _waitingStatuses.contains(r.status)).length;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            ChoiceChip(
              label: Text('Ready to issue ($ready)'),
              selected: _show == _Show.ready,
              onSelected: (_) => setState(() => _show = _Show.ready),
            ),
            ChoiceChip(
              label: Text('Awaiting approval ($waiting)'),
              selected: _show == _Show.waiting,
              onSelected: (_) => setState(() => _show = _Show.waiting),
            ),
            ChoiceChip(
              label: Text('Both (${ready + waiting})'),
              selected: _show == _Show.all,
              onSelected: (_) => setState(() => _show = _Show.all),
            ),
            SizedBox(
              width: 240,
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search reference, department, officer',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          if (list.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('No requisitions here.'))
          else
            for (final r in list) ...[
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => context.go('/app/requisitions/${r.id}'),
                leading: const CircleAvatar(radius: 18, child: Icon(Icons.description_rounded, size: 18)),
                title: Text(r.number),
                subtitle: Text('${r.department} | ${r.officer}${r.date == null ? '' : ' | ${dmy(r.date!)}'}'),
                trailing: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  StatePill(r.status),
                  if (widget.canIssue)
                    Tooltip(
                      message: _readyStatuses.contains(r.status)
                          ? 'Issue stock'
                          : 'Needs Headmaster and Operations Manager approval first',
                      child: FilledButton.icon(
                        // Only works once the requisition has been approved.
                        onPressed: (_readyStatuses.contains(r.status) && _busyId == null) ? () => _issue(r) : null,
                        icon: _busyId == r.id
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.outbox_rounded),
                        label: const Text('Issue'),
                      ),
                    ),
                ]),
              ),
            ],
        ]);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: issue notes (lazy list + lookup by number)
// ---------------------------------------------------------------------------
class _NotesTab extends ConsumerStatefulWidget {
  const _NotesTab();

  @override
  ConsumerState<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<_NotesTab> {
  final _search = TextEditingController();
  final _number = TextEditingController();
  String? _numberError;
  bool _finding = false;
  int _shown = _pageSize;
  bool _loadingMore = false;

  @override
  void dispose() {
    _search.dispose();
    _number.dispose();
    super.dispose();
  }

  void _loadMore() {
    if (_loadingMore) return;
    _loadingMore = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _shown += _pageSize;
        _loadingMore = false;
      });
    });
  }

  /// GET /stock-issues/number/{issueNumber}
  Future<void> _find() async {
    final n = _number.text.trim();
    if (n.isEmpty) {
      setState(() => _numberError = 'Enter an issue number');
      return;
    }
    setState(() {
      _finding = true;
      _numberError = null;
    });
    try {
      final issue = await ref.read(repoProvider).issueByNumber(n);
      if (!mounted) return;
      await _showIssue(context, issue);
    } catch (_) {
      if (mounted) setState(() => _numberError = 'No issue note with that number');
    } finally {
      if (mounted) setState(() => _finding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(issuesP);
    final listHeight = (MediaQuery.sizeOf(context).height * 0.55).clamp(320.0, 640.0);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.start, children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() => _shown = _pageSize),
            decoration: const InputDecoration(
              hintText: 'Search the list',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          width: 300,
          child: TextField(
            controller: _number,
            onSubmitted: (_) => _find(),
            decoration: InputDecoration(
              labelText: 'Find by issue number',
              hintText: 'BVC-ISS-2026-00001',
              isDense: true,
              errorText: _numberError,
              suffixIcon: IconButton(
                tooltip: 'Find',
                onPressed: _finding ? null : _find,
                icon: _finding
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search_rounded),
              ),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      data.when(
        loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => _LoadError(message: '$e', onRetry: () => refreshAll(ref)),
        data: (all) {
          final q = _search.text.trim().toLowerCase();
          final list = all.where((i) {
            if (q.isEmpty) return true;
            return i.number.toLowerCase().contains(q) ||
                i.requisitionNumber.toLowerCase().contains(q) ||
                i.issuedBy.toLowerCase().contains(q) ||
                i.receivedBy.toLowerCase().contains(q) ||
                i.lines.any((l) => l.item.name.toLowerCase().contains(q));
          }).toList()
            ..sort((a, b) => (b.date ?? DateTime(1970)).compareTo(a.date ?? DateTime(1970)));

          if (list.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(all.isEmpty ? 'No stock has been issued yet.' : 'No issue notes match your search.'),
            );
          }
          final shown = math.min(_shown, list.length);
          final hasMore = shown < list.length;

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Showing $shown of ${list.length} issue notes', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            SizedBox(
              height: listHeight,
              // ListView.builder only builds the rows that are on screen.
              child: ListView.builder(
                itemCount: shown + (hasMore ? 1 : 0),
                itemBuilder: (ctx, index) {
                  if (index >= shown) {
                    _loadMore();
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
                    );
                  }
                  final i = list[index];
                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => _openById(ctx, i.id),
                      leading: const CircleAvatar(radius: 18, child: Icon(Icons.receipt_long_rounded, size: 18)),
                      title: Text(i.number),
                      subtitle: Text(
                        '${i.requisitionNumber.isEmpty ? 'Requisition ${i.requisitionId}' : i.requisitionNumber}'
                        ' | issued by ${i.issuedBy}, received by ${i.receivedBy}\n'
                        '${i.date == null ? '' : stamp(i.date!)}',
                      ),
                      isThreeLine: true,
                      trailing: StatusChip('${i.lines.length} item${i.lines.length == 1 ? '' : 's'}', StatusKind.neutral),
                    ),
                  ]);
                },
              ),
            ),
          ]);
        },
      ),
    ]);
  }

  /// Loads the issue note by id (GET /stock-issues/{id}) and shows it.
  Future<void> _openById(BuildContext context, int id) async {
    final StockIssue issue;
    try {
      issue = await ref.read(repoProvider).issue(id);
    } catch (e) {
      if (context.mounted) snack(context, '$e');
      return;
    }
    if (!context.mounted) return;
    await _showIssue(context, issue);
  }

  Future<void> _showIssue(BuildContext context, StockIssue i) {
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        return AlertDialog(
          title: const Text('Issue note'),
          content: BVSurface(
            child: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.number, style: t.titleLarge),
                  const SizedBox(height: 4),
                  Text('Requisition: ${i.requisitionNumber.isEmpty ? i.requisitionId : i.requisitionNumber}'),
                  Text('Issued by: ${i.issuedBy}'),
                  Text('Received by: ${i.receivedBy}'),
                  if (i.date != null) Text('Date: ${stamp(i.date!)}'),
                  if (i.remarks.isNotEmpty) Text('Remarks: ${i.remarks}'),
                  const Divider(height: 24),
                  for (final l in i.lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${qty(l.qty)} ${l.uom}  ${l.item.name} (${l.item.code})\n'
                        'From ${l.location}${l.remarks.isEmpty ? '' : ' | ${l.remarks}'}',
                      ),
                    ),
                ]),
              ),
            ),
          ),
          actions: [
            if (i.requisitionId > 0)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/app/requisitions/${i.requisitionId}');
                },
                child: const Text('Open requisition'),
              ),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        );
      },
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
      ]);
}
