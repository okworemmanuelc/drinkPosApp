import 'package:flutter/widgets.dart';

class User {
  final String id;
  final String name;
  final String role;

  User({required this.id, required this.name, required this.role});
}

class AuthService extends ValueNotifier<User?> {
  AuthService() : super(User(id: 's4', name: 'John Cashier', role: 'Cashier'));

  User? get currentUser => value;

  void logout() {
    value = null;
  }
}

final authService = AuthService();
