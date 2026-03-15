import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../../core/database/app_database.dart';

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
    return ValueListenableBuilder<UserData?>(
      valueListenable: authService,
      builder: (context, user, _) {
        final tier = user?.roleTier ?? 0;
        
        if (tier >= minTier) {
          return child;
        }

        return fallback ?? _buildDefaultFallback(context);
      },
    );
  }

  Widget _buildDefaultFallback(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_person_rounded,
          color: Colors.grey.withValues(alpha: 0.5),
          size: 32,
        ),
        const SizedBox(height: 4),
        Text(
          'Insufficient role',
          style: TextStyle(
            color: Colors.grey.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

