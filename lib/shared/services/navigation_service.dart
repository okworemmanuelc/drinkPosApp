import 'package:flutter/material.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final ValueNotifier<int> currentIndex = ValueNotifier<int>(0);
  final List<int> _history = [];
  final ValueNotifier<String?> selectedWarehouseId = ValueNotifier<String?>(null);

  /// True when the logged-in user's warehouse access is locked to one location.
  /// CEO (tier 5) is never locked. Everyone else is locked to their warehouseId.
  final ValueNotifier<bool> warehouseLocked = ValueNotifier<bool>(false);

  /// The warehouse the current user is locked to, or null if not locked.
  final ValueNotifier<int?> lockedWarehouseId = ValueNotifier<int?>(null);

  void setIndex(int index) {
    if (currentIndex.value != index) {
      _history.add(currentIndex.value);
      // Keep history reasonable
      if (_history.length > 10) _history.removeAt(0);
      currentIndex.value = index;
    }
  }

  bool popIndex() {
    if (_history.isNotEmpty) {
      currentIndex.value = _history.removeLast();
      return true;
    }
    return false;
  }

  /// Called right after login. Locks non-CEO users to their assigned warehouse.
  /// [roleTier] and [warehouseId] come from the UserData that just logged in.
  void applyUserWarehouseLock(int roleTier, int? warehouseId) {
    if (roleTier >= 5) {
      // CEO — no restrictions, clear any previous lock
      warehouseLocked.value = false;
      lockedWarehouseId.value = null;
    } else {
      warehouseLocked.value = true;
      lockedWarehouseId.value = warehouseId;
    }
  }

  /// Called on logout — removes all warehouse restrictions.
  void clearWarehouseLock() {
    warehouseLocked.value = false;
    lockedWarehouseId.value = null;
  }

  /// Manually update the warehouse lock (e.g. for CEO switching locations in POS)
  void setLockedWarehouse(int? id) {
    lockedWarehouseId.value = id;
  }
}

final navigationService = NavigationService();
