import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/features/auth/screens/join_name_entry_screen.dart';
import 'package:reebaplus_pos/shared/services/auth_service.dart';

class RoleConfirmationScreen extends StatelessWidget {
  final String email;
  final InviteValidationResult result;

  const RoleConfirmationScreen({
    super.key,
    required this.email,
    required this.result,
  });

  void _onConfirm(BuildContext context) {
    Navigator.of(context).pushReplacement(
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
    final businessName = result.businessName ?? 'Unknown Business';
    final locationName =
        'Main Location'; // For now, warehouseId to name is complex; keeping simplified or looking up if needed
    final role = result.invite?.role ?? 'Staff';
    final inviterName = result.inviterName ?? 'Manager';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/auth_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.black),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 64,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Confirm Invitation',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Does this match what you were expecting?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Info Card
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildInfoRow(
                                      Icons.business_rounded,
                                      'Business',
                                      businessName,
                                    ),
                                    const Divider(
                                      color: Colors.white24,
                                      height: 32,
                                    ),
                                    _buildInfoRow(
                                      Icons.location_on_rounded,
                                      'Location',
                                      locationName,
                                    ),
                                    const Divider(
                                      color: Colors.white24,
                                      height: 32,
                                    ),
                                    _buildInfoRow(
                                      Icons.badge_rounded,
                                      'Assigned Role',
                                      role.toUpperCase(),
                                      isHighlight: true,
                                    ),
                                    const Divider(
                                      color: Colors.white24,
                                      height: 32,
                                    ),
                                    _buildInfoRow(
                                      Icons.person_rounded,
                                      'Invited by',
                                      inviterName,
                                    ),
                                  ],
                                ),
                              ),
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
                                  color: Colors.white.withValues(alpha: 0.6),
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
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 20),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                color: isHighlight ? Colors.blueAccent : Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
