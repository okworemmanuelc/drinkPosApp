import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/shared/widgets/main_layout.dart';
import 'package:reebaplus_pos/features/auth/widgets/auth_background.dart';
import 'package:reebaplus_pos/core/theme/app_decorations.dart';
import 'package:reebaplus_pos/core/providers/app_providers.dart';

class SuccessDashboardEntryScreen extends ConsumerWidget {
  const SuccessDashboardEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return AuthBackground(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 64,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      // Success Icon
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.greenAccent,
                            size: 80,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Success Text
                      Center(
                        child: Text(
                          'Your business is ready!',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'You have successfully set up your account. Here is a quick checklist of what to do next:',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: textColor.withValues(alpha: 0.8),
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Next Steps Checklist
                      _buildChecklistItem(
                        context,
                        ref,
                        Icons.inventory_2_rounded,
                        'Add your first product',
                        onTap: () {
                          ref.read(navigationProvider).setIndex(2); // Inventory
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const MainLayout(),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildChecklistItem(
                        context,
                        ref,
                        Icons.group_add_rounded,
                        'Invite your team',
                        onTap: () {
                          ref.read(navigationProvider).setIndex(8); // Staff
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const MainLayout(),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildChecklistItem(
                        context,
                        ref,
                        Icons.point_of_sale_rounded,
                        'Set up a payment method (Coming Soon)',
                        enabled: false,
                      ),

                      const Spacer(),
                      const SizedBox(height: 32),

                      AppButton(
                        text: 'Go to Dashboard',
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const MainLayout(),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildChecklistItem(
    BuildContext context,
    WidgetRef ref,
    IconData icon,
    String text, {
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecorations.glassCard(context, radius: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
              if (enabled)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: textColor.withValues(alpha: 0.3),
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
