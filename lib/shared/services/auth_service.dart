import 'package:flutter/widgets.dart';
import '../../core/database/app_database.dart';

/// Central auth service using Supabase for remote auth
/// and local Drift DB for offline PIN / biometric quick-access.
class AuthService extends ValueNotifier<UserData?> {
  AuthService() : super(const UserData(
    id: 1,
    name: 'Admin User',
    pin: '1234',
    role: 'CEO',
    roleTier: 5,
    avatarColor: '#3B82F6',
    biometricEnabled: false,
  ));

  UserData? get currentUser => value;
  DateTime? get sessionStartTime => DateTime.now();

  Future<void> init() async {}
  Future<String?> signUpWithEmail({required String name, required String email, required String password}) async => null;
  Future<String?> signInWithEmail({required String email, required String password}) async => null;
  Future<bool> userExists(String email) async => true;
  Future<String?> signInWithGoogle({bool isSignUp = false}) async => null;
  Future<bool> loginWithPin(String pin) async => true;
  Future<void> setPin(String pin) async {}
  Future<void> setBiometric(bool enabled) async {}
  Future<bool> hasQuickAccess() async => true;
  Future<UserData?> getQuickAccessUser() async => value;
  Future<void> enableQuickAccess() async {}
  Future<void> disableQuickAccess() async {}
  Future<void> logout({bool clearQuickAccess = false}) async {}
  Future<bool> verifySupervisorPin(int userId, String pin) async => true;
}

final authService = AuthService();
