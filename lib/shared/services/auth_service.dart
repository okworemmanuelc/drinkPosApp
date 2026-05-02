import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:drift/drift.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:math';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/database/uuid_v7.dart';
import 'package:reebaplus_pos/shared/services/navigation_service.dart';
import 'package:reebaplus_pos/shared/services/secure_storage_service.dart';
import 'package:reebaplus_pos/core/services/supabase_sync_service.dart';
import 'package:reebaplus_pos/shared/services/pin_hasher.dart';

/// Route to show after login instead of the default MainLayout.
enum PostLoginRoute { none, successDashboard, accessGranted }

/// Holds the currently logged-in user.
/// `value` is null when nobody is logged in.
class AuthService extends ValueNotifier<UserData?> {
  final AppDatabase _db;
  final NavigationService _nav;
  final SecureStorageService _secure;
  final SupabaseSyncService _sync;

  AuthService(this._db, this._nav, this._secure, this._sync) : super(null) {
    // Hand the database a thin closure over `value` so DAOs that mix in
    // BusinessScopedDao always read the current session's businessId
    // (auto-tracks login/logout through the ValueNotifier).
    _db.businessIdResolver = () => value?.businessId;
  }

  /// Notifies listeners whenever the device-level user ID changes.
  final ValueNotifier<String?> deviceUserIdNotifier = ValueNotifier<String?>(null);

  /// Id of the active row in `Sessions` for the currently logged-in user.
  /// Set by [setCurrentUser] and cleared on logout.
  String? currentSessionId;

  /// Set before calling [setCurrentUser] to route to a special post-login screen.
  PostLoginRoute pendingPostLoginRoute = PostLoginRoute.none;
  UserData? pendingPostLoginUser;

  /// The currently logged-in user, or null if nobody is logged in.
  UserData? get currentUser => value;

  /// Returns every user whose stored PBKDF2 hash matches [pin]. Sentinel /
  /// placeholder rows (no hash yet) never match — they must go through
  /// [setUserPin] first.
  Future<List<UserData>> getUsersByPin(String pin, {String? email}) async {
    final query = _db.select(_db.users);
    if (email != null && email.isNotEmpty) {
      query.where((u) => u.email.equals(email));
    }
    final candidates = await query.get();
    return candidates.where((u) {
      final hash = u.pinHash;
      final salt = u.pinSalt;
      final iterations = u.pinIterations;
      if (hash == null || salt == null || iterations == null) {
        return false;
      }
      final computed = PinHasher.hashBase64(pin, salt, iterations);
      return PinHasher.constantTimeEquals(hash, computed);
    }).toList();
  }

  /// Hashes [plaintext] with a fresh per-user salt and stores the resulting
  /// pinHash/pinSalt/pinIterations triple. Overwrites the legacy [Users.pin]
  /// column with the literal `'__HASHED__'` so the row no longer carries the
  /// PIN in cleartext. Single canonical PIN write path.
  Future<void> setUserPin(String userId, String plaintext) async {
    final salt = PinHasher.generateSaltBase64();
    final hash = PinHasher.hashBase64(
      plaintext,
      salt,
      PinHasher.defaultIterations,
    );
    await (_db.update(_db.users)..where((u) => u.id.equals(userId))).write(
      UsersCompanion(
        pin: const Value('__HASHED__'),
        pinHash: Value(hash),
        pinSalt: Value(salt),
        pinIterations: const Value(PinHasher.defaultIterations),
      ),
    );
  }

  // ── Device persistence (encrypted) ──────────────────────────────────────

  /// Returns the locally-persisted user ID, or null if no user has ever
  /// logged in on this device.
  Future<String?> getDeviceUserId() => _secure.getDeviceUserId();

  /// Returns the last successfully logged-in email.
  Future<String?> getLastLoggedInEmail() => _secure.getLastLoggedInEmail();

  /// Persists [userId] so the next app launch goes straight to PIN screen.
  Future<void> saveDeviceUserId(String userId) async {
    await _secure.saveDeviceUserId(userId);
    deviceUserIdNotifier.value = userId;
  }

