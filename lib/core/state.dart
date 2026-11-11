import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

// ---------------------------------------------------------------------------
// Device settings: server address and who is using the app
// ---------------------------------------------------------------------------
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('prefs not loaded'));

class ApiBaseNotifier extends Notifier<String> {
  @override
  String build() => ref.read(prefsProvider).getString('api_base') ?? kDefaultApiBase;
  void set(String v) {
    state = v.trim();
    ref.read(prefsProvider).setString('api_base', state);
  }
}

final apiBaseProvider = NotifierProvider<ApiBaseNotifier, String>(ApiBaseNotifier.new);
final apiProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(apiBaseProvider)));

class Session {
  const Session(this.name, this.role);
  final String name;
  final Role role;
}

class SessionNotifier extends Notifier<Session?> {
  @override
  Session? build() {
    final p = ref.read(prefsProvider);
    final n = p.getString('user_name');
    final r = p.getString('user_role');
    if (n == null || r == null) return null;
    final role = Role.values.where((x) => x.name == r);
    return role.isEmpty ? null : Session(n, role.first);
  }

  void login(String name, Role role) {
    final p = ref.read(prefsProvider);
    p.setString('user_name', name.trim());
    p.setString('user_role', role.name);
    state = Session(name.trim(), role);
  }

  void logout() {
    final p = ref.read(prefsProvider);
    p.remove('user_name');
    p.remove('user_role');
    state = null;
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);

// ---------------------------------------------------------------------------
// Repository: one method per backend endpoint
// ---------------------------------------------------------------------------
class Repo {
  Repo(this.api);
  final ApiClient api;

  List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
      (v as List? ?? []).whereType<Map>().map((e) => f(Map<String, dynamic>.from(e))).toList();

  // catalogue
  Future<List<Dept>> departments() async => _list(await api.get('/departments'), Dept.fromJson);
  Future<List<Category>> categories() async => _list(await api.get('/categories'), Category.fromJson);
  Future<List<Item>> items() async => _list(await api.get('/items'), Item.fromJson);
  Future<List<Location>> locations() async => _list(await api.get('/stock-locations'), Location.fromJson);
  Future<void> createDepartment(String name, String description) =>
      api.post('/departments', body: {'name': name, 'description': description});
  Future<void> createCategory(String name, String description, int departmentId) =>
      api.post('/categories', body: {'name': name, 'description': description, 'departmentId': departmentId});
  Future<void> createItem({
    required String code,
    required String name,
    required String description,
    required String uom,
    required int categoryId,
    required double minLevel,
    required double reorderLevel,
  }) =>
      api.post('/items', body: {
        'itemCode': code,
        'name': name,
        'description': description,
        'unitOfMeasure': uom,
        'categoryId': categoryId,
        'minimumStockLevel': minLevel,
        'reorderLevel': reorderLevel,
      });

  // stock
  Future<List<Balance>> balances() async => _list(await api.get('/stock-balances'), Balance.fromJson);
  Future<List<Movement>> movements() async => _list(await api.get('/stock-movements'), Movement.fromJson);
  Future<void> addToStock({
    required int itemId,
    required int locationId,
    required double quantity,
    required String reference,
    required String remarks,
    required String by,
  }) =>
      api.post('/stock-movements/receive', query: {
        'itemId': '$itemId',
        'locationId': '$locationId',
        'quantity': '$quantity',
        'referenceNumber': reference,
        'remarks': remarks,
        'performedBy': by,
      });

  // item requisitions
  Future<List<Requisition>> requisitions() async => _list(await api.get('/requisitions'), Requisition.fromJson);
  Future<void> createRequisition({
    required String department,
    required String officer,
    required String purpose,
    required List<({int itemId, int qty, String uom, String description})> lines,
  }) =>
      api.post('/requisitions', body: {
        'requestingDepartment': department,
        'requestingOfficer': officer,
        'purpose': purpose,
        'items': [
          for (final l in lines)
            {'item': {'id': l.itemId}, 'description': l.description, 'quantity': l.qty, 'unitOfMeasure': l.uom}
        ],
      });
  Future<void> storesReview(int id, String by, List<Map<String, dynamic>> lines) =>
      api.post('/requisitions/$id/stores-review', query: {'stockController': by}, body: lines);
  Future<void> submitRequisition(int id, String by) =>
      api.post('/requisitions/$id/submit', query: {'stockController': by});
  Future<void> headApprove(int id, String by, String comments) =>
      api.post('/requisitions/$id/head/approve', query: {'headName': by, 'comments': comments});
  Future<void> headReject(int id, String by, String comments) =>
      api.post('/requisitions/$id/head/reject', query: {'headName': by, 'comments': comments});
  Future<void> omApprove(int id, String by, String comments) =>
      api.post('/requisitions/$id/operations-manager/approve', query: {'operationsManager': by, 'comments': comments});
  Future<void> omReject(int id, String by, String comments) =>
      api.post('/requisitions/$id/operations-manager/reject', query: {'operationsManager': by, 'comments': comments});

  // stock issues
  Future<List<StockIssue>> issues() async => _list(await api.get('/stock-issues'), StockIssue.fromJson);
  Future<void> issueStock(int requisitionId, String issuedBy, String receivedBy, String remarks,
          List<Map<String, dynamic>> lines) =>
      api.post('/stock-issues/requisition/$requisitionId',
          query: {'issuedBy': issuedBy, 'receivedBy': receivedBy, 'remarks': remarks}, body: lines);

