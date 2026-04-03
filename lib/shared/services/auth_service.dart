import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/shared/services/navigation_service.dart';

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
    final result = await (database.select(
      database.users,
    )..where((u) => u.pin.equals(pin))).get();
    return result;
  }

  // ── Device persistence ─────────────────────────────────────────────────────

  static const _deviceUserKey = 'device_user_id';

  /// Returns the locally-persisted user ID, or null if no user has ever
  /// logged in on this device.
  Future<int?> getDeviceUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_deviceUserKey);
  }

  /// Persists [userId] so the next app launch goes straight to PIN screen.
  Future<void> saveDeviceUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_deviceUserKey, userId);
  }

  /// Clears the persisted device session (call on explicit logout).
  Future<void> clearDeviceUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceUserKey);
  }

  // ── Supabase OTP ───────────────────────────────────────────────────────────

  /// Sends a one-time password to [email] via Supabase.
  /// Returns null on success, or an error string on failure.
  Future<String?> sendOtp(String email) async {
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Failed to send OTP. Check your connection.';
    }
  }

  /// Verifies the [otp] code for [email].
  /// Returns null on success, or an error string on failure.
  Future<String?> verifyOtp(String email, String otp) async {
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.email,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Verification failed. Please try again.';
    }
  }

  /// Looks up a user in the local database by email.
  Future<UserData?> getUserByEmail(String email) =>
      database.warehousesDao.getUserByEmail(email);

  // ── Session management ─────────────────────────────────────────────────────

  /// Marks [user] as the active logged-in user and applies warehouse lock.
  void setCurrentUser(UserData user) {
    try {
      // Side-effects first — navigationService fully ready before any rebuild
      navigationService.applyUserWarehouseLock(user.roleTier, user.warehouseId);
      if (user.roleTier >= 4) {
        navigationService.setIndex(0);
      } else {
        navigationService.setIndex(1);
      }
      saveDeviceUserId(user.id);

      // Notify listeners after call stack unwinds — safe on cold start
      scheduleMicrotask(() {
        value = user;
      });

      if (user.roleTier < 5 && user.warehouseId == null) {
        scheduleMicrotask(() => _handleOnboardingAlerts(user));
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
        await (database.update(database.users)
              ..where((u) => u.id.equals(currentUser.id)))
            .write(UsersCompanion(createdAt: Value(now)));
        // Refresh local state
        currentUser = await (database.select(
          database.users,
        )..where((u) => u.id.equals(currentUser.id))).getSingle();
        value = currentUser;
      }

      final joinDate = currentUser.createdAt ?? now;
      final hoursSinceJoin = now.difference(joinDate).inHours;
      final deadline = joinDate.add(const Duration(hours: 48));
      final deadlineStr =
          '${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')} on ${deadline.day}/${deadline.month}';

      // 2. Initial notification to CEO
      if (currentUser.lastNotificationSentAt == null) {
        await database.notificationsDao.create(
          'warning',
          'Assignment Required: ${currentUser.name} has joined. Please assign a warehouse before the 48h deadline ($deadlineStr).',
          linkedRecordId: currentUser.id.toString(),
        );

        await (database.update(database.users)
              ..where((u) => u.id.equals(currentUser.id)))
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

          await (database.update(database.users)
                ..where((u) => u.id.equals(currentUser.id)))
              .write(UsersCompanion(lastNotificationSentAt: Value(now)));
        }
      }

      // Refresh final state once after all updates (if any)
      final finalUser = await (database.select(
        database.users,
      )..where((u) => u.id.equals(currentUser.id))).getSingle();
      if (finalUser != value) {
        value = finalUser;
      }
    } catch (e, stack) {
      debugPrint('[AuthService] Error in onboarding alerts: $e\n$stack');
    }
  }

  /// Clears the active user, removes the warehouse lock, and erases the
  /// device-level session so the next launch shows the email screen.
  void logout() {
    value = null;
    navigationService.clearWarehouseLock();
    clearDeviceUserId(); // fire-and-forget
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

  /// Creates a new owner (CEO) account in the local database after OTP verification.
  /// Returns the newly created [UserData] record.
  Future<UserData> createNewOwner(String email, String name) async {
    final id = await database
        .into(database.users)
        .insert(
          UsersCompanion(
            name: Value(name),
            email: Value(email),
            pin: const Value(''),
            role: const Value('CEO'),
            roleTier: const Value(5),
            avatarColor: const Value('#8B5CF6'),
          ),
        );
    return (database.select(
      database.users,
    )..where((u) => u.id.equals(id))).getSingle();
  }

  // ── Stubs kept for backward compatibility ───────────────────────────────
  Future<void> init() async {}
  Future<String?> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async => null;
  Future<String?> signInWithEmail({
    required String email,
    required String password,
  }) async => null;
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
