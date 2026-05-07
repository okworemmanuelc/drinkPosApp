import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reebaplus_pos/core/database/uuid_v7.dart';

/// Encrypted key-value store for sensitive auth data.
///
/// Uses Android EncryptedSharedPreferences and iOS Keychain under the hood.
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ── Keys ────────────────────────────────────────────────────────────────
  static const _deviceUserIdKey = 'secure_device_user_id';
  static const _lastEmailKey = 'secure_last_logged_in_email';
  static const _authMethodKey = 'secure_auth_method'; // "google" | "email"

  // Device ID lives in plain SharedPreferences so it survives fullLogout's
  // _storage.deleteAll(). It's an opaque random UUID, not a credential.
  static const _deviceIdKey = 'device_id';
  String? _cachedDeviceId;

  // ── Device User ID ──────────────────────────────────────────────────────
  Future<String?> getDeviceUserId() async {
    return _storage.read(key: _deviceUserIdKey);
  }

  Future<void> saveDeviceUserId(String userId) async {
    await _storage.write(key: _deviceUserIdKey, value: userId);
  }

  Future<void> clearDeviceUserId() async {
    await _storage.delete(key: _deviceUserIdKey);
  }

  // ── Last Logged-In Email ────────────────────────────────────────────────
  Future<String?> getLastLoggedInEmail() async {
    return _storage.read(key: _lastEmailKey);
  }

  Future<void> saveLastLoggedInEmail(String email) async {
    await _storage.write(key: _lastEmailKey, value: email);
  }

  // ── Device ID ───────────────────────────────────────────────────────────
  /// Returns this physical device's stable ID, generating one on first call.
  /// Persists across fullLogout (via SharedPreferences, not the secure store)
  /// so the same device is recognised on next login.
  Future<String> getOrCreateDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null) {
      id = UuidV7.generate();
      await prefs.setString(_deviceIdKey, id);
    }
    _cachedDeviceId = id;
    return id;
  }

  // ── Auth Method (google | email) ────────────────────────────────────────
  Future<String?> getAuthMethod() async {
    return _storage.read(key: _authMethodKey);
  }

  Future<void> saveAuthMethod(String method) async {
    await _storage.write(key: _authMethodKey, value: method);
  }

  // ── Clear All ────────────────────────────────────���──────────────────────
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // ── One-time migration from SharedPreferences ──────────────────────────

  static const _legacyDeviceUserKey = 'device_user_id';
  static const _legacyLastEmailKey = 'last_logged_in_email';

  /// Moves legacy plaintext auth data to encrypted storage. Safe to call
  /// multiple times — only migrates keys that still exist in SharedPreferences.
  static Future<void> migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final legacyId = prefs.getInt(_legacyDeviceUserKey);
      if (legacyId != null) {
        final existing = await _storage.read(key: _deviceUserIdKey);
        if (existing == null) {
          await _storage.write(
            key: _deviceUserIdKey,
            value: legacyId.toString(),
          );
        }
        await prefs.remove(_legacyDeviceUserKey);
      }

      final legacyEmail = prefs.getString(_legacyLastEmailKey);
      if (legacyEmail != null) {
        final existing = await _storage.read(key: _lastEmailKey);
        if (existing == null) {
          await _storage.write(key: _lastEmailKey, value: legacyEmail);
        }
        await prefs.remove(_legacyLastEmailKey);
      }

      // Default auth method to "email" for migrated users
      if (legacyId != null || legacyEmail != null) {
        final method = await _storage.read(key: _authMethodKey);
        if (method == null) {
          await _storage.write(key: _authMethodKey, value: 'email');
        }
      }
    } catch (e) {
      debugPrint('[SecureStorage] Migration error (non-fatal): $e');
    }
  }
}
