import 'package:flutter/widgets.dart';
import '../../core/database/app_database.dart';
import 'navigation_service.dart';

/// Holds the currently logged-in user.
/// `value` is null when nobody is logged in.
class AuthService extends ValueNotifier<UserData?> {
  AuthService() : super(null); // no user on startup

  /// The currently logged-in user, or null if nobody is logged in.
  UserData? get currentUser => value;

  /// Returns every user in the database whose PIN matches [pin].
  /// There may be more than one match (e.g. two staff share a PIN),
  /// so we return a list and let the UI ask the user to pick one.
  Future<List<UserData>> getUsersByPin(String pin) async {
    final result = await (database.select(database.users)
          ..where((u) => u.pin.equals(pin)))
        .get();
    return result;
  }

  /// Marks [user] as the active logged-in user and applies warehouse lock.
  void setCurrentUser(UserData user) {
    value = user;
    navigationService.applyUserWarehouseLock(user.roleTier, user.warehouseId);
  }

  /// Clears the active user and removes the warehouse lock.
  void logout() {
    value = null;
    navigationService.clearWarehouseLock();
  }

  /// Returns true if [pin] belongs to at least one user whose
  /// `roleTier` is greater than or equal to [minimumTier].
  ///
  /// Used by the PIN confirmation dialog and by refund / crate-return
  /// features that need a manager or CEO to approve.
  ///
  /// Role tiers: 1 = Staff, 4 = Manager, 5 = CEO
  Future<bool> verifyPinForTier(String pin, int minimumTier) async {
    final matches = await getUsersByPin(pin);
    return matches.any((u) => u.roleTier >= minimumTier);
  }

  // ── Stubs kept for backward compatibility ───────────────────────────────
  Future<void> init() async {}
  Future<String?> signUpWithEmail({required String name, required String email, required String password}) async => null;
  Future<String?> signInWithEmail({required String email, required String password}) async => null;
  Future<bool> userExists(String email) async => false;
  Future<String?> signInWithGoogle({bool isSignUp = false}) async => null;
  Future<void> setPin(String pin) async {}
  Future<void> setBiometric(bool enabled) async {}
  Future<bool> hasQuickAccess() async => false;
  Future<UserData?> getQuickAccessUser() async => value;
  Future<void> enableQuickAccess() async {}
  Future<void> disableQuickAccess() async {}
  Future<bool> verifySupervisorPin(int userId, String pin) async => false;
}

final authService = AuthService();