  // purchase requests
  Future<List<PurchaseRequest>> purchaseRequests() async =>
      _list(await api.get('/purchase-requests'), PurchaseRequest.fromJson);
  Future<void> createPurchaseRequest({
    required int requisitionId,
    required String by,
    required String justification,
    required List<Map<String, dynamic>> items,
  }) =>
      api.post('/purchase-requests',
          body: {'requisitionId': requisitionId, 'requestedBy': by, 'justification': justification, 'items': items});
  Future<void> submitDirectorate(int id, String om, String comments) => api.post(
      '/purchase-requests/$id/submit-for-directorate-approval',
      query: {'operationsManager': om, 'comments': comments});
  Future<void> od1Approve(int id, String by, String c) =>
      api.post('/purchase-requests/$id/od1/approve', query: {'approver': by, 'comments': c});
  Future<void> od1Reject(int id, String by, String c) =>
      api.post('/purchase-requests/$id/od1/reject', query: {'rejector': by, 'comments': c});
  Future<void> od2Approve(int id, String by, String c) =>
      api.post('/purchase-requests/$id/od2/approve', query: {'approver': by, 'comments': c});
  Future<void> od2Reject(int id, String by, String c) =>
      api.post('/purchase-requests/$id/od2/reject', query: {'rejector': by, 'comments': c});
  Future<void> raApprove(int id, String by, String c) =>
      api.post('/purchase-requests/$id/ra/approve', query: {'approver': by, 'comments': c});
  Future<void> raReject(int id, String by, String c) =>
      api.post('/purchase-requests/$id/ra/reject', query: {'rejector': by, 'comments': c});

  // purchase orders
  Future<List<PurchaseOrder>> purchaseOrders() async =>
      _list(await api.get('/purchase-orders'), PurchaseOrder.fromJson);
  Future<void> createPurchaseOrder(Map<String, dynamic> body) => api.post('/purchase-orders', body: body);
  Future<void> issuePo(int id, String by) => api.put('/purchase-orders/$id/issue', query: {'issuedBy': by});
  Future<void> cancelPo(int id, String by, String reason) =>
      api.put('/purchase-orders/$id/cancel', query: {'cancelledBy': by, 'reason': reason});

  // goods received vouchers
  Future<List<Grv>> grvs() async => _list(await api.get('/grvs'), Grv.fromJson);
  Future<void> createGrv(Map<String, dynamic> body) => api.post('/grvs', body: body);
  Future<void> grvSubmit(int id, String by) => api.put('/grvs/$id/submit', query: {'submittedBy': by});
  Future<void> grvVerify(int id, String by, String remarks) =>
      api.put('/grvs/$id/verify', query: {'stockController': by, 'remarks': remarks});
  Future<void> grvApprove(int id, String by, String comments) =>
      api.put('/grvs/$id/approve', query: {'operationsManager': by, 'comments': comments});
  Future<void> grvReject(int id, String by, String reason) =>
      api.put('/grvs/$id/reject', query: {'operationsManager': by, 'reason': reason});
}

final repoProvider = Provider<Repo>((ref) => Repo(ref.watch(apiProvider)));

final departmentsP = FutureProvider.autoDispose<List<Dept>>((ref) => ref.watch(repoProvider).departments());
final categoriesP = FutureProvider.autoDispose<List<Category>>((ref) => ref.watch(repoProvider).categories());
final itemsP = FutureProvider.autoDispose<List<Item>>((ref) => ref.watch(repoProvider).items());
final locationsP = FutureProvider.autoDispose<List<Location>>((ref) => ref.watch(repoProvider).locations());
final balancesP = FutureProvider.autoDispose<List<Balance>>((ref) => ref.watch(repoProvider).balances());
final movementsP = FutureProvider.autoDispose<List<Movement>>((ref) => ref.watch(repoProvider).movements());
final requisitionsP = FutureProvider.autoDispose<List<Requisition>>((ref) => ref.watch(repoProvider).requisitions());
final issuesP = FutureProvider.autoDispose<List<StockIssue>>((ref) => ref.watch(repoProvider).issues());
final prsP = FutureProvider.autoDispose<List<PurchaseRequest>>((ref) => ref.watch(repoProvider).purchaseRequests());
final posP = FutureProvider.autoDispose<List<PurchaseOrder>>((ref) => ref.watch(repoProvider).purchaseOrders());
final grvsP = FutureProvider.autoDispose<List<Grv>>((ref) => ref.watch(repoProvider).grvs());

/// Re-load everything after an action.
void refreshAll(WidgetRef ref) {
  for (final p in [
    departmentsP, categoriesP, itemsP, locationsP, balancesP, movementsP,
    requisitionsP, issuesP, prsP, posP, grvsP,
  ]) {
    ref.invalidate(p);
  }
}

/// Total on hand per item id (all locations).
Map<int, double> onHandByItem(List<Balance> balances) {
  final m = <int, double>{};
  for (final b in balances) {
    m[b.item.id] = (m[b.item.id] ?? 0) + b.qty;
  }
  return m;
}
