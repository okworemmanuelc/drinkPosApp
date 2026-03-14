import 'package:flutter/widgets.dart';
import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';

class AuthService extends ValueNotifier<UserData?> {
  AuthService() : super(null);

  UserData? get currentUser => value;
  DateTime? _sessionStartTime;
  DateTime? get sessionStartTime => _sessionStartTime;

  Future<void> init() async {
    // Check for existing session
    final lastSession = await (database.select(database.sessions)
          ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();

    if (lastSession != null) {
      final user = await (database.select(database.users)
            ..where((t) => t.id.equals(lastSession.userId)))
        .getSingleOrNull();

      if (user != null) {
        _sessionStartTime = lastSession.timestamp;
        value = user;
      }
    }
  }

  Future<bool> loginWithPin(String pin) async {
    final user = await (database.select(database.users)
          ..where((t) => t.pin.equals(pin)))
        .getSingleOrNull();

    if (user != null) {
      // Create session
      await database.into(database.sessions).insert(
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

  Future<void> logout() async {
    // Clear sessions
    await database.delete(database.sessions).go();
    _sessionStartTime = null;
    value = null;
  }

  Future<bool> verifySupervisorPin(int userId, String pin) async {
    final user = await (database.select(database.users)
          ..where((t) => t.id.equals(userId) & t.pin.equals(pin) & t.roleTier.isBiggerOrEqualValue(4)))
        .getSingleOrNull();
    return user != null;
  }
}

final authService = AuthService();
