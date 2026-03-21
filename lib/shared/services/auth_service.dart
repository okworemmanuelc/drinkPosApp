import 'package:flutter/widgets.dart';
import 'package:drift/drift.dart';
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
    try {
      value = user;
      navigationService.applyUserWarehouseLock(user.roleTier, user.warehouseId);

      // Managers and above → Dashboard (index 0), everyone else → POS (index 1)
      if (user.roleTier >= 4) {
        navigationService.setIndex(0);
      } else {
        navigationService.setIndex(1);
      }

      // Check for warehouse assignment alerts for staff below CEO
      if (user.roleTier < 5 && user.warehouseId == null) {
        _handleOnboardingAlerts(user);
      }
    } catch (e) {
      debugPrint('[AuthService] CRITICAL ERROR in setCurrentUser: $e');
    }
  }

  /// Single entry point for all initialization/notification logic for new/unassigned staff.
  Future<void> _handleOnboardingAlerts(UserData user) async {
    try {
      final now = DateTime.now();
      UserData currentUser = user;

      // 1. Initialize createdAt if null
      if (currentUser.createdAt == null) {
        await (database.update(database.users)..where((u) => u.id.equals(currentUser.id)))
            .write(UsersCompanion(createdAt: Value(now)));
        // Refresh local state
        currentUser = await (database.select(database.users)..where((u) => u.id.equals(currentUser.id))).getSingle();
        value = currentUser;
      }

      final joinDate = currentUser.createdAt ?? now;
      final hoursSinceJoin = now.difference(joinDate).inHours;
      final deadline = joinDate.add(const Duration(hours: 48));
      final deadlineStr = '${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')} on ${deadline.day}/${deadline.month}';

      // 2. Initial notification to CEO
      if (currentUser.lastNotificationSentAt == null) {
        await database.notificationsDao.create(
          'warning',
          'Assignment Required: ${currentUser.name} has joined. Please assign a warehouse before the 48h deadline ($deadlineStr).',
          linkedRecordId: currentUser.id.toString(),
        );
        
        await (database.update(database.users)..where((u) => u.id.equals(currentUser.id)))
            .write(UsersCompanion(lastNotificationSentAt: Value(now)));
      }

      // 3. Escalation notification (if 48h passed)
      if (hoursSinceJoin >= 48) {
        final lastSent = currentUser.lastNotificationSentAt;
        if (lastSent != null && now.difference(lastSent).inHours >= 24) {
          await database.notificationsDao.create(
            'danger',
            'URGENT: 48h Countdown expired for ${currentUser.name} (Deadline: $deadlineStr). Warehouse assignment remains pending.',
            linkedRecordId: currentUser.id.toString(),
          );
          
          await (database.update(database.users)..where((u) => u.id.equals(currentUser.id)))
              .write(UsersCompanion(lastNotificationSentAt: Value(now)));
        }
      }

      // Refresh final state once after all updates (if any)
      final finalUser = await (database.select(database.users)..where((u) => u.id.equals(currentUser.id))).getSingle();
      if (finalUser != value) {
        value = finalUser;
      }
    } catch (e, stack) {
      debugPrint('[AuthService] Error in onboarding alerts: $e\n$stack');
    }
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
