import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';

/// Minimum share of the purchase value a partial batch must reach
/// (Head Office can override with a reason). Spec default: 50%.
const kMinPartialPct = 50;
const kDemoPassword = 'Bella@2026';

final storeProvider = ChangeNotifierProvider<Store>((ref) => Store());

T? _find<T>(Iterable<T> items, bool Function(T) test) {
  for (final e in items) {
    if (test(e)) return e;
  }
  return null;
}

/// In-memory demo "backend". Every rule from the spec (approval chain,
/// mandatory rejection comment, partial batches, three signatures, reorder
/// and buffer levels) lives here so the UI stays thin. Replace the methods
/// with REST calls when the real API exists.
class Store extends ChangeNotifier {
  Store() {
    _seed();
  }

  AppUser? currentUser;
  int failedLogins = 0;
  DateTime? lockedUntil;

  final List<AppUser> users = [];
  final List<StockItem> stock = [];
  final List<Requisition> reqs = [];
  final List<StockMove> moves = [];
  final List<Voucher> vouchers = [];
  final List<DeliveryNote> notes = [];

  int _reqSeq = 0, _pvSeq = 0, _dnSeq = 0, _autoSeq = 0, _userSeq = 0;

  // -------------------------------------------------------------------------
  // Lookups
  // -------------------------------------------------------------------------
  StockItem? stockById(String? id) =>
      id == null ? null : _find(stock, (s) => s.id == id);
  Requisition? reqByRef(String ref) => _find(reqs, (r) => r.ref == ref);
  DeliveryNote? noteByNo(String no) => _find(notes, (n) => n.no == no);
  Voucher? voucherByNo(String no) => _find(vouchers, (v) => v.no == no);

  String _nextReq() => 'REQ-2026-${(++_reqSeq).toString().padLeft(4, '0')}';

  // -------------------------------------------------------------------------
  // Auth
  // -------------------------------------------------------------------------
  String? login(String id, String pw) {
    final now = DateTime.now();
    if (lockedUntil != null && now.isBefore(lockedUntil!)) {
      final m = lockedUntil!.difference(now).inMinutes + 1;
      return 'Too many failed attempts. Try again in $m min.';
    }
    final key = id.trim().toLowerCase();
    final u = _find(
        users,
        (u) =>
            u.email.toLowerCase() == key ||
            u.username.toLowerCase() == key ||
            (u.employeeNumber.isNotEmpty && u.employeeNumber.toLowerCase() == key));
    if (u == null || u.password != pw) {
      failedLogins++;
      if (failedLogins >= 5) {
        lockedUntil = now.add(const Duration(minutes: 15));
        failedLogins = 0;
        return 'Too many failed attempts. Locked for 15 minutes.';
      }
      return 'Incorrect email / username or password.';
    }
    if (u.accountLocked) {
      return 'Your account is locked. Please contact the System Administrator.';
    }
    if (!u.active) {
      return 'Your account is pending activation by the System Administrator.';
    }
    failedLogins = 0;
    u.lastLogin = DateTime.now();
    currentUser = u;
    notifyListeners();
    return null;
  }

  void logout() {
    currentUser = null;
    notifyListeners();
  }

  /// Self-registration. The account starts inactive with the Requester role and
  /// no department; the System Administrator assigns those and activates it.
  String? register({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required String password,
  }) {
    final mail = email.trim().toLowerCase();
    if (users.any((u) => u.email.toLowerCase() == mail)) {
      return 'An account with that email already exists.';
    }
    // Username is derived from the email address (made unique if needed).
    final base = mail.split('@').first;
    var username = base;
    var n = 1;
    while (users.any((u) => u.username.toLowerCase() == username)) {
      username = '$base${++n}';
    }
    users.add(AppUser(
      id: 'u_new${++_userSeq}',
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      username: username,
      email: email.trim(),
      phoneNumber: phoneNumber.trim(),
      password: password,
      role: Role.requester,
      active: false,
    ));
    notifyListeners();
    return null;
  }

