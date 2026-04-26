import 'package:flutter/material.dart';
import 'package:reebaplus_pos/features/auth/screens/new_owner_name_screen.dart';
import 'package:reebaplus_pos/features/auth/screens/invite_code_screen.dart';
import 'package:reebaplus_pos/features/auth/widgets/onboarding_step_indicator.dart';
import 'package:reebaplus_pos/features/auth/widgets/auth_background.dart';
import 'package:reebaplus_pos/core/theme/app_decorations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reebaplus_pos/core/providers/app_providers.dart';

class BusinessTypeSelectionScreen extends ConsumerWidget {
  final String email;

  const BusinessTypeSelectionScreen({super.key, required this.email});

  Future<void> _onRegister(BuildContext context, WidgetRef ref) async {
    // Ensure the database is completely empty before starting a new business
    await ref.read(databaseProvider).clearAllData();
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => NewOwnerNameScreen(email: email)));
  }

  Future<void> _onJoin(BuildContext context, WidgetRef ref) async {
    // Ensure the database is completely empty before joining a business
    await ref.read(databaseProvider).clearAllData();
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => InviteCodeScreen(email: email)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return AuthBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios, color: textColor, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(height: 8),
              const OnboardingStepIndicator(
                currentStep: 1,
                totalSteps: 7,
                stepLabels: OnboardingStepIndicator.pathALabels,
              ),
              const SizedBox(height: 16),
              Center(
                child: Image.asset(
                  'assets/images/reebaplus_logo.png',
                  height: 90,
                  color: isDark ? null : theme.colorScheme.primary,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.storefront, size: 90, color: textColor),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Get Started',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Are you setting up a new business or joining one?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // Register Option
              _buildOptionCard(
                context,
                title: 'Register a new business',
                subtitle:
                    'For owners & founders setting up for the first time.',
                icon: Icons.add_business_rounded,
                onTap: () => _onRegister(context, ref),
              ),

              const SizedBox(height: 20),

              // Join Option
              _buildOptionCard(
                context,
                title: 'Join an existing business',
                subtitle: 'For employees or partners who have an invite.',
                icon: Icons.people_alt_rounded,
                onTap: () => _onJoin(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final primary = theme.colorScheme.primary;

    return Container(
      decoration: AppDecorations.glassCard(context, radius: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          highlightColor: textColor.withValues(alpha: 0.05),
          splashColor: textColor.withValues(alpha: 0.1),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: textColor.withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: textColor.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
