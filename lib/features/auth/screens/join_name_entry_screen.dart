import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;

import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/features/auth/screens/create_pin_screen.dart';
import 'package:reebaplus_pos/shared/services/auth_service.dart';
import 'package:reebaplus_pos/core/utils/notifications.dart';
import 'package:reebaplus_pos/features/auth/widgets/onboarding_step_indicator.dart';

class JoinNameEntryScreen extends StatefulWidget {
  final String email;
  final InviteValidationResult result;

  const JoinNameEntryScreen({
    super.key,
    required this.email,
    required this.result,
  });

  @override
  State<JoinNameEntryScreen> createState() => _JoinNameEntryScreenState();
}

class _JoinNameEntryScreenState extends State<JoinNameEntryScreen> {
  final _nameController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppNotification.showError(context, 'Please enter your full name.');
      return;
    }

    setState(() => _loading = true);

    // Create staff account logic
    final invite = widget.result.invite!;
    final newId = await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            name: name,
            email: drift.Value(widget.email),
            pin: 'TEMPPIN', // temporary
            role: invite.role,
            roleTier: const drift.Value(1),
            warehouseId: drift.Value(invite.warehouseId),
            businessId: drift.Value(invite.businessId),
            biometricEnabled: const drift.Value(false),
          ),
        );

    // Redeem the invite to finalize role & business linkages
    await authService.redeemInvite(invite.code, newId);

    final newUser = await database.warehousesDao.getUserById(newId);

    if (!mounted) return;
    setState(() => _loading = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CreatePinScreen(
          user: newUser!,
          isJoinFlow: true, // we will add this parameter to CreatePinScreen
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const OnboardingStepIndicator(
                    currentStep: 4,
                    totalSteps: 6,
                    stepLabels: OnboardingStepIndicator.pathBLabels,
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Welcome to the Team',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'What is your full name?',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: TextField(
                          controller: _nameController,
                          keyboardType: TextInputType.name,
                          textCapitalization: TextCapitalization.words,
                          autofocus: true,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            labelStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            prefixIcon: Icon(
                              Icons.person_outline_rounded,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  AppButton(
                    text: 'Continue',
                    isLoading: _loading,
                    onPressed: _loading ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
