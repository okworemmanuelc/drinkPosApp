/// Post-OTP screen on the deep-link invite path.
///
/// Captures the invitee's name → calls [InviteApiService.redeemByToken]
/// (atomic profile + user insert + invite-accepted flip in one RPC) →
/// syncs cloud → local → pushes CreatePinScreen with the freshly-created
/// local user.
///
/// The manual-code fallback (InviteCodeScreen) routes to a similar
/// experience via [redeemByCode] — kept as a separate widget below.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reebaplus_pos/core/providers/app_providers.dart';
import 'package:reebaplus_pos/core/theme/app_decorations.dart';
import 'package:reebaplus_pos/core/utils/notifications.dart';
import 'package:reebaplus_pos/features/auth/screens/create_pin_screen.dart';
import 'package:reebaplus_pos/features/auth/widgets/auth_background.dart';
import 'package:reebaplus_pos/features/auth/widgets/onboarding_step_indicator.dart';
import 'package:reebaplus_pos/features/invite/services/invite_api_service.dart';
import 'package:reebaplus_pos/shared/widgets/app_button.dart';

class InviteJoinNameScreen extends ConsumerStatefulWidget {
  /// Pass exactly one of [token] or [code]. The deep-link path uses
  /// [token]; the manual-code fallback (InviteCodeScreen) uses [code].
  final String? token;
  final String? code;
  final String email;

  const InviteJoinNameScreen({
    super.key,
    this.token,
    this.code,
    required this.email,
  }) : assert(
          (token == null) != (code == null),
          'Exactly one of token/code must be provided',
        );

  @override
  ConsumerState<InviteJoinNameScreen> createState() =>
      _InviteJoinNameScreenState();
}

class _InviteJoinNameScreenState
    extends ConsumerState<InviteJoinNameScreen> {
  final _nameController = TextEditingController();
  bool _loading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitted) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppNotification.showError(context, 'Please enter your full name.');
      return;
    }

    setState(() => _loading = true);

    final api = ref.read(inviteApiServiceProvider);
    final auth = ref.read(authProvider);

    final result = widget.token != null
        ? await api.redeemByToken(token: widget.token!, userName: name)
        : await api.redeemByCode(code: widget.code!, userName: name);

    if (!mounted) return;

    if (result is InviteApiErr<Map<String, dynamic>>) {
      setState(() => _loading = false);
      AppNotification.showError(context, result.message);
      return;
    }
    final data = (result as InviteApiOk<Map<String, dynamic>>).data;
    final businessId = data['business_id']?.toString();
    if (businessId == null || businessId.isEmpty) {
      setState(() => _loading = false);
      AppNotification.showError(
        context,
        'Server returned an unexpected response. Please retry.',
      );
      return;
    }

    // The redeem RPC just inserted/updated public.users with the granular
    // role and current auth.uid(). Pull cloud → local so the local users
    // row exists for the PIN screen to attach to.
    try {
      await auth.syncOnLogin(businessId);
      await auth.upsertLocalUserFromProfile();
    } catch (e) {
      debugPrint('[InviteJoinName] sync failed: $e');
    }

    final localUser = await auth.getUserByEmail(widget.email.toLowerCase());
    if (!mounted) return;

    if (localUser == null) {
      setState(() => _loading = false);
      AppNotification.showError(
        context,
        'Could not load your account locally. Please retry.',
      );
      return;
    }

    // Drop the pending token now that redemption succeeded — read-and-clear.
    auth.consumePendingInviteToken();
    _submitted = true;

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CreatePinScreen(user: localUser, isJoinFlow: true),
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
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OnboardingStepIndicator(
                currentStep: 4,
                totalSteps: 6,
                stepLabels: OnboardingStepIndicator.pathBLabels,
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Welcome to the team',
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