  // -------------------------------------------------------------------------
  // User administration (System Administrator)
  // -------------------------------------------------------------------------
  /// Saves the role, department and active flag for a user in one go.
  /// Returns an error message, or null on success.
  String? updateUserAccess(
    AppUser u, {
    required Role role,
    required String department,
    required bool active,
  }) {
    final me = currentUser;
    if (me == null || me.role != Role.admin) {
      return 'Only the System Administrator can manage users.';
    }
    if (u.id == me.id && (role != u.role || !active)) {
      return 'You cannot change your own role or deactivate your own account.';
    }
    if (active && department.isEmpty) {
      return 'Select a department before activating this account.';
    }
    u.role = role;
    u.department = department;
    u.active = active;
    if (active) u.accountLocked = false;
    u.updatedAt = DateTime.now();
    notifyListeners();
    return null;
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------
  void _log(Requisition r, String text,
      {HistKind kind = HistKind.note, AppUser? by}) {
    final u = by ?? currentUser;
    r.history.add(HistoryEntry(
        u?.name ?? 'System', u?.role.label ?? 'System', text, DateTime.now(),
        kind: kind));
  }

  void _suggestIssue(Requisition r) {
    if (r.isAuto) return;
    for (final l in r.lines) {
      final s = stockById(l.stockId);
      l.fromStock = s == null ? 0 : math.min(l.qty, s.onHand);
    }
  }

  void _move(StockItem s, String type, int qty, String ref) {
    moves.insert(
        0,
        StockMove(s.name, type, qty, s.onHand, ref,
            currentUser?.name ?? 'System', DateTime.now()));
  }

  Role? levelRole(ReqStatus st) => switch (st) {
        ReqStatus.storesReview => Role.stores,
        ReqStatus.pendingHead => Role.head,
        ReqStatus.pendingOm => Role.om,
        ReqStatus.pendingHo => Role.ho,
        _ => null,
      };

  /// Guard: a role may act only at its own level, never on its own requisition.
  bool canAct(Requisition r, AppUser u) =>
      levelRole(r.status) == u.role && r.requesterId != u.id;

  // -------------------------------------------------------------------------
  // Requisitions: create / submit / resubmit / cancel
  // -------------------------------------------------------------------------
  Requisition createReq({
    required String dept,
    required String priority,
    required DateTime requiredBy,
    required String costCentre,
    required String justification,
    required List<ReqLine> lines,
    required bool submit,
  }) {
    final u = currentUser!;
    final r = Requisition(
      ref: _nextReq(),
      dept: dept,
      requester: u.name,
      requesterId: u.id,
      created: DateTime.now(),
      requiredBy: requiredBy,
      priority: priority,
      costCentre: costCentre,
      source: 'Manual',
      justification: justification,
      status: submit ? ReqStatus.storesReview : ReqStatus.draft,
      lines: lines,
    );
    _suggestIssue(r);
    _log(r, justification);
    _log(r, submit ? 'Submitted to Stores Controller.' : 'Draft saved.',
        kind: HistKind.system);
    reqs.insert(0, r);
    notifyListeners();
    return r;
  }

  void submitDraft(Requisition r) {
    r.status = ReqStatus.storesReview;
    _suggestIssue(r);
    _log(r, 'Submitted to Stores Controller.', kind: HistKind.system);
    notifyListeners();
  }

  void resubmit(Requisition r,
      {required List<ReqLine> lines, required String justification}) {
    r.lines = lines;
    r.justification = justification;
    r.version++;
    r.rejection = null;
    r.rejectedBy = null;
    r.status = ReqStatus.storesReview;
    _suggestIssue(r);
    _log(r, 'Resubmitted as v${r.version}. Approvals restart at Stores review.',
        kind: HistKind.system);
    notifyListeners();
  }

  bool canCancel(Requisition r, AppUser u) =>
      r.requesterId == u.id &&
      (r.status == ReqStatus.draft ||
          r.status == ReqStatus.storesReview ||
          r.status == ReqStatus.pendingHead);

  void cancel(Requisition r) {
    r.status = ReqStatus.cancelled;
    _log(r, 'Cancelled by requester before first approval.', kind: HistKind.system);
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Stores review, approvals, rejection
  // -------------------------------------------------------------------------
  void setIssue(Requisition r, int lineIndex, int qty) {
    final l = r.lines[lineIndex];
    final s = stockById(l.stockId);
    final cap = r.isAuto || s == null ? 0 : math.min(l.qty, s.onHand);
    l.fromStock = qty.clamp(0, cap).toInt();
    notifyListeners();
  }

  String? storesForward(Requisition r, String note) {
    final u = currentUser!;
    if (!canAct(r, u) || u.role != Role.stores) return 'Not allowed.';
    if (note.trim().isNotEmpty) r.storesNote = note.trim();
    _log(r,
        'Stock checked.${note.trim().isEmpty ? '' : ' Note: ${note.trim()}.'} Forwarded to School Head.',
        kind: HistKind.approve);
    r.status = ReqStatus.pendingHead;
    notifyListeners();
    return null;
  }

  String? approve(Requisition r, {String comment = ''}) {
    final u = currentUser!;
    if (!canAct(r, u)) return 'You cannot approve this requisition.';
    final extra = comment.trim().isEmpty ? '' : ' "${comment.trim()}"';
    switch (r.status) {
      case ReqStatus.pendingHead:
        _log(r, 'Approved by School Head.$extra', kind: HistKind.approve);
        r.status = ReqStatus.pendingOm;
      case ReqStatus.pendingOm:
        _log(r, 'Approved by Operations Manager.$extra', kind: HistKind.approve);
        r.status = ReqStatus.pendingHo;
      case ReqStatus.pendingHo:
        _log(r, 'Final approval by Head Office Admin.$extra', kind: HistKind.approve);
        _finalApprove(r);
      default:
        return 'Nothing to approve.';
    }
    notifyListeners();
    return null;
  }

  void _finalApprove(Requisition r) {
    for (final l in r.lines) {
      final s = stockById(l.stockId);
      if (s == null) continue;
      if (l.fromStock > 0) {
        s.onHand -= l.fromStock;
        _move(s, 'out', l.fromStock, 'Issue ${r.ref}');
      }
      if (l.toBuy > 0) s.onOrder += l.toBuy;
    }
    if (r.lines.every((l) => l.toBuy <= 0)) {
      r.status = ReqStatus.completed;
      _log(r, 'Fully issued from stock. No purchase needed.', kind: HistKind.system);
    } else {
      r.status = ReqStatus.approved;
    }
    runReorderCheck();
  }

  /// Mandatory comment: at least 10 characters, saved with name, role, time.
  String? reject(Requisition r, String comment) {
    final u = currentUser!;
    if (!canAct(r, u)) return 'You cannot reject this requisition.';
    if (comment.trim().length < 10) return 'A comment of at least 10 characters is required.';
    r.rejection = comment.trim();
    r.rejectedBy = u.role.label;
    r.status = ReqStatus.rejected;
    _log(r, 'Rejected by ${u.role.label}: "${comment.trim()}"', kind: HistKind.reject);
    notifyListeners();
    return null;
  }

  // -------------------------------------------------------------------------
  // Head Office: batches, vouchers, funds, cancel balance
  // -------------------------------------------------------------------------
  static const _batchStatuses = [
    ReqStatus.approved,
    ReqStatus.voucher,
    ReqStatus.delivery,
    ReqStatus.partial,
  ];

  bool canRelease(Requisition r, AppUser u) =>
      u.role == Role.ho && _batchStatuses.contains(r.status) && r.hasBatchable;

  String? releaseBatch(
    Requisition r,
    Map<int, int> qty, {
    required String supplier,
    required String method,
    String? reason,
  }) {
    final u = currentUser!;
    if (!canRelease(r, u)) return 'Only Head Office Admin can release a batch.';
    final sel = Map<int, int>.from(qty)..removeWhere((k, v) => v <= 0);
    if (sel.isEmpty) return 'Select at least one line.';
    if (supplier.trim().isEmpty) return 'Enter the supplier.';
    for (final e in sel.entries) {
      if (e.value > r.lines[e.key].batchable) {
        return 'Quantity for ${r.lines[e.key].name} exceeds the approved balance.';
      }
    }
    var value = 0.0;
    sel.forEach((i, q) => value += q * r.lines[i].unitPrice);
    final isFull = [
      for (var i = 0; i < r.lines.length; i++)
        r.lines[i].batchable - (sel[i] ?? 0) <= 0,
    ].every((x) => x);
    final pct = r.buyTotal == 0 ? 100.0 : value / r.buyTotal * 100;
    if (!isFull && pct < kMinPartialPct && (reason == null || reason.trim().isEmpty)) {
      return 'This batch is ${pct.round()}% of the purchase value. '
          'Enter a reason to release below $kMinPartialPct%.';
    }
    final batchRef = '${r.ref}/B${r.batches.length + 1}';
    final pv = 'PV-2026-${(++_pvSeq).toString().padLeft(4, '0')}';
    final v = Voucher(
      no: pv,
      reqRef: r.ref,
      batchRef: batchRef,
      supplier: supplier.trim(),
      method: method,
      date: DateTime.now(),
      raisedBy: u.name,
      lines: [
        for (final e in sel.entries)
          VLine(r.lines[e.key].name, e.value, r.lines[e.key].unitPrice),
      ],
    );
    vouchers.insert(0, v);
    sel.forEach((i, q) => r.lines[i].batched += q);
    r.batches.add(Batch(
      ref: batchRef,
      qty: sel,
      value: value,
      pct: pct,
      voucherNo: pv,
      reason: reason?.trim().isEmpty ?? true ? null : reason!.trim(),
    ));
    if (r.status == ReqStatus.approved) r.status = ReqStatus.voucher;
    _log(r,
        'Batch $batchRef released: voucher $pv for \$${value.toStringAsFixed(2)} (${pct.round()}%).'
        '${reason == null || reason.trim().isEmpty ? '' : ' Reason: ${reason.trim()}'}',
        kind: HistKind.approve);
    notifyListeners();
    return null;
  }

  String? releaseFunds(Voucher v) {
    final u = currentUser!;
    if (u.role != Role.ho) return 'Only Head Office Admin can release funds.';
    if (v.released) return 'Funds already released.';
    final r = reqByRef(v.reqRef)!;
    v.released = true;
    final driver = _find(users, (x) => x.role == Role.driver && x.active);
    final no = 'DN-2026-${(++_dnSeq).toString().padLeft(4, '0')}';
    final batch = _find(r.batches, (b) => b.ref == v.batchRef)!;
    batch.deliveryNo = no;
    notes.insert(
      0,
      DeliveryNote(
        no: no,
        voucherNo: v.no,
        reqRef: r.ref,
        batchRef: v.batchRef,
        supplier: v.supplier,
        driver: driver?.name ?? 'Unassigned',
        vehicle: 'AFD 4821 (Isuzu)',
        date: DateTime.now(),
        lines: [
          for (final e in batch.qty.entries)
            DLine(e.key, r.lines[e.key].name, e.value),
        ],
      ),
    );
    if (r.status == ReqStatus.voucher || r.status == ReqStatus.approved) {
      r.status = ReqStatus.delivery;
    }
    _log(r, 'Funds released for ${v.no}. Delivery note $no assigned to ${driver?.name ?? 'a driver'}.',
        kind: HistKind.system);
    notifyListeners();
    return null;
  }

  String? cancelBalance(Requisition r, String comment) {
    final u = currentUser!;
    if (u.role != Role.ho) return 'Only Head Office Admin can cancel a balance.';
    if (comment.trim().length < 10) return 'A comment of at least 10 characters is required.';
    var n = 0;
    for (final l in r.lines) {
      final c = l.batchable;
      if (c > 0) {
        l.cancelled += c;
        n += c;
        final s = stockById(l.stockId);
        if (s != null) s.onOrder = math.max(0, s.onOrder - c);
      }
    }
    _log(r, 'Balance cancelled ($n units): "${comment.trim()}"', kind: HistKind.reject);
    if (r.lines.every((l) => l.balance <= 0)) r.status = ReqStatus.completed;
    notifyListeners();
    return null;
  }

  // -------------------------------------------------------------------------
  // Delivery: three signatures, then add to stock
  // -------------------------------------------------------------------------
  String? signDelivery(DeliveryNote n, SignStage stage, List<List<Offset>> strokes) {
    final u = currentUser!;
    if (u.role != stage.role) return 'Only the ${stage.role.label} can sign here.';
    if (n.nextStage != stage) {
      return 'Signatures must follow the order: Driver, Security, Stores Controller.';
    }
    if (strokes.isEmpty) return 'Please sign in the box first.';
    n.sigs[stage] = Signature(u.name, u.role.label, DateTime.now(), strokes);
    final r = reqByRef(n.reqRef);
    if (r != null) _log(r, '${n.no}: ${stage.title} signed by ${u.name}.', kind: HistKind.system);
    notifyListeners();
    return null;
  }

  String? flagDelivery(DeliveryNote n, String note) {
    if (note.trim().length < 10) return 'A note of at least 10 characters is required.';
    n.flagNote = note.trim();
    final r = reqByRef(n.reqRef);
    if (r != null) _log(r, '${n.no} flagged: "${note.trim()}"', kind: HistKind.reject);
    notifyListeners();
    return null;
  }

  String? addToStock(DeliveryNote n, Map<int, int> accepted, String note) {
    final u = currentUser!;
    if (u.role != Role.stores) return 'Only the Stores Controller can add stock.';
    if (!n.fullySigned) return 'All three signatures are needed first.';
    if (n.stockAdded) return 'Stock already added.';
    final r = reqByRef(n.reqRef)!;
    var short = 0;
    for (var i = 0; i < n.lines.length; i++) {
      final d = n.lines[i];
      short += d.ordered - (accepted[i] ?? d.ordered).clamp(0, d.ordered).toInt();
    }
    if (short > 0 && note.trim().length < 10) {
      return 'A shortage needs a note of at least 10 characters.';
    }
    for (var i = 0; i < n.lines.length; i++) {
      final d = n.lines[i];
      final acc = (accepted[i] ?? d.ordered).clamp(0, d.ordered).toInt();
      d.accepted = acc;
      final l = r.lines[d.lineIndex];
      l.received += acc;
      l.batched -= (d.ordered - acc); // shortage becomes a balance again
      final s = stockById(l.stockId);
      if (s != null) {
        s.onHand += acc;
        s.onOrder = math.max(0, s.onOrder - acc);
        _move(s, 'in', acc, 'GRN ${n.no}');
      }
    }
    n.stockAdded = true;
    n.receiveNote = note.trim().isEmpty ? null : note.trim();
    r.status = r.lines.every((l) => l.balance <= 0) ? ReqStatus.completed : ReqStatus.partial;
    _log(
        r,
        '${n.no} received and added to stock.'
        '${short > 0 ? ' Shortage of $short unit(s) returned to the balance.' : ''}'
        '${n.receiveNote == null ? '' : ' Note: ${n.receiveNote}'}',
        kind: HistKind.system);
    runReorderCheck();
    notifyListeners();
    return null;
  }

  // -------------------------------------------------------------------------
  // Stock levels & automatic reorder
  // -------------------------------------------------------------------------
  String? setLevels(StockItem s, {required int reorder, required int buffer, required int max}) {
    if (!(max > reorder && reorder > buffer && buffer > 0)) {
      return 'Levels must satisfy: Max > Reorder > Buffer > 0.';
    }
    s.reorder = reorder;
    s.buffer = buffer;
    s.max = max;
    notifyListeners();
    return null;
  }

  Requisition? get openAutoReq => _find(
      reqs, (r) => r.isAuto && r.status.isOpen && r.status != ReqStatus.draft);

  /// When on hand + on order <= reorder level, draft an AUTO requisition.
  /// Items already covered by an open AUTO requisition are skipped.
  int runReorderCheck() {
    final covered = <String>{
      for (final r in reqs.where((r) => r.isAuto && r.status.isOpen))
        for (final l in r.lines)
          if (l.stockId != null) l.stockId!,
    };
    final low = stock
        .where((s) => s.onHand + s.onOrder <= s.reorder && !covered.contains(s.id))
        .toList();
    if (low.isEmpty) return 0;
    final urgent = low.any((s) => s.onHand <= s.buffer);
    final r = Requisition(
      ref: 'AUTO-2026-${(++_autoSeq).toString().padLeft(4, '0')}',
      dept: 'Stores',
      requester: 'System (AUTO)',
      requesterId: 'system',
      created: DateTime.now(),
      requiredBy: DateTime.now().add(const Duration(days: 7)),
      priority: urgent ? 'Urgent' : 'Normal',
      costCentre: 'STORES',
      source: 'AUTO',
      justification:
          'Automatic replenishment: ${low.length} item(s) at or below reorder level.',
      status: ReqStatus.storesReview,
      lines: [
        for (final s in low)
          ReqLine(
            stockId: s.id,
            name: s.name,
            unit: s.unit,
            qty: math.max(1, s.max - (s.onHand + s.onOrder)),
            unitPrice: s.price,
          ),
      ],
    );
    r.history.add(HistoryEntry('System', 'System', r.justification, DateTime.now(),
        kind: HistKind.system));
    reqs.insert(0, r);
    notifyListeners();
    return low.length;
  }

  // -------------------------------------------------------------------------
  // Queries for dashboards and lists
  // -------------------------------------------------------------------------
  List<Requisition> visibleReqs(AppUser u) {
    final list = u.role == Role.requester
        ? reqs.where((r) => r.requesterId == u.id).toList()
        : List<Requisition>.of(reqs);
    list.sort((a, b) => b.created.compareTo(a.created));
    return list;
  }

  /// Requisitions that need this user to act now, oldest first.
  List<Requisition> queueFor(AppUser u) {
    bool needs(Requisition r) => switch (u.role) {
          Role.stores => r.status == ReqStatus.storesReview,
          Role.head => r.status == ReqStatus.pendingHead,
          Role.om => r.status == ReqStatus.pendingOm,
          Role.ho => r.status == ReqStatus.pendingHo || canRelease(r, u),
          Role.requester => r.requesterId == u.id &&
              (r.status == ReqStatus.rejected || r.status == ReqStatus.draft),
          _ => false,
        };
    final list = reqs.where(needs).where((r) => r.requesterId != u.id || u.role == Role.requester).toList();
    list.sort((a, b) => a.created.compareTo(b.created));
    return list;
  }

  /// Delivery notes relevant to this user.
  List<DeliveryNote> deliveriesFor(AppUser u) => notes.where((n) {
        return switch (u.role) {
          Role.driver => n.nextStage == SignStage.driver,
          Role.security => n.nextStage == SignStage.security,
          Role.stores => !n.stockAdded,
          Role.ho || Role.om => !n.stockAdded,
          _ => false,
        };
      }).toList();

  int get lowStockCount => stock.where((s) => s.level != StockLevel.healthy).length;

  int approvedBy(Role role) => reqs
      .where((r) => r.history.any((h) => h.kind == HistKind.approve && h.role == role.label))
      .length;

  // -------------------------------------------------------------------------
  // Demo data
  // -------------------------------------------------------------------------
  void resetDemo() {
    final id = currentUser?.id;
    _seed();
    currentUser = id == null ? null : _find(users, (u) => u.id == id);
    notifyListeners();
  }

  void _seed() {
    users
      ..clear()
      ..addAll([
        AppUser(id: 'u_req', firstName: 'Tendai', lastName: 'Moyo', username: 'requester', employeeNumber: 'BV-0231', email: 'requester@bellavista.ac.zw', department: 'Science', role: Role.requester, password: kDemoPassword),
        AppUser(id: 'u_stores', firstName: 'Rudo', lastName: 'Mandaza', username: 'stores', employeeNumber: 'BV-0102', email: 'stores@bellavista.ac.zw', department: 'Stores', role: Role.stores, password: kDemoPassword),
        AppUser(id: 'u_head', firstName: 'Chipo', lastName: 'Nyathi', username: 'head', employeeNumber: 'BV-0010', email: 'head@bellavista.ac.zw', department: 'Administration', role: Role.head, password: kDemoPassword),
        AppUser(id: 'u_om', firstName: 'Tafara', lastName: 'Chuma', username: 'om', employeeNumber: 'BV-0021', email: 'om@bellavista.ac.zw', department: 'Operations', role: Role.om, password: kDemoPassword),
        AppUser(id: 'u_ho', firstName: 'Nyasha', lastName: 'Dube', username: 'ho', employeeNumber: 'BV-0003', email: 'ho@bellavista.ac.zw', department: 'Head Office', role: Role.ho, password: kDemoPassword),
        AppUser(id: 'u_driver', firstName: 'Farai', lastName: 'Ndlovu', username: 'driver', employeeNumber: 'BV-0305', email: 'driver@bellavista.ac.zw', department: 'Transport', role: Role.driver, password: kDemoPassword),
        AppUser(id: 'u_sec', firstName: 'S.', lastName: 'Mhlanga', username: 'security', employeeNumber: 'BV-0410', email: 'security@bellavista.ac.zw', department: 'Security', role: Role.security, password: kDemoPassword),
        AppUser(id: 'u_admin', firstName: 'Admin', lastName: 'User', username: 'admin', employeeNumber: 'BV-0001', email: 'admin@bellavista.ac.zw', department: 'ICT', role: Role.admin, password: kDemoPassword),
        AppUser(id: 'u_pending', firstName: 'Kudzai', lastName: 'Banda', username: 'kbanda', employeeNumber: 'BV-0450', email: 'kbanda@bellavista.ac.zw', phoneNumber: '+263 77 123 4567', role: Role.requester, password: kDemoPassword, active: false),
      ]);

    StockItem si(String id, String name, String unit, int hand, int reorder, int buffer, int max, double price) =>
        StockItem(id: id, name: name, unit: unit, onHand: hand, reorder: reorder, buffer: buffer, max: max, price: price);
    stock
      ..clear()
      ..addAll([
        si('a4', 'A4 paper', 'ream', 14, 20, 8, 60, 4.50),
        si('pens', 'Marker pens', 'box', 2, 12, 5, 40, 4.50),
        si('chalk', 'Chalk', 'box', 9, 12, 6, 36, 2.00),
        si('tp', 'Toilet paper', 'pack', 0, 15, 8, 60, 3.50),
        si('toner', 'Printer toner', 'each', 9, 4, 2, 12, 80.00),
        si('beakers', 'Beakers 250 ml', 'each', 35, 15, 8, 60, 4.50),
        si('clean', 'Cleaning liquid', 'litre', 40, 20, 10, 80, 2.50),
        si('goggles', 'Safety goggles', 'each', 0, 10, 4, 60, 7.00),
        si('coats', 'Lab coats (L)', 'each', 0, 5, 2, 20, 39.40),
        si('netballs', 'Netballs', 'each', 12, 6, 3, 20, 15.00),
        si('cones', 'Training cones', 'set', 6, 4, 2, 12, 8.00),
        si('covers', 'Book covers', 'roll', 20, 10, 5, 40, 3.80),
        si('labels', 'Labels', 'pack', 25, 10, 5, 50, 1.50),
      ]);

    reqs.clear();
    moves.clear();
    vouchers.clear();
    notes.clear();
    _reqSeq = 148;
    _pvSeq = 86;
    _dnSeq = 86;
    _autoSeq = 11;

    ReqLine ln(String id, int qty) {
      final s = stockById(id)!;
      return ReqLine(stockId: s.id, name: s.name, unit: s.unit, qty: qty, unitPrice: s.price);
    }

    HistoryEntry h(String who, String role, String text, DateTime at, [HistKind k = HistKind.note]) =>
        HistoryEntry(who, role, text, at, kind: k);

    Requisition mk(String ref, String dept, String by, String byId, DateTime d,
        String just, ReqStatus st, List<ReqLine> lines,
        {String prio = 'Normal'}) {
      final r = Requisition(
        ref: ref,
        dept: dept,
        requester: by,
        requesterId: byId,
        created: d,
        requiredBy: d.add(const Duration(days: 9)),
        priority: prio,
        costCentre: '${dept.substring(0, 3).toUpperCase()}-GEN',
        source: 'Manual',
        justification: just,
        status: st,
        lines: lines,
      );
      _suggestIssue(r);
      r.history.add(h(by, 'Requester', just, d));
      reqs.add(r);
      return r;
    }

    const stores = 'Stores Controller';
    mk('REQ-2026-0142', 'Science', 'Tendai Moyo', 'u_req', DateTime(2026, 11, 3),
        'Needed for Form 3 practicals starting 12 Nov.', ReqStatus.storesReview,
        [ln('beakers', 20), ln('pens', 10), ln('goggles', 30), ln('coats', 6)]);
    mk('REQ-2026-0143', 'Sports', 'K. Sibanda', 'ext', DateTime(2026, 11, 4),
        'Netballs and cones for the inter-house season.', ReqStatus.storesReview,
        [ln('netballs', 14), ln('cones', 6)]);
    mk('REQ-2026-0144', 'Admin', 'R. Ncube', 'ext', DateTime(2026, 11, 4),
        'Printer toner for the admin block.', ReqStatus.storesReview, [ln('toner', 4)]);
    mk('REQ-2026-0145', 'Boarding', 'M. Dube', 'ext', DateTime(2026, 11, 5),
        'Cleaning supplies for the boarding houses.', ReqStatus.storesReview,
        [ln('clean', 30), ln('tp', 40)]);

    final r146 = mk('REQ-2026-0146', 'Kitchen', 'P. Chuma', 'ext', DateTime(2026, 11, 3),
        'Kitchen cleaning stock for term end.', ReqStatus.pendingHead,
        [ln('clean', 20), ln('tp', 60)]);
    r146.history.add(h('Rudo Mandaza', stores, 'Stock checked. Forwarded to School Head.', DateTime(2026, 11, 4), HistKind.approve));
    final r148 = mk('REQ-2026-0148', 'Sports', 'K. Sibanda', 'ext', DateTime(2026, 11, 4),
        'Replacement balls and cones.', ReqStatus.pendingHead, [ln('netballs', 10), ln('cones', 8)]);
    r148.history.add(h('Rudo Mandaza', stores, 'Stock checked. Forwarded to School Head.', DateTime(2026, 11, 5), HistKind.approve));

    final r140 = mk('REQ-2026-0140', 'Sports', 'K. Sibanda', 'ext', DateTime(2026, 11, 2),
        'Exam paper supply for sports department tests.', ReqStatus.pendingOm, [ln('a4', 30)]);
    r140.history.addAll([
      h('Rudo Mandaza', stores, 'Stock checked. Forwarded to School Head.', DateTime(2026, 11, 3), HistKind.approve),
      h('Chipo Nyathi', 'School Head', 'Approved by School Head.', DateTime(2026, 11, 4), HistKind.approve),
    ]);

    final r138 = mk('REQ-2026-0138', 'Kitchen', 'P. Chuma', 'ext', DateTime(2026, 10, 30),
        'Hygiene supplies for the dining hall.', ReqStatus.pendingHo,
        [ln('clean', 30), ln('tp', 40)]);
    r138.history.addAll([
      h('Rudo Mandaza', stores, 'Stock checked. Forwarded to School Head.', DateTime(2026, 10, 31), HistKind.approve),
      h('Chipo Nyathi', 'School Head', 'Approved by School Head.', DateTime(2026, 11, 1), HistKind.approve),
      h('Tafara Chuma', 'Operations Manager', 'Approved by Operations Manager.', DateTime(2026, 11, 2), HistKind.approve),
    ]);

    final r137 = mk('REQ-2026-0137', 'Admin', 'R. Ncube', 'ext', DateTime(2026, 10, 29),
        'Photocopy paper for term exams.', ReqStatus.storesReview, [ln('a4', 40)]);
    for (final l in r137.lines) {
      l.fromStock = 0;
    }
    r137.history.addAll([
      h('Rudo Mandaza', stores, 'Stock checked. Forwarded to School Head.', DateTime(2026, 10, 30), HistKind.approve),
      h('Chipo Nyathi', 'School Head', 'Approved by School Head.', DateTime(2026, 10, 31), HistKind.approve),
      h('Tafara Chuma', 'Operations Manager', 'Approved by Operations Manager.', DateTime(2026, 11, 1), HistKind.approve),
      h('Nyasha Dube', 'Head Office Admin', 'Final approval by Head Office Admin.', DateTime(2026, 11, 2), HistKind.approve),
    ]);
    _finalApprove(r137);

    final r141 = mk('REQ-2026-0141', 'Library', 'L. Zhou', 'ext', DateTime(2026, 11, 2),
        'Book covers and labels for the new intake.', ReqStatus.rejected,
        [ln('covers', 10), ln('labels', 20)]);
    r141.rejection = 'Budget not available this term. Please resubmit next month.';
    r141.rejectedBy = 'School Head';
    r141.history.add(h('Chipo Nyathi', 'School Head',
        'Rejected by School Head: "${r141.rejection}"', DateTime(2026, 11, 3), HistKind.reject));

    final r130 = mk('REQ-2026-0130', 'Boarding', 'M. Dube', 'ext', DateTime(2026, 10, 22),
        'Cleaning liquid for the boarding houses.', ReqStatus.completed, [ln('clean', 20)]);
    for (final l in r130.lines) {
      l.fromStock = 0;
      l.received = l.toBuy;
    }
    r130.history.add(h('Rudo Mandaza', stores, 'Goods received and added to stock.', DateTime(2026, 10, 28), HistKind.system));

    currentUser = null;
    runReorderCheck(); // creates the first AUTO requisition (AUTO-2026-0012)
    currentUser = null;
  }
}
