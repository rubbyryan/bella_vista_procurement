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
  const Session(this.name, this.role, [this.department = '']);
  final String name;
  final Role role;
  final String department; // assigned by the System Administrator (may be empty)
}

class SessionNotifier extends Notifier<Session?> {
  @override
  Session? build() {
    final p = ref.read(prefsProvider);
    final n = p.getString('user_name');
    final r = p.getString('user_role');
    if (n == null || r == null) return null;
    final role = Role.values.where((x) => x.name == r);
    return role.isEmpty ? null : Session(n, role.first, p.getString('user_dept') ?? '');
  }

  void login(String name, Role role, {String department = ''}) {
    final p = ref.read(prefsProvider);
    p.setString('user_name', name.trim());
    p.setString('user_role', role.name);
    p.setString('user_dept', department.trim());
    state = Session(name.trim(), role, department.trim());
  }

  void logout() {
    final p = ref.read(prefsProvider);
    p.remove('user_name');
    p.remove('user_role');
    p.remove('user_dept');
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
  Future<Item> item(int id) async => Item.fromJson(Map<String, dynamic>.from(await api.get('/items/$id') as Map));
  Future<List<Item>> itemsByCategory(int categoryId) async =>
      _list(await api.get('/items/category/$categoryId'), Item.fromJson);
  Future<List<Item>> itemsByDepartment(int departmentId) async =>
      _list(await api.get('/items/department/$departmentId'), Item.fromJson);
  Future<List<Location>> locations() async => _list(await api.get('/stock-locations'), Location.fromJson);
  Future<Location> location(int id) async =>
      Location.fromJson(Map<String, dynamic>.from(await api.get('/stock-locations/$id') as Map));
  Future<void> createLocation(String name, String description) =>
      api.post('/stock-locations', body: {'name': name, 'description': description});
  Future<void> updateLocation(int id, String name, String description) =>
      api.put('/stock-locations/$id', body: {'name': name, 'description': description});
  Future<void> deactivateLocation(int id) => api.patch('/stock-locations/$id/deactivate');
  Future<void> createDepartment(String name, String description) =>
      api.post('/departments', body: {'name': name, 'description': description});
  Future<Dept> department(int id) async => Dept.fromJson(Map<String, dynamic>.from(await api.get('/departments/$id') as Map));
  Future<void> updateDepartment(int id, String name, String description) =>
      api.put('/departments/$id', body: {'name': name, 'description': description});
  Future<void> createCategory(String name, String description, int departmentId) =>
      api.post('/categories', body: {'name': name, 'description': description, 'departmentId': departmentId});
  Future<Category> category(int id) async => Category.fromJson(Map<String, dynamic>.from(await api.get('/categories/$id') as Map));
  Future<List<Category>> categoriesByDepartment(int departmentId) async =>
      _list(await api.get('/categories/department/$departmentId'), Category.fromJson);
  Future<void> updateCategory(int id, String name, String description, int departmentId) =>
      api.put('/categories/$id', body: {'name': name, 'description': description, 'departmentId': departmentId});
  Future<void> deactivateCategory(int id) => api.patch('/categories/$id/deactivate');
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
  Future<Balance> balance(int id) async =>
      Balance.fromJson(Map<String, dynamic>.from(await api.get('/stock-balances/$id') as Map));
  Future<List<Balance>> balancesByLocation(int locationId) async =>
      _list(await api.get('/stock-balances/location/$locationId'), Balance.fromJson);
  Future<List<Balance>> balancesByItem(int itemId) async =>
      _list(await api.get('/stock-balances/item/$itemId'), Balance.fromJson);
  Future<Balance> balanceFor(int itemId, int locationId) async =>
      Balance.fromJson(Map<String, dynamic>.from(await api.get('/stock-balances/item/$itemId/location/$locationId') as Map));
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
  Future<Requisition> requisition(int id) async =>
      Requisition.fromJson(Map<String, dynamic>.from(await api.get('/requisitions/$id') as Map));
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
  Future<StockIssue> issue(int id) async =>
      StockIssue.fromJson(Map<String, dynamic>.from(await api.get('/stock-issues/$id') as Map));
  Future<StockIssue> issueByNumber(String number) async => StockIssue.fromJson(
      Map<String, dynamic>.from(await api.get('/stock-issues/number/${Uri.encodeComponent(number.trim())}') as Map));
  Future<List<StockIssue>> issuesForRequisition(int requisitionId) async =>
      _list(await api.get('/stock-issues/requisition/$requisitionId'), StockIssue.fromJson);
  Future<void> issueStock(int requisitionId, String issuedBy, String receivedBy, String remarks,
      List<Map<String, dynamic>> lines) =>
      api.post('/stock-issues/requisition/$requisitionId',
          query: {'issuedBy': issuedBy, 'receivedBy': receivedBy, 'remarks': remarks}, body: lines);

  // purchase requests
  Future<List<PurchaseRequest>> purchaseRequests() async =>
      _list(await api.get('/purchase-requests'), PurchaseRequest.fromJson);
  Future<PurchaseRequest> purchaseRequest(int id) async =>
      PurchaseRequest.fromJson(Map<String, dynamic>.from(await api.get('/purchase-requests/$id') as Map));
  Future<PurchaseRequest> purchaseRequestByNumber(String number) async => PurchaseRequest.fromJson(
      Map<String, dynamic>.from(await api.get('/purchase-requests/number/${Uri.encodeComponent(number.trim())}') as Map));
  Future<PurchaseRequest> purchaseRequestForRequisition(int requisitionId) async => PurchaseRequest.fromJson(
      Map<String, dynamic>.from(await api.get('/purchase-requests/requisition/$requisitionId') as Map));
  Future<List<PurchaseRequest>> purchaseRequestsByStatus(String status) async =>
      _list(await api.get('/purchase-requests/status/$status'), PurchaseRequest.fromJson);
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
  Future<PurchaseOrder> purchaseOrder(int id) async =>
      PurchaseOrder.fromJson(Map<String, dynamic>.from(await api.get('/purchase-orders/$id') as Map));
  Future<PurchaseOrder> purchaseOrderByNumber(String number) async => PurchaseOrder.fromJson(
      Map<String, dynamic>.from(await api.get('/purchase-orders/number/${Uri.encodeComponent(number.trim())}') as Map));
  Future<List<PurchaseOrder>> purchaseOrdersForRequest(int purchaseRequestId) async =>
      _list(await api.get('/purchase-orders/purchase-request/$purchaseRequestId'), PurchaseOrder.fromJson);
  Future<List<PurchaseOrder>> purchaseOrdersByStatus(String status) async =>
      _list(await api.get('/purchase-orders/status/$status'), PurchaseOrder.fromJson);
  Future<void> createPurchaseOrder(Map<String, dynamic> body) => api.post('/purchase-orders', body: body);
  Future<void> issuePo(int id, String by) => api.put('/purchase-orders/$id/issue', query: {'issuedBy': by});
  Future<void> cancelPo(int id, String by, String reason) =>
      api.put('/purchase-orders/$id/cancel', query: {'cancelledBy': by, 'reason': reason});

  // goods received vouchers
  Future<List<Grv>> grvs() async => _list(await api.get('/grvs'), Grv.fromJson);
  Future<Grv> grv(int id) async => Grv.fromJson(Map<String, dynamic>.from(await api.get('/grvs/$id') as Map));
  Future<Grv> grvByNumber(String number) async =>
      Grv.fromJson(Map<String, dynamic>.from(await api.get('/grvs/number/${Uri.encodeComponent(number.trim())}') as Map));
  Future<List<Grv>> grvsForOrder(int purchaseOrderId) async =>
      _list(await api.get('/grvs/purchase-order/$purchaseOrderId'), Grv.fromJson);
  Future<List<Grv>> grvsByStatus(String status) async =>
      _list(await api.get('/grvs/status/$status'), Grv.fromJson);
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
final categoriesByDeptP = FutureProvider.autoDispose.family<List<Category>, int>(
        (ref, departmentId) => ref.watch(repoProvider).categoriesByDepartment(departmentId));
final itemsByCategoryP = FutureProvider.autoDispose.family<List<Item>, int>(
        (ref, categoryId) => ref.watch(repoProvider).itemsByCategory(categoryId));
final itemsByDeptP = FutureProvider.autoDispose.family<List<Item>, int>(
        (ref, departmentId) => ref.watch(repoProvider).itemsByDepartment(departmentId));
final itemsP = FutureProvider.autoDispose<List<Item>>((ref) => ref.watch(repoProvider).items());
final locationsP = FutureProvider.autoDispose<List<Location>>((ref) => ref.watch(repoProvider).locations());
final balancesP = FutureProvider.autoDispose<List<Balance>>((ref) => ref.watch(repoProvider).balances());
final movementsP = FutureProvider.autoDispose<List<Movement>>((ref) => ref.watch(repoProvider).movements());
final requisitionsP = FutureProvider.autoDispose<List<Requisition>>((ref) => ref.watch(repoProvider).requisitions());
final requisitionByIdP = FutureProvider.autoDispose.family<Requisition, int>(
        (ref, id) => ref.watch(repoProvider).requisition(id));
final balancesByLocationP = FutureProvider.autoDispose.family<List<Balance>, int>(
        (ref, locationId) => ref.watch(repoProvider).balancesByLocation(locationId));
final balancesByItemP = FutureProvider.autoDispose.family<List<Balance>, int>(
        (ref, itemId) => ref.watch(repoProvider).balancesByItem(itemId));
/// One item at one location. Resolves to an empty list when no record exists yet.
final balanceForP = FutureProvider.autoDispose.family<List<Balance>, (int, int)>((ref, key) async {
  try {
    return [await ref.watch(repoProvider).balanceFor(key.$1, key.$2)];
  } catch (_) {
    return <Balance>[];
  }
});
final issuesByRequisitionP = FutureProvider.autoDispose.family<List<StockIssue>, int>(
        (ref, requisitionId) => ref.watch(repoProvider).issuesForRequisition(requisitionId));
final issuesP = FutureProvider.autoDispose<List<StockIssue>>((ref) => ref.watch(repoProvider).issues());
final prsP = FutureProvider.autoDispose<List<PurchaseRequest>>((ref) => ref.watch(repoProvider).purchaseRequests());
final posP = FutureProvider.autoDispose<List<PurchaseOrder>>((ref) => ref.watch(repoProvider).purchaseOrders());
final grvsP = FutureProvider.autoDispose<List<Grv>>((ref) => ref.watch(repoProvider).grvs());

final prByIdP = FutureProvider.autoDispose.family<PurchaseRequest, int>((ref, id) => ref.watch(repoProvider).purchaseRequest(id));
final poByIdP = FutureProvider.autoDispose.family<PurchaseOrder, int>((ref, id) => ref.watch(repoProvider).purchaseOrder(id));
final grvByIdP = FutureProvider.autoDispose.family<Grv, int>((ref, id) => ref.watch(repoProvider).grv(id));
final prsByStatusP = FutureProvider.autoDispose.family<List<PurchaseRequest>, String>(
        (ref, status) => ref.watch(repoProvider).purchaseRequestsByStatus(status));
final posByStatusP = FutureProvider.autoDispose.family<List<PurchaseOrder>, String>(
        (ref, status) => ref.watch(repoProvider).purchaseOrdersByStatus(status));
final grvsByStatusP = FutureProvider.autoDispose.family<List<Grv>, String>(
        (ref, status) => ref.watch(repoProvider).grvsByStatus(status));
final grvsForOrderP = FutureProvider.autoDispose.family<List<Grv>, int>(
        (ref, purchaseOrderId) => ref.watch(repoProvider).grvsForOrder(purchaseOrderId));

/// Re-load everything after an action.
void refreshAll(WidgetRef ref) {
  for (final p in [
    departmentsP, categoriesP, itemsP, locationsP, balancesP, movementsP,
    requisitionsP, issuesP, prsP, posP, grvsP,
  ]) {
    ref.invalidate(p);
  }
  ref.invalidate(categoriesByDeptP);
  ref.invalidate(itemsByCategoryP);
  ref.invalidate(itemsByDeptP);
  ref.invalidate(requisitionByIdP);
  ref.invalidate(issuesByRequisitionP);
  ref.invalidate(balancesByLocationP);
  ref.invalidate(balancesByItemP);
  ref.invalidate(balanceForP);
  ref.invalidate(prByIdP);
  ref.invalidate(poByIdP);
  ref.invalidate(grvByIdP);
  ref.invalidate(prsByStatusP);
  ref.invalidate(posByStatusP);
  ref.invalidate(grvsByStatusP);
  ref.invalidate(grvsForOrderP);
}

/// Total on hand per item id (all locations).
Map<int, double> onHandByItem(List<Balance> balances) {
  final m = <int, double>{};
  for (final b in balances) {
    m[b.item.id] = (m[b.item.id] ?? 0) + b.qty;
  }
  return m;
}