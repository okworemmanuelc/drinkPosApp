import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import '../../core/database/app_database.dart';
import 'package:drift/drift.dart';

/// Central auth service using Supabase for remote auth
/// and local Drift DB for offline PIN / biometric quick-access.
class AuthService extends ValueNotifier<UserData?> {
  AuthService() : super(null);

  UserData? get currentUser => value;
  DateTime? _sessionStartTime;
  DateTime? get sessionStartTime => _sessionStartTime;

  SupabaseClient get _client => Supabase.instance.client;

  // ─── Initialisation ──────────────────────────────────────
  Future<void> init() async {
    // Check for existing Supabase session
    final session = _client.auth.currentSession;
    if (session != null) {
      await _syncLocalUser();
    } else {
      // Fallback: check local session for quick-access
      final lastSession =
          await (database.select(database.sessions)
                ..orderBy([
                  (t) => OrderingTerm(
                    expression: t.timestamp,
                    mode: OrderingMode.desc,
                  ),
                ])
                ..limit(1))
              .getSingleOrNull();

      if (lastSession != null) {
        final user = await (database.select(
          database.users,
        )..where((t) => t.id.equals(lastSession.userId))).getSingleOrNull();
        if (user != null) {
          _sessionStartTime = lastSession.timestamp;
          value = user;
        }
      }
    }
  }

  // ─── Email / Password ────────────────────────────────────
  Future<String?> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      if (response.user != null) {
        await _upsertLocalUser(name: name, email: email, password: password);
        return null; // success
      }
      return 'Sign-up failed. Please try again.';
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        await _syncLocalUser();
        return null; // success
      }
      return 'Invalid credentials.';
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // ─── Google Sign-In ──────────────────────────────────────
  Future<bool> userExists(String email) async {
    final existing = await (database.select(database.users)
          ..where((t) => t.email.equals(email)))
        .getSingleOrNull();
    return existing != null;
  }

  Future<String?> signInWithGoogle({bool isSignUp = false}) async {
    try {
      const webClientId =
          '803041471830-vougj3r36gktrh95fofr024qif9n3a0e.apps.googleusercontent.com';

      final googleSignIn = GoogleSignIn(serverClientId: webClientId);

      // Always show the account chooser, even if already signed in.
      await googleSignIn.signOut();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return 'Google Sign-In cancelled.';

      // RESTRICTION: Check if user exists in our DB before proceeding (unless signing up)
      final exists = await userExists(googleUser.email);
      if (!exists && !isSignUp) {
        await googleSignIn.signOut();
        return 'USER_NOT_FOUND';
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) return 'Could not obtain Google tokens.';

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user != null) {
        await _upsertLocalUser(
          name: googleUser.displayName ?? googleUser.email.split('@').first,
          email: googleUser.email,
        );
        return null;
      }
      return 'Google Sign-In failed.';
    } catch (e) {
      return e.toString();
    }
  }

  // ─── PIN Quick-Access ────────────────────────────────────
  Future<bool> loginWithPin(String pin) async {
    final user = await (database.select(
      database.users,
    )..where((t) => t.pin.equals(pin))).getSingleOrNull();

    if (user != null) {
      await database
          .into(database.sessions)
          .insert(
            SessionsCompanion.insert(
              userId: user.id,
              timestamp: Value(DateTime.now()),
            ),
          );
      _sessionStartTime = DateTime.now();
      value = user;
      return true;
    }
    return false;
  }

  Future<void> setPin(String pin) async {
    if (value == null) return;
    await (database.update(database.users)
          ..where((t) => t.id.equals(value!.id)))
        .write(UsersCompanion(pin: Value(pin)));

    // Reload user
    final updated = await (database.select(
      database.users,
    )..where((t) => t.id.equals(value!.id))).getSingleOrNull();
    if (updated != null) value = updated;
  }

  Future<void> setBiometric(bool enabled) async {
    if (value == null) return;
    await (database.update(database.users)
          ..where((t) => t.id.equals(value!.id)))
        .write(UsersCompanion(biometricEnabled: Value(enabled)));

    final updated = await (database.select(
      database.users,
    )..where((t) => t.id.equals(value!.id))).getSingleOrNull();
    if (updated != null) value = updated;
  }

  // ─── Quick-Access check ──────────────────────────────────
  /// Returns `true` if the current device already has a logged-in user
  /// with a PIN set, meaning we can show the quick-access screen.
  Future<bool> hasQuickAccess() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('quick_access_user_id');
    if (userId == null) return false;

    final user = await (database.select(
      database.users,
    )..where((t) => t.id.equals(userId))).getSingleOrNull();
    return user != null && user.pin.isNotEmpty;
  }

  Future<UserData?> getQuickAccessUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('quick_access_user_id');
    if (userId == null) return null;
    return (database.select(
      database.users,
    )..where((t) => t.id.equals(userId))).getSingleOrNull();
  }

  Future<void> enableQuickAccess() async {
    if (value == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quick_access_user_id', value!.id);
  }

  Future<void> disableQuickAccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('quick_access_user_id');
  }

  // ─── Logout ──────────────────────────────────────────────
  Future<void> logout({bool clearQuickAccess = false}) async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
    await database.delete(database.sessions).go();
    _sessionStartTime = null;
    if (clearQuickAccess) await disableQuickAccess();
    value = null;
  }

  // ─── Supervisor ──────────────────────────────────────────
  Future<bool> verifySupervisorPin(int userId, String pin) async {
    final user =
        await (database.select(database.users)..where(
              (t) =>
                  t.id.equals(userId) &
                  t.pin.equals(pin) &
                  t.roleTier.isBiggerOrEqualValue(4),
            ))
            .getSingleOrNull();
    return user != null;
  }

  // ─── Helpers ─────────────────────────────────────────────
  Future<void> _syncLocalUser() async {
    final supaUser = _client.auth.currentUser;
    if (supaUser == null) return;

    final email = supaUser.email ?? '';
    final name = supaUser.userMetadata?['name'] ?? email.split('@').first;

    await _upsertLocalUser(name: name, email: email);
  }

  Future<void> _upsertLocalUser({
    required String name,
    required String email,
    String? password,
  }) async {
    // Check if the user already exists
    final existing = await (database.select(
      database.users,
    )..where((t) => t.email.equals(email))).getSingleOrNull();

    int userId;
    if (existing != null) {
      userId = existing.id;
    } else {
      // Create new local user
      final hash = password != null
          ? sha256.convert(utf8.encode(password)).toString()
          : null;

      userId = await database
          .into(database.users)
          .insert(
            UsersCompanion.insert(
              name: name,
              pin: '', // will be set during PIN setup
              role: 'staff',
              email: Value(email),
              passwordHash: Value(hash),
            ),
          );
    }

    // Create session
    await database
        .into(database.sessions)
        .insert(
          SessionsCompanion.insert(
            userId: userId,
            timestamp: Value(DateTime.now()),
          ),
        );
    _sessionStartTime = DateTime.now();

    final user = await (database.select(
      database.users,
    )..where((t) => t.id.equals(userId))).getSingleOrNull();
    value = user;

    // Enable quick access
    await enableQuickAccess();
  }
}

final authService = AuthService();
