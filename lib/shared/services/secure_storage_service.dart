import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // ── Device User ID ──────────────────────────────────────────────────────
  Future<int?> getDeviceUserId() async {
    final raw = await _storage.read(key: _deviceUserIdKey);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> saveDeviceUserId(int userId) async {
    await _storage.write(key: _deviceUserIdKey, value: userId.toString());
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
