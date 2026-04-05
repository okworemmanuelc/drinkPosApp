import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/features/auth/screens/join_name_entry_screen.dart';
import 'package:reebaplus_pos/shared/services/auth_service.dart';
import 'package:reebaplus_pos/features/auth/widgets/onboarding_step_indicator.dart';
import 'package:reebaplus_pos/features/auth/widgets/auth_background.dart';
import 'package:reebaplus_pos/core/theme/app_decorations.dart';

class RoleConfirmationScreen extends StatelessWidget {
  final String email;
  final InviteValidationResult result;

  const RoleConfirmationScreen({
    super.key,
    required this.email,
    required this.result,
  });

  void _onConfirm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JoinNameEntryScreen(email: email, result: result),
      ),
    );
  }

  void _onCancel(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final businessName = result.businessName ?? 'Unknown Business';
    final locationName = 'Main Location';
    final role = result.invite?.role ?? 'Staff';
    final inviterName = result.inviterName ?? 'Manager';

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
                      const OnboardingStepIndicator(
                        currentStep: 3,
                        totalSteps: 6,
                        stepLabels: OnboardingStepIndicator.pathBLabels,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Confirm Invitation',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Does this match what you were expecting?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Info Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: AppDecorations.glassCard(
                          context,
                          radius: 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildInfoRow(
                              context,
                              Icons.business_rounded,
                              'Business',
                              businessName,
                            ),
                            Divider(
                              color: textColor.withValues(alpha: 0.1),
                              height: 32,
                            ),
                            _buildInfoRow(
                              context,
                              Icons.location_on_rounded,
                              'Location',
                              locationName,
                            ),
                            Divider(
                              color: textColor.withValues(alpha: 0.1),
                              height: 32,
                            ),
                            _buildInfoRow(
                              context,
                              Icons.badge_rounded,
                              'Assigned Role',
                              role.toUpperCase(),
                              isHighlight: true,
                            ),
                            Divider(
                              color: textColor.withValues(alpha: 0.1),
                              height: 32,
                            ),
                            _buildInfoRow(
                              context,
                              Icons.person_rounded,
                              'Invited by',
                              inviterName,
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),
                      const SizedBox(height: 32),

                      AppButton(
                        text: 'Confirm and Join',
                        onPressed: () => _onConfirm(context),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () => _onCancel(context),
                          child: Text(
                            'This isn\'t right',
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.6),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
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

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        Icon(icon, color: textColor.withValues(alpha: 0.5), size: 20),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: textColor.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                color: isHighlight ? primary : textColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
