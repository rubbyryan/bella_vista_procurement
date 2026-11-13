import 'theme/bv_theme.dart';

// ---------------------------------------------------------------------------
// Tolerant JSON helpers (the Spring backend returns entities directly)
// ---------------------------------------------------------------------------
double _d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
int _i(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);
String _s(dynamic v) => v == null ? '' : '$v';
String? _sn(dynamic v) => v == null || '$v'.isEmpty ? null : '$v';
Map<String, dynamic>? _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;
List<T> _l<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
    v is List ? v.whereType<Map>().map((e) => f(Map<String, dynamic>.from(e))).toList() : <T>[];

DateTime? _dt(dynamic v) {
  if (v == null) return null;
  if (v is String) return DateTime.tryParse(v);
  if (v is List && v.length >= 3) {
    return DateTime(_i(v[0]), _i(v[1]), _i(v[2]), v.length > 3 ? _i(v[3]) : 0, v.length > 4 ? _i(v[4]) : 0);
  }
  return null;
}

/// 12 -> "12", 12.5 -> "12.5"
String qty(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

// ---------------------------------------------------------------------------
// Roles. The backend has no login yet: the person picks a name and a role, the
// role only decides which screens and buttons the app shows.
// ---------------------------------------------------------------------------
enum Role { requester, stores, head, om, od1, od2, ra, security, admin }

extension RoleX on Role {
  String get label => switch (this) {
        Role.requester => 'Requester',
        Role.stores => 'Stores Controller',
        Role.head => 'Headmaster',
        Role.om => 'Operations Manager',
        Role.od1 => 'Operations Directorate 1 (OD1)',
        Role.od2 => 'Operations Directorate 2 (OD2)',
        Role.ra => 'Responsible Authority (RA)',
        Role.security => 'Security Officer',
        Role.admin => 'System Administrator',
      };
}

// ---------------------------------------------------------------------------
// Catalogue and stock
// ---------------------------------------------------------------------------
class Dept {
  Dept(this.id, this.name, this.description, [this.active = true]);
  factory Dept.fromJson(Map<String, dynamic> j) =>
      Dept(_i(j['id']), _s(j['name']), _s(j['description']), j['active'] is bool ? j['active'] as bool : true);
  final int id;
  final String name;
  final String description;
  final bool active;
}

class Category {
  Category(this.id, this.name, this.departmentName, this.departmentId, {this.description = '', this.active = true});
  factory Category.fromJson(Map<String, dynamic> j) {
    final d = _m(j['department']);
    return Category(
      _i(j['id']),
      _s(j['name']),
      _s(d?['name'] ?? j['departmentName']),
      _i(d?['id'] ?? j['departmentId']),
      description: _s(j['description']),
      active: j['active'] is bool ? j['active'] as bool : true,
    );
  }
  final int id;
  final String name;
  final String departmentName;
  final int departmentId;
  final String description;
  final bool active;
}

class Item {
  Item({
    required this.id,
    required this.code,
    required this.name,
    required this.uom,
    required this.categoryName,
    required this.departmentName,
    required this.minLevel,
    required this.reorderLevel,
    this.description = '',
    this.categoryId = 0,
    this.active = true,
  });
  factory Item.fromJson(Map<String, dynamic> j) {
    final c = _m(j['category']);
    final d = _m(c?['department']);
    return Item(
      id: _i(j['id']),
      code: _s(j['itemCode']),
      name: _s(j['name']),
      uom: _s(j['unitOfMeasure']),
      categoryName: _s(j['categoryName'] ?? c?['name']),
      departmentName: _s(j['departmentName'] ?? d?['name']),
      minLevel: _d(j['minimumStockLevel']),
      reorderLevel: _d(j['reorderLevel']),
      description: _s(j['description']),
      categoryId: _i(j['categoryId'] ?? c?['id']),
      active: j['active'] is bool ? j['active'] as bool : true,
    );
  }
  final String description;
  final int categoryId;
  final bool active;
  final int id;
  final String code;
  final String name;
  final String uom;
  final String categoryName;
  final String departmentName;
  final double minLevel;
  final double reorderLevel;
  String get label => '$code | $name';
}

class Location {
  Location(this.id, this.name, this.description, [this.active = true]);
  factory Location.fromJson(Map<String, dynamic> j) =>
      Location(_i(j['id']), _s(j['name']), _s(j['description']), j['active'] is bool ? j['active'] as bool : true);
  final int id;
  final String name;
  final String description;
  final bool active;
}

class Balance {
  Balance(this.item, this.location, this.qty, {this.id = 0, this.updated});
  factory Balance.fromJson(Map<String, dynamic> j) => Balance(
      Item.fromJson(_m(j['item']) ?? {}), Location.fromJson(_m(j['location']) ?? {}), _d(j['quantityOnHand']),
      id: _i(j['id']), updated: _dt(j['lastUpdated']));
  final int id;
  final Item item;
  final Location location;
  final double qty;
  final DateTime? updated;
}

class Movement {
  Movement(this.item, this.type, this.qty, this.ref, this.by, this.at, this.remarks, this.to, this.from);
  factory Movement.fromJson(Map<String, dynamic> j) => Movement(
      _s(_m(j['item'])?['name']), _s(j['movementType']), _d(j['quantity']), _s(j['referenceNumber']),
      _s(j['performedBy']), _dt(j['movementDate']), _s(j['remarks']),
      _s(_m(j['destinationLocation'])?['name']), _s(_m(j['sourceLocation'])?['name']));
  final String item;
  final String type;
  final double qty;
  final String ref;
  final String by;
  final DateTime? at;
  final String remarks;
  final String to;
  final String from;
}

// ---------------------------------------------------------------------------
// Item requisition (issue of stock): Requester > Stores > Head > OM > Issue
// ---------------------------------------------------------------------------
StatusKind _kind(String status) {
  switch (status) {
    case 'NEW':
    case 'DRAFT':
    case 'CANCELLED':
      return StatusKind.neutral;
    case 'STORES_REVIEW':
    case 'READY_FOR_ISSUE':
    case 'PARTIALLY_ISSUED':
    case 'ISSUED':
    case 'PARTIALLY_RECEIVED':
    case 'CONVERTED_TO_PO':
    case 'CONVERTED_TO_PURCHASE':
    case 'PENDING_STOCK_VERIFICATION':
      return StatusKind.inProgress;
    case 'RESOLVED':
    case 'APPROVED':
    case 'FULLY_RECEIVED':
    case 'FULLY_ACCEPTED':
    case 'PARTIALLY_ACCEPTED':
      return StatusKind.success;
    case 'REJECTED':
      return StatusKind.danger;
    default:
      return StatusKind.pending; // PENDING_*, RETURNED_TO_OM
  }
}

String statusLabel(String s) {
  const special = {
    'PENDING_HEAD_APPROVAL': 'Pending Head',
    'PENDING_OM_APPROVAL': 'Pending OM',
    'PENDING_DIRECTORATE_APPROVAL': 'Pending OD1 / OD2',
    'PENDING_RA_APPROVAL': 'Pending RA',
    'PENDING_STOCK_VERIFICATION': 'Pending verification',
    'READY_FOR_ISSUE': 'Ready for issue',
    'CONVERTED_TO_PO': 'Purchase order raised',
    'RETURNED_TO_OM': 'Returned to OM',
    'STORES_REVIEW': 'Stores review',
    'NEW': 'New',
  };
  if (special.containsKey(s)) return special[s]!;
  final t = s.toLowerCase().replaceAll('_', ' ');
  return t.isEmpty ? '' : t[0].toUpperCase() + t.substring(1);
}

StatusKind statusKind(String s) => _kind(s);

class ReqLine {
  ReqLine({
    required this.id,
    required this.item,
    required this.description,
    required this.quantity,
    required this.uom,
    required this.available,
    required this.recommended,
    required this.shortage,
    required this.remarks,
    required this.verified,
  });
  factory ReqLine.fromJson(Map<String, dynamic> j) => ReqLine(
        id: _i(j['id']),
        item: Item.fromJson(_m(j['item']) ?? {}),
        description: _s(j['description']),
        quantity: _i(j['quantity']),
        uom: _s(j['unitOfMeasure']),
        available: j['quantityAvailable'] == null ? null : _i(j['quantityAvailable']),
        recommended: j['quantityRecommended'] == null ? null : _i(j['quantityRecommended']),
        shortage: j['quantityShortage'] == null ? null : _i(j['quantityShortage']),
        remarks: _s(j['storesRemarks']),
        verified: j['storesVerified'] == true,
      );
  final int id;
  final Item item;
  final String description;
  final int quantity;
  final String uom;
  final int? available;
  final int? recommended;
  final int? shortage;
  final String remarks;
  final bool verified;
}

class Requisition {
  Requisition({
    required this.id,
    required this.number,
    required this.department,
    required this.officer,
    required this.date,
    required this.purpose,
    required this.status,
    required this.stockController,
    required this.headBy,
    required this.headComments,
    required this.headDate,
    required this.omBy,
    required this.omComments,
    required this.omDate,
    required this.lines,
  });
  factory Requisition.fromJson(Map<String, dynamic> j) => Requisition(
        id: _i(j['id']),
        number: _s(j['requisitionNumber']),
        department: _s(j['requestingDepartment']),
        officer: _s(j['requestingOfficer']),
        date: _dt(j['requestDate']),
        purpose: _s(j['purpose']),
        status: _s(j['status']),
        stockController: _s(j['stockController']),
        headBy: _sn(j['headApprovedBy']),
        headComments: _sn(j['headApprovalComments']),
        headDate: _dt(j['headApprovalDate']),
        omBy: _sn(j['operationsManagerApprovedBy']),
        omComments: _sn(j['operationsManagerComments']),
        omDate: _dt(j['operationsManagerApprovalDate']),
        lines: _l(j['items'], ReqLine.fromJson),
      );
  final int id;
  final String number;
  final String department;
  final String officer;
  final DateTime? date;
  final String purpose;
  final String status;
  final String stockController;
  final String? headBy;
  final String? headComments;
  final DateTime? headDate;
  final String? omBy;
  final String? omComments;
  final DateTime? omDate;
  final List<ReqLine> lines;

  bool get allVerified => lines.isNotEmpty && lines.every((l) => l.verified);
  bool get hasShortage => lines.any((l) => (l.shortage ?? 0) > 0);
  String get summary {
    final n = lines.map((l) => l.item.name).toList();
    final shown = n.take(2).join(', ');
    return n.length > 2 ? '$shown +${n.length - 2}' : shown;
  }
}

class IssueLine {
  IssueLine(this.requisitionLineId, this.item, this.location, this.qty, this.uom, [this.remarks = '']);
  factory IssueLine.fromJson(Map<String, dynamic> j) => IssueLine(
      _i(_m(j['requisitionLine'])?['id']), Item.fromJson(_m(j['item']) ?? {}),
      _s(_m(j['stockLocation'])?['name']), _d(j['quantityIssued']), _s(j['unitOfMeasure']), _s(j['remarks']));
  final String remarks;
  final int requisitionLineId;
  final Item item;
  final String location;
  final double qty;
  final String uom;
}

class StockIssue {
  StockIssue(this.id, this.number, this.requisitionId, this.issuedBy, this.receivedBy, this.date, this.remarks, this.lines,
      [this.requisitionNumber = '']);
  factory StockIssue.fromJson(Map<String, dynamic> j) => StockIssue(
      _i(j['id']), _s(j['issueNumber']), _i(_m(j['requisition'])?['id']), _s(j['issuedBy']), _s(j['receivedBy']),
      _dt(j['issueDate']), _s(j['remarks']), _l(j['items'], IssueLine.fromJson),
      _s(_m(j['requisition'])?['requisitionNumber']));
  final String requisitionNumber;
  final int id;
  final String number;
  final int requisitionId;
  final String issuedBy;
  final String receivedBy;
  final DateTime? date;
  final String remarks;
  final List<IssueLine> lines;
}

// ---------------------------------------------------------------------------
// Purchase request: Stores > OM > OD1 + OD2 > (RA at USD 1,000 or more)
// ---------------------------------------------------------------------------
class PrLine {
  PrLine(this.id, this.item, this.quantity, this.uom, this.unitPrice, this.total, this.remarks);
  factory PrLine.fromJson(Map<String, dynamic> j) => PrLine(_i(j['id']), Item.fromJson(_m(j['item']) ?? {}),
      _d(j['quantity']), _s(j['unitOfMeasure']), _d(j['estimatedUnitPrice']), _d(j['estimatedLineTotal']), _s(j['remarks']));
  final int id;
  final Item item;
  final double quantity;
  final String uom;
  final double unitPrice;
  final double total;
  final String remarks;
}

class PurchaseRequest {
  PurchaseRequest({
    required this.id,
    required this.number,
    required this.requisitionId,
    required this.requisitionNumber,
    required this.date,
    required this.requestedBy,
    required this.department,
    required this.justification,
    required this.status,
    required this.total,
    required this.omBy,
    required this.omComments,
    required this.omDate,
    required this.od1By,
    required this.od1Comments,
    required this.od1Date,
    required this.od1RejBy,
    required this.od1RejComments,
    required this.od2By,
    required this.od2Comments,
    required this.od2Date,
    required this.od2RejBy,
    required this.od2RejComments,
    required this.raBy,
    required this.raComments,
    required this.raDate,
    required this.raRejBy,
    required this.raRejComments,
    required this.lines,
  });
  factory PurchaseRequest.fromJson(Map<String, dynamic> j) {
    final r = _m(j['requisition']);
    return PurchaseRequest(
      id: _i(j['id']),
      number: _s(j['requestNumber']),
      requisitionId: _i(r?['id']),
      requisitionNumber: _s(r?['requisitionNumber']),
      date: _dt(j['requestDate']),
      requestedBy: _s(j['requestedBy']),
      department: _s(j['requestingDepartment']),
      justification: _s(j['justification']),
      status: _s(j['status']),
      total: _d(j['estimatedTotal']),
      omBy: _sn(j['operationsManager']),
      omComments: _sn(j['omComments']),
      omDate: _dt(j['omReviewDate']),
      od1By: _sn(j['od1ApprovedBy']),
      od1Comments: _sn(j['od1Comments']),
      od1Date: _dt(j['od1ApprovalDate']),
      od1RejBy: _sn(j['od1RejectedBy']),
      od1RejComments: _sn(j['od1RejectionComments']),
      od2By: _sn(j['od2ApprovedBy']),
      od2Comments: _sn(j['od2Comments']),
      od2Date: _dt(j['od2ApprovalDate']),
      od2RejBy: _sn(j['od2RejectedBy']),
      od2RejComments: _sn(j['od2RejectionComments']),
      raBy: _sn(j['responsibleAuthority']),
      raComments: _sn(j['raComments']),
      raDate: _dt(j['raApprovalDate']),
      raRejBy: _sn(j['raRejectedBy']),
      raRejComments: _sn(j['raRejectionComments']),
      lines: _l(j['items'], PrLine.fromJson),
    );
  }
  final int id;
  final String number;
  final int requisitionId;
  final String requisitionNumber;
  final DateTime? date;
  final String requestedBy;
  final String department;
  final String justification;
  final String status;
  final double total;
  final String? omBy, omComments, od1By, od1Comments, od1RejBy, od1RejComments;
  final String? od2By, od2Comments, od2RejBy, od2RejComments, raBy, raComments, raRejBy, raRejComments;
  final DateTime? omDate, od1Date, od2Date, raDate;
  final List<PrLine> lines;

  bool get needsRa => total >= 1000;
  String get summary {
    final n = lines.map((l) => l.item.name).toList();
    final shown = n.take(2).join(', ');
    return n.length > 2 ? '$shown +${n.length - 2}' : shown;
  }
}

// ---------------------------------------------------------------------------
// Purchase order
// ---------------------------------------------------------------------------
class PoLine {
  PoLine(this.id, this.prLineId, this.item, this.quantity, this.uom, this.unitPrice, this.total);
  factory PoLine.fromJson(Map<String, dynamic> j) => PoLine(_i(j['id']), _i(_m(j['purchaseRequestLine'])?['id']),
      Item.fromJson(_m(j['item']) ?? {}), _d(j['quantity']), _s(j['unitOfMeasure']), _d(j['unitPrice']), _d(j['lineTotal']));
  final int id;
  final int prLineId;
  final Item item;
  final double quantity;
  final String uom;
  final double unitPrice;
  final double total;
}

class PurchaseOrder {
  PurchaseOrder({
    required this.id,
    required this.number,
    required this.prId,
    required this.prNumber,
    required this.supplier,
    required this.contact,
    required this.orderDate,
    required this.expected,
    required this.deliveryLocation,
    required this.terms,
    required this.remarks,
    required this.subTotal,
    required this.tax,
    required this.total,
    required this.status,
    required this.preparedBy,
    required this.issuedBy,
    required this.lines,
  });
  factory PurchaseOrder.fromJson(Map<String, dynamic> j) {
    final p = _m(j['purchaseRequest']);
    return PurchaseOrder(
      id: _i(j['id']),
      number: _s(j['orderNumber']),
      prId: _i(p?['id']),
      prNumber: _s(p?['requestNumber']),
      supplier: _s(j['supplierName']),
      contact: _s(j['supplierContact']),
      orderDate: _dt(j['orderDate']),
      expected: _dt(j['expectedDeliveryDate']),
      deliveryLocation: _s(j['deliveryLocation']),
      terms: _s(j['paymentTerms']),
      remarks: _s(j['remarks']),
      subTotal: _d(j['subTotal']),
      tax: _d(j['taxAmount']),
      total: _d(j['totalAmount']),
      status: _s(j['status']),
      preparedBy: _s(j['preparedBy']),
      issuedBy: _s(j['issuedBy']),
      lines: _l(j['items'], PoLine.fromJson),
    );
  }
  final int id;
  final String number;
  final int prId;
  final String prNumber;
  final String supplier;
  final String contact;
  final DateTime? orderDate;
  final DateTime? expected;
  final String deliveryLocation;
  final String terms;
  final String remarks;
  final double subTotal;
  final double tax;
  final double total;
  final String status;
  final String preparedBy;
  final String issuedBy;
  final List<PoLine> lines;
}

// ---------------------------------------------------------------------------
// Goods Received Voucher: Create > Submit > Stock Controller verifies > OM approves (adds stock)
// ---------------------------------------------------------------------------
class GrvLine {
  GrvLine({
    required this.id,
    required this.poLineId,
    required this.item,
    required this.location,
    required this.ordered,
    required this.previous,
    required this.delivered,
    required this.accepted,
    required this.rejected,
    required this.damaged,
    required this.outstanding,
    required this.uom,
    required this.remarks,
  });
  factory GrvLine.fromJson(Map<String, dynamic> j) => GrvLine(
        id: _i(j['id']),
        poLineId: _i(_m(j['purchaseOrderLine'])?['id']),
        item: Item.fromJson(_m(j['item']) ?? {}),
        location: _s(_m(j['stockLocation'])?['name']),
        ordered: _d(j['quantityOrdered']),
        previous: _d(j['quantityPreviouslyReceived']),
        delivered: _d(j['quantityDelivered']),
        accepted: _d(j['quantityAccepted']),
        rejected: _d(j['quantityRejected']),
        damaged: _d(j['quantityDamaged']),
        outstanding: _d(j['quantityOutstanding']),
        uom: _s(j['unitOfMeasure']),
        remarks: _s(j['inspectionRemarks']),
      );
  final int id;
  final int poLineId;
  final Item item;
  final String location;
  final double ordered, previous, delivered, accepted, rejected, damaged, outstanding;
  final String uom;
  final String remarks;
}

class Grv {
  Grv({
    required this.id,
    required this.number,
    required this.poId,
    required this.poNumber,
    required this.supplier,
    required this.deliveryNote,
    required this.deliveryDate,
    required this.createdBy,
    required this.receivedBy,
    required this.vehicle,
    required this.driver,
    required this.submittedBy,
    required this.verifiedBy,
    required this.verifyRemarks,
    required this.approvedBy,
    required this.approvalComments,
    required this.rejectedBy,
    required this.rejectionReason,
    required this.remarks,
    required this.status,
    required this.date,
    required this.lines,
  });
  factory Grv.fromJson(Map<String, dynamic> j) {
    final p = _m(j['purchaseOrder']);
    return Grv(
      id: _i(j['id']),
      number: _s(j['grvNumber']),
      poId: _i(p?['id']),
      poNumber: _s(p?['orderNumber']),
      supplier: _s(j['supplierName'] ?? p?['supplierName']),
      deliveryNote: _s(j['deliveryNoteNumber']),
      deliveryDate: _dt(j['deliveryDate']),
      createdBy: _s(j['createdBy']),
      receivedBy: _s(j['receivedBy']),
      vehicle: _s(j['vehicleRegistration']),
      driver: _s(j['driverName']),
      submittedBy: _sn(j['submittedBy']),
      verifiedBy: _sn(j['verifiedBy']),
      verifyRemarks: _sn(j['verificationRemarks']),
      approvedBy: _sn(j['approvedBy']),
      approvalComments: _sn(j['approvalComments']),
      rejectedBy: _sn(j['rejectedBy']),
      rejectionReason: _sn(j['rejectionReason']),
      remarks: _s(j['remarks']),
      status: _s(j['status']),
      date: _dt(j['receivedDate']),
      lines: _l(j['items'], GrvLine.fromJson),
    );
  }
  final int id;
  final String number;
  final int poId;
  final String poNumber;
  final String supplier;
  final String deliveryNote;
  final DateTime? deliveryDate;
  final String createdBy, receivedBy, vehicle, driver;
  final String? submittedBy, verifiedBy, verifyRemarks, approvedBy, approvalComments, rejectedBy, rejectionReason;
  final String remarks;
  final String status;
  final DateTime? date;
  final List<GrvLine> lines;
  bool get stockAdded => status == 'FULLY_ACCEPTED' || status == 'PARTIALLY_ACCEPTED';
}
