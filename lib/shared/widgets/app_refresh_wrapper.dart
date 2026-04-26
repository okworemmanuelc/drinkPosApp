import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reebaplus_pos/core/services/supabase_sync_service.dart';
import 'package:reebaplus_pos/core/providers/app_providers.dart';

class AppRefreshWrapper extends ConsumerWidget {
  final Widget child;
  
  const AppRefreshWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        // Provide haptic feedback for tactile feel
        HapticFeedback.lightImpact();
        
        try {
          final authService = ref.read(authProvider);
          final user = authService.currentUser;
          
          if (user != null && user.businessId != null) {
            final syncService = SupabaseSyncService(ref.read(databaseProvider));
            await syncService.syncAll(user.businessId!);
            
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sync completed successfully.'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Sync failed. You might be offline.'),
                backgroundColor: Colors.red.shade400,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      },
      child: child,
    );
  }
}
