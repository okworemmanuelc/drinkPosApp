import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/providers/app_providers.dart';
import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/features/auth/screens/create_pin_screen.dart';
import 'package:reebaplus_pos/shared/services/auth_service.dart';
import 'package:reebaplus_pos/core/utils/notifications.dart';
import 'package:reebaplus_pos/features/auth/widgets/onboarding_step_indicator.dart';
import 'package:reebaplus_pos/features/auth/widgets/auth_background.dart';
import 'package:reebaplus_pos/core/theme/app_decorations.dart';

class JoinNameEntryScreen extends ConsumerStatefulWidget {
  final String email;
  final InviteValidationResult result;

  const JoinNameEntryScreen({
    super.key,
    required this.email,
    required this.result,
  });

  @override
  ConsumerState<JoinNameEntryScreen> createState() =>
      _JoinNameEntryScreenState();
}

class _JoinNameEntryScreenState extends ConsumerState<JoinNameEntryScreen> {
  final _nameController = TextEditingController();
  bool _loading = false;
  bool _submitted = false; // prevents re-inserting the user on back+re-submit

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitted) return; // guard against back+re-submit creating a duplicate

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppNotification.showError(context, 'Please enter your full name.');
      return;
    }

    setState(() => _loading = true);

    // Create staff account logic
    final db = ref.read(databaseProvider);
    final auth = ref.read(authProvider);
    final invite = widget.result.invite!;
    await db.into(db.users).insert(
          UsersCompanion.insert(
            name: name,
            email: drift.Value(widget.email),
            pin: AuthService.setupRequiredPin,
            role: invite.role,
            roleTier: const drift.Value(1),
            warehouseId: drift.Value(invite.warehouseId),
            businessId: invite.businessId,
            biometricEnabled: const drift.Value(false),
          ),
        );
    final newUser = await db.warehousesDao.getUserByEmail(widget.email);
    if (newUser == null) {
      throw StateError('User not found after insert (email=${widget.email})');
    }
    final newId = newUser.id;
    await auth.redeemInvite(invite.code, newId);

    if (!mounted) return;
    _submitted = true;
    setState(() => _loading = false);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreatePinScreen(user: newUser, isJoinFlow: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return AuthBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                currentStep: 4,
                totalSteps: 6,
                stepLabels: OnboardingStepIndicator.pathBLabels,
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Welcome to the Team',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'What is your full name?',
                  style: TextStyle(
                    fontSize: 15,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(height: 48),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppDecorations.glassCard(context),
                child: TextField(
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                  style: TextStyle(color: textColor, fontSize: 18),
                  decoration: AppDecorations.authInputDecoration(
                    context,
                    label: 'Full Name',
                    prefixIcon: Icons.person_outline_rounded,
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
    );
  }
}