  /// Persists [email] as the last logged-in user.
  Future<void> saveLastLoggedInEmail(String email) =>
      _secure.saveLastLoggedInEmail(email);

  /// Clears the persisted device session (call on explicit logout).
  Future<void> clearDeviceUserId() async {
    await _secure.clearDeviceUserId();
    deviceUserIdNotifier.value = null;
  }

  // ── Auth method tracking ────────────────────────────────────────────────

  /// Saves the authentication method ("google" or "email") for this session.
  Future<void> saveAuthMethod(String method) => _secure.saveAuthMethod(method);

  /// Returns the stored auth method, or null if not set.
  Future<String?> getAuthMethod() => _secure.getAuthMethod();

  // ── Supabase Sync ─────────────────────────────────────────────────────────

  /// Sentinel PIN written to a local user row when it's been seeded from a
  /// cloud profile but the device hasn't set up a PIN yet. The OTP flow
  /// detects this and routes the user into PIN setup.
  static const String setupRequiredPin = '__SETUP_REQUIRED__';

  /// Reads the current auth user's cloud profile and the linked business
  /// metadata. Returns null when no profile / business exists, when no user
  /// is signed in, or on network error.
  Future<SupabaseAccountInfo?> fetchSupabaseAccount() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return null;
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('business_id, role, role_tier')
          .eq('id', authUser.id)
          .maybeSingle();
      final businessId = profile?['business_id'] as String?;
      if (profile == null || businessId == null) return null;

      final business = await Supabase.instance.client
          .from('businesses')
          .select('name')
          .eq('id', businessId)
          .maybeSingle();
      final businessName = business?['name'] as String?;
      if (businessName == null) return null;

