enum UserRole {
  requester('Requester'),
  storesController('Stores Controller'),
  schoolHead('School Head'),
  operationsManager('Operations Manager'),
  headOfficeAdmin('Head Office Admin'),
  driver('Driver'),
  security('Security');

  final String label;
  const UserRole(this.label);
}

/// Alias so existing code that says `Role` keeps compiling.
typedef Role = UserRole;

class RequisitionItemModel {
  final String itemName;
  final String unit;
  final int qtyRequested;
  final int onHand;
  final double estPrice;
  String storesDecision;

  RequisitionItemModel({
    required this.itemName,
    required this.unit,
    required this.qtyRequested,
    required this.onHand,
    required this.estPrice,
    this.storesDecision = 'Issue from stock',
  });
}

class RequisitionModel {
  final String id;
  final String department;
  final String requesterName;
  final String date;
  final double totalValue;
  final List<RequisitionItemModel> items;

  /// e.g. "Stores Review", "Pending Head", "Pending OM", "Pending HO",
  /// "Approved", "Rejected", "Partial", "Completed"
  String status;
  String? rejectionComment;

  RequisitionModel({
    required this.id,
    required this.department,
    required this.requesterName,
    required this.date,
    required this.totalValue,
    required this.items,
    required this.status,
    this.rejectionComment,
  });
}

class AppStateModel {
  final UserRole currentRole;
  final List<RequisitionModel> requisitions;

  const AppStateModel({
    required this.currentRole,
    required this.requisitions,
  });
}
