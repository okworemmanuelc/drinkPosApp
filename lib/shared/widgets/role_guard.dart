import 'package:flutter/material.dart';

class RoleGuard extends StatelessWidget {
  final int minTier;
  final Widget child;
  final Widget? fallback;

  const RoleGuard({
    super.key,
    required this.minTier,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