      return SupabaseAccountInfo(
        businessId: businessId,
        businessName: businessName,
        role: profile['role'] as String? ?? 'Staff',
        roleTier: (profile['role_tier'] as num?)?.toInt() ?? 1,
      );
    } catch (e) {
      debugPrint('[AuthService] fetchSupabaseAccount error: $e');
      return null;
    }
  }

  Future<void> syncOnLogin(String businessId) async {
    await _sync.syncAll(businessId);
    _sync.startRealtimeSync(businessId);
    _sync.startAutoPush();
  }

  /// Reads the current user's cloud profile (by `auth.uid()`) and reflects it
  /// into the local `users` table. On a fresh device this recreates the row
  /// so the existing PIN-entry / device-session flow can pick up.
  ///
  /// Only profile-owned fields (name, role, roleTier, businessId) are written.
  /// Device-local fields (pin, passwordHash, biometricEnabled, avatarColor,
  /// warehouseId) are never overwritten on existing rows.
  ///
  /// If no local row exists yet, one is inserted with [setupRequiredPin] as a
  /// placeholder so the caller can route to PIN setup.
  Future<UserData?> upsertLocalUserFromProfile() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null || authUser.email == null) return null;

    Map<String, dynamic>? profile;
    try {
      profile = await Supabase.instance.client
          .from('profiles')
          .select('name, role, role_tier, business_id')
          .eq('id', authUser.id)
          .maybeSingle();
    } catch (e) {
      debugPrint('[AuthService] upsertLocalUserFromProfile fetch error: $e');
      return null;
    }
    if (profile == null) return null;

    final name = profile['name'] as String? ?? '';
    final role = profile['role'] as String? ?? 'Staff';
    final roleTier = (profile['role_tier'] as num?)?.toInt() ?? 1;
    final businessId = profile['business_id'] as String?;
    final email = authUser.email!;

    if (businessId == null) return null;
    final existing = await getUserByEmail(email);
    if (existing != null) {
      await (_db.update(_db.users)..where((u) => u.id.equals(existing.id)))
          .write(UsersCompanion(
        name: Value(name),
        role: Value(role),
        roleTier: Value(roleTier),
        businessId: Value(businessId),
      ));
      return (_db.select(_db.users)..where((u) => u.id.equals(existing.id)))
          .getSingle();
    }

    return _db.into(_db.users).insertReturning(
          UsersCompanion.insert(
            name: name,
            email: Value(email),
            pin: setupRequiredPin,
            role: role,
            roleTier: Value(roleTier),
            businessId: businessId,
          ),
        );
  }

  // ── Supabase OTP ───────────────────────────────────────────────────────────

  /// Sends a one-time password to [email] via Supabase.
  /// Returns null on success, or an error string on failure.
  Future<String?> sendOtp(String email) async {
    debugPrint('[AuthService] Attempting to send OTP to $email...');
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );
      debugPrint('[AuthService] OTP send command success.');
      return null;
    } on AuthException catch (e) {
      debugPrint('[AuthService] Supabase AuthException: ${e.message}');
      return e.message;
    } catch (e) {
      debugPrint('[AuthService] OTP send generic error: $e');
      if (e.toString().toLowerCase().contains('socketexception') ||
          e.toString().toLowerCase().contains('failed host lookup') ||
          e.toString().toLowerCase().contains('clientexception')) {
        return 'No Internet Connection. Reebaplus POS requires an active connection.';
      }
      return 'Failed to send OTP. Please try again.';
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
    } catch (e) {
      if (e.toString().toLowerCase().contains('socketexception') ||
          e.toString().toLowerCase().contains('failed host lookup') ||
          e.toString().toLowerCase().contains('clientexception')) {
        return 'No Internet Connection. Reebaplus POS requires an active connection.';
      }
      return 'Verification failed. Please try again.';
    }
  }

  /// Looks up a user in the local database by email.
  Future<UserData?> getUserByEmail(String email) {
    debugPrint('[AuthService] Querying local user for $email...');
    return _db.warehousesDao.getUserByEmail(email).then((u) {
      debugPrint('[AuthService] Query done for $email. Found: ${u != null}');
      return u;
    });
  }

  // ── Session management ─────────────────────────────────────────────────────

  /// Marks [user] as the active logged-in user and applies warehouse lock.
  void setCurrentUser(UserData user) {
    try {
      // Side-effects first — navigationService fully ready before any rebuild
      _nav.applyUserWarehouseLock(user.roleTier, user.warehouseId);
      if (user.roleTier >= 4) {
        _nav.setIndex(0);
      } else {
        _nav.setIndex(1);
      }
      saveDeviceUserId(user.id);
      if (user.email != null) saveLastLoggedInEmail(user.email!);

      // Set synchronously so VLB listener fires before any route pop cleans up
      value = user;

      _sync.startRealtimeSync(user.businessId);
      _sync.startAutoPush();

      if (user.roleTier < 5 && user.warehouseId == null) {
        scheduleMicrotask(() => _handleOnboardingAlerts(user));
      }

      // Record a session row for this login. Fire-and-forget — local DB write
      // shouldn't block the post-login UI; failures are logged.
      scheduleMicrotask(() async {
        try {
          currentSessionId = await _db.sessionsDao.createSession(
            userId: user.id,
            ttl: const Duration(days: 30),
          );
        } catch (e) {
          debugPrint('[AuthService] createSession error: $e');
        }
      });
    } catch (e, stack) {
      debugPrint('[AuthService] CRITICAL ERROR in setCurrentUser: $e\n$stack');
    }
  }

  /// Single entry point for all initialization/notification logic for new/unassigned staff.
  Future<void> _handleOnboardingAlerts(UserData user) async {
    try {
      final now = DateTime.now();
      UserData currentUser = user;



      final joinDate = currentUser.createdAt;
      final hoursSinceJoin = now.difference(joinDate).inHours;
      final deadline = joinDate.add(const Duration(hours: 48));
      final deadlineStr =
          '${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')} on ${deadline.day}/${deadline.month}';

      // 2. Initial notification to CEO
      if (currentUser.lastNotificationSentAt == null) {
        await _db.notificationsDao.create(
          'warning',
          'Assignment Required: ${currentUser.name} has joined. Please assign a warehouse before the 48h deadline ($deadlineStr).',
          linkedRecordId: currentUser.id.toString(),
        );

        await (_db.update(_db.users)..where((u) => u.id.equals(currentUser.id)))
            .write(UsersCompanion(lastNotificationSentAt: Value(now)));
      }

      // 3. Escalation notification (if 48h passed)
      if (hoursSinceJoin >= 48) {
        final lastSent = currentUser.lastNotificationSentAt;
        if (lastSent != null && now.difference(lastSent).inHours >= 24) {
          await _db.notificationsDao.create(
            'danger',
            'URGENT: 48h Countdown expired for ${currentUser.name} (Deadline: $deadlineStr). Warehouse assignment remains pending.',
            linkedRecordId: currentUser.id.toString(),
          );

          await (_db.update(_db.users)
                ..where((u) => u.id.equals(currentUser.id)))
              .write(UsersCompanion(lastNotificationSentAt: Value(now)));
        }
      }

      // Refresh final state once after all updates (if any)
      final finalUser = await (_db.select(
        _db.users,
      )..where((u) => u.id.equals(currentUser.id))).getSingle();
      if (finalUser != value) {
        value = finalUser;
      }
    } catch (e, stack) {
      debugPrint('[AuthService] Error in onboarding alerts: $e\n$stack');
    }
  }

  /// If true, the LoginScreen will skip automatically prompting for Biometrics
  /// so that users who explicitly pressed "Log Out" aren't immediately logged back in.
  bool bypassNextBiometric = false;

  /// Clears the active user, removes the warehouse lock, but retains the
  /// device-level session so the next launch shows the personalized PIN screen.
  void logout() {
    final sid = currentSessionId;
    if (sid != null) {
      scheduleMicrotask(() async {
        try {
          await _db.sessionsDao.revokeSession(sid);
        } catch (e) {
          debugPrint('[AuthService] revokeSession error: $e');
        }
      });
      currentSessionId = null;
    }
    value = null;
    bypassNextBiometric = true;
    _nav.clearWarehouseLock();
    _nav.resetNavigation();
  }

  /// Completely wipes the session, reverting the device to a fresh state.
  /// Next launch will demand Email + OTP.
  Future<void> fullLogout() async {
    // 1. Wipe all encrypted auth data so the notifier fires and _hasDeviceUser
    //    becomes false before the ValueListenableBuilder rebuilds.
    await _secure.clearAll();
    deviceUserIdNotifier.value = null;

    // 2. Terminate all sessions globally via Supabase (fire-and-forget —
    //    network failures should not prevent local logout).
    Supabase.instance.client.auth
        .signOut(scope: SignOutScope.global)
        .catchError(
          (e) => debugPrint('[AuthService] Supabase signOut error: $e'),
        );

    // 3. Sign out of Google if applicable (fire-and-forget).
    try {
      await GoogleSignIn().signOut();
    } catch (e) {
      debugPrint('[AuthService] Google signOut error: $e');
    }

    // 4. Clear local state — triggers the ValueListenableBuilder to rebuild.
    //    At this point _hasDeviceUser is already false → routes to EmailEntryScreen.
    value = null;
    _nav.clearWarehouseLock();
    _nav.resetNavigation();
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
  /// If an account with this email already exists (e.g. user went back and
  /// re-submitted the name screen), updates the name and returns the existing record.
  Future<UserData> createNewOwner(String email, String name) async {
    final existing = await getUserByEmail(email);
    if (existing != null) {
      await (_db.update(_db.users)..where((u) => u.id.equals(existing.id)))
          .write(UsersCompanion(
        name: Value(name),
        lastUpdatedAt: Value(DateTime.now()),
      ));
      return (_db.select(_db.users)..where((u) => u.id.equals(existing.id)))
          .getSingle();
    }

    // Users.businessId is NOT NULL, so seed a Businesses row first using the
    // owner's name as a placeholder. BusinessDetailsScreen overwrites it with
    // the real business name in the next step of onboarding.
    final businessId = UuidV7.generate();
    final userId = UuidV7.generate();
    await _db.transaction(() async {
      await _db.into(_db.businesses).insert(BusinessesCompanion.insert(
            id: Value(businessId),
            name: name,
          ));
      await _db.into(_db.users).insert(UsersCompanion.insert(
            id: Value(userId),
            businessId: businessId,
            name: name,
            email: Value(email),
            pin: setupRequiredPin,
            role: 'ceo',
            roleTier: const Value(5),
          ));
    });
    return (_db.select(_db.users)..where((u) => u.id.equals(userId)))
        .getSingle();
  }

  // ── Initialisation ──────────────────────────────────────────────────────
  Future<void> init() async {}

  // ── Google Sign-In (via Supabase OAuth) ──────────────────────────────────

  /// Authenticates with Google via Supabase OAuth redirect flow.
  /// Opens a browser for Google login, then redirects back to the app.
  /// Returns the user's email on success, or null if cancelled / failed.
  Future<String?> signInWithGoogle() async {
    try {
      final supabase = Supabase.instance.client;

      // Start the OAuth flow — opens the browser.
      final success = await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'reebaplus://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

      if (!success) {
        debugPrint('[AuthService] Google OAuth launch failed');
        return null;
      }

      // Wait for the auth state to change (user redirected back).
      final completer = Completer<String?>();
      late final StreamSubscription<AuthState> sub;

      sub = supabase.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.signedIn) {
          final email = data.session?.user.email;
          sub.cancel();
          completer.complete(email?.toLowerCase());
        }
      });

      // Timeout after 2 minutes if the user doesn't complete the flow.
      final email = await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          sub.cancel();
          return null;
        },
      );

      if (email != null) {
        debugPrint('[AuthService] Google + Supabase sign-in success: $email');
      }
      return email;
    } catch (e) {
      debugPrint('[AuthService] Google Sign-In error: $e');
      return null;
    }
  }

  // ── Stubs kept for backward compatibility ───────────────────────────────
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
  Future<void> setPin(String pin) async {}
  Future<void> setBiometric(bool enabled) async {}
  Future<bool> hasQuickAccess() async => false;
  Future<UserData?> getQuickAccessUser() async => value;
  Future<void> enableQuickAccess() async {}
  Future<void> disableQuickAccess() async {}
  Future<bool> verifySupervisorPin(String userId, String pin) async => false;

  // ── Invite lifecycle ───────────────────────────────────────────────────────

  /// Generates a secure 8-character invite code (no confusing characters).
  String _generateSecureCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No 0, O, I, 1
    final rnd = Random.secure();
    return List.generate(8, (index) => chars[rnd.nextInt(chars.length)]).join();
  }

  /// Creates a new invite and returns the generated sharing link.
  Future<String> createInvite({
    required String email,
    required String inviteeName,
    required String role,
    String? warehouseId,
  }) async {
    final businessId = value?.businessId;
    final createdBy = value?.id;
    if (businessId == null || createdBy == null) {
      throw StateError('Cannot create invite: no active session');
    }

    final code = _generateSecureCode();
    final expiresAt = DateTime.now().add(const Duration(hours: 48));

    await _db.into(_db.invites).insert(
          InvitesCompanion.insert(
            businessId: businessId,
            email: email,
            inviteeName: inviteeName,
            role: role,
            warehouseId: Value(warehouseId),
            code: code,
            status: const Value('pending'),
            expiresAt: expiresAt,
            createdBy: createdBy,
            createdAt: Value(DateTime.now()),
            lastUpdatedAt: Value(DateTime.now()),
          ),
        );

    return 'https://reebaplus.pos/join?code=$code';
  }

  /// Validates an invite code and returns the details.
  Future<InviteValidationResult> validateInvite(String code) async {
    final normalized = code.trim().toUpperCase();
    final invite = await (_db.select(
      _db.invites,
    )..where((t) => t.code.equals(normalized))).getSingleOrNull();

    if (invite == null) {
      return InviteValidationResult.error('Invalid invite code.');
    }
    if (invite.status == 'revoked') {
      return InviteValidationResult.error(
        'This invite has been cancelled by your manager.',
      );
    }
    if (invite.status == 'accepted') {
      return InviteValidationResult.error('This invite has already been used.');
    }

    final now = DateTime.now();
    if (invite.expiresAt.isBefore(now)) {
      await (_db.update(_db.invites)..where((t) => t.id.equals(invite.id)))
          .write(const InvitesCompanion(status: Value('expired')));
      return InviteValidationResult.error(
        'This invite has expired. Ask your manager for a new one.',
      );
    }

    final biz = await (_db.select(
      _db.businesses,
    )..where((t) => t.id.equals(invite.businessId))).getSingle();

    final inviter = await (_db.select(
      _db.users,
    )..where((t) => t.id.equals(invite.createdBy))).getSingleOrNull();

    return InviteValidationResult.success(
      invite: invite,
      businessName: biz.name,
      inviterName: inviter?.name ?? 'your manager',
    );
  }

  /// Completes the join process for a user.
  Future<void> redeemInvite(String code, String userId) async {
    final normalized = code.trim().toUpperCase();
    final invite = await (_db.select(
      _db.invites,
    )..where((t) => t.code.equals(normalized))).getSingleOrNull();

    if (invite == null) throw Exception('Invite not found');

    await _db.transaction(() async {
      // 1. Update invite status
      await (_db.update(
        _db.invites,
      )..where((t) => t.id.equals(invite.id))).write(
        InvitesCompanion(
          status: const Value('accepted'),
          usedAt: Value(DateTime.now()),
        ),
      );

      // 2. Assign role and business to user
      // We need to map the role string to a tier.
      int tier = 1; // Default staff
      if (invite.role.toLowerCase().contains('manager')) tier = 4;
      if (invite.role.toLowerCase().contains('ceo')) tier = 5;

      await (_db.update(_db.users)..where((t) => t.id.equals(userId))).write(
        UsersCompanion(
          role: Value(invite.role),
          roleTier: Value(tier),
          businessId: Value(invite.businessId),
          warehouseId: Value(invite.warehouseId),
        ),
      );
    });
  }

  /// Cancels an invite.
  Future<void> revokeInvite(String inviteId) async {
    await (_db.update(_db.invites)..where((t) => t.id.equals(inviteId))).write(
      const InvitesCompanion(status: Value('revoked')),
    );
  }

  /// Re-issues an invite with a new code and expiry.
  Future<String> resendInvite(String inviteId) async {
    final code = _generateSecureCode();
    final expiresAt = DateTime.now().add(const Duration(hours: 48));

    await (_db.update(_db.invites)..where((t) => t.id.equals(inviteId))).write(
      InvitesCompanion(
        code: Value(code),
        status: const Value('pending'),
        expiresAt: Value(expiresAt),
      ),
    );

    return 'https://reebaplus.pos/join?code=$code';
  }
}

class InviteValidationResult {
  final InviteData? invite;
  final String? businessName;
  final String? inviterName;
  final String? error;

  InviteValidationResult.success({
    required this.invite,
    required this.businessName,
    required this.inviterName,
  }) : error = null;

  InviteValidationResult.error(this.error)
    : invite = null,
      businessName = null,
      inviterName = null;

  bool get isSuccess => error == null;
}

/// Snapshot of the current auth user's cloud profile + linked business,
/// used by the OTP flow to confirm an existing account on a fresh device.
class SupabaseAccountInfo {
  final String businessId;
  final String businessName;
  final String role;
  final int roleTier;

  const SupabaseAccountInfo({
    required this.businessId,
    required this.businessName,
    required this.role,
    required this.roleTier,
  });
}
