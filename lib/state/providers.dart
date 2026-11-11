import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';

// ---------------------------------------------------------------------------
// Appearance
// ---------------------------------------------------------------------------
enum AppAppearance { system, light, dark, primary }

class AppearanceNotifier extends Notifier<AppAppearance> {
  @override
  AppAppearance build() => AppAppearance.system;

  void set(AppAppearance a) => state = a;
}

final appearanceProvider =
    NotifierProvider<AppearanceNotifier, AppAppearance>(AppearanceNotifier.new);

// ---------------------------------------------------------------------------
// App state (role + requisitions)
// ---------------------------------------------------------------------------
class AppStateNotifier extends Notifier<AppStateModel> {
  @override
  AppStateModel build() {
    return AppStateModel(
      currentRole: UserRole.storesController,
      requisitions: [
        RequisitionModel(
          id: 'REQ-2026-0142',
          department: 'Science',
          requesterName: 'Tendai Moyo',
          date: '03 Nov 2026',
          totalValue: 482.50,
          status: 'Stores Review',
          items: [
            RequisitionItemModel(itemName: 'Beakers 250ml', unit: 'each', qtyRequested: 20, onHand: 35, estPrice: 90.00),
            RequisitionItemModel(itemName: 'Marker pens (box)', unit: 'box', qtyRequested: 10, onHand: 2, estPrice: 45.00, storesDecision: 'Issue 2 + buy 8'),
            RequisitionItemModel(itemName: 'Safety goggles', unit: 'each', qtyRequested: 30, onHand: 0, estPrice: 210.00, storesDecision: 'Purchase 30'),
            RequisitionItemModel(itemName: 'Lab coats (L)', unit: 'each', qtyRequested: 6, onHand: 0, estPrice: 137.50, storesDecision: 'Purchase 6'),
          ],
        ),
        RequisitionModel(
          id: 'REQ-2026-0143',
          department: 'Sports',
          requesterName: 'K. Sibanda',
          date: '04 Nov 2026',
          totalValue: 215.00,
          status: 'Pending Head',
          items: [
            RequisitionItemModel(itemName: 'Netballs', unit: 'each', qtyRequested: 5, onHand: 1, estPrice: 150.00),
            RequisitionItemModel(itemName: 'Cones', unit: 'set', qtyRequested: 2, onHand: 0, estPrice: 65.00),
          ],
        ),
        RequisitionModel(
          id: 'REQ-2026-0135',
          department: 'Science',
          requesterName: 'Tendai Moyo',
          date: '27 Oct 2026',
          totalValue: 1120.00,
          status: 'Partial',
          items: [
            RequisitionItemModel(itemName: 'Microscopes', unit: 'each', qtyRequested: 4, onHand: 0, estPrice: 1120.00),
          ],
        ),
      ],
    );
  }

  void setRole(UserRole role) {
    state = AppStateModel(currentRole: role, requisitions: state.requisitions);
  }

  void updateStatus(String id, String newStatus, {String? comment}) {
    state = AppStateModel(
      currentRole: state.currentRole,
      requisitions: state.requisitions.map((req) {
        if (req.id == id) {
          req.status = newStatus;
          if (comment != null) req.rejectionComment = comment;
        }
        return req;
      }).toList(),
    );
  }

  void addRequisition(RequisitionModel req) {
    state = AppStateModel(
      currentRole: state.currentRole,
      requisitions: [req, ...state.requisitions],
    );
  }
}

final appStateProvider =
    NotifierProvider<AppStateNotifier, AppStateModel>(AppStateNotifier.new);
