import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reebaplus_pos/core/utils/notifications.dart';
import 'package:reebaplus_pos/features/auth/onboarding/onboarding_draft.dart';
import 'package:reebaplus_pos/features/auth/widgets/auth_background.dart';
import 'package:reebaplus_pos/core/theme/app_decorations.dart';
import 'package:reebaplus_pos/features/auth/widgets/onboarding_step_indicator.dart';
import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/features/auth/screens/business_details_screen.dart';
import 'package:reebaplus_pos/shared/widgets/smooth_route.dart';

/// Shown after OTP verification for a brand-new owner. First step of the
/// collect-first / commit-once wizard: writes [OnboardingDraft.ownerName]
/// only — no DB or Supabase writes happen until PIN confirm.
class NewOwnerNameScreen extends ConsumerStatefulWidget {
  final String email;

  const NewOwnerNameScreen({super.key, required this.email});

  @override
  ConsumerState<NewOwnerNameScreen> createState() => _NewOwnerNameScreenState();
}

class _NewOwnerNameScreenState extends ConsumerState<NewOwnerNameScreen> {
  final _nameController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Restore from draft if the user navigated back from a later step.
    final draft = ref.read(onboardingDraftProvider);
    if (draft?.ownerName != null) _nameController.text = draft!.ownerName!;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppNotification.showError(context, 'Please enter your name.');
      return;
    }

    setState(() => _loading = true);

    // Write to draft only — atomic commit happens at PIN confirm. Defensive
    // start() in case the user reached this screen without going through
    // BusinessTypeSelection's seed.
    final notifier = ref.read(onboardingDraftProvider.notifier);
    if (ref.read(onboardingDraftProvider) == null) {
      notifier.start(widget.email);
    }
    notifier.update((d) => d.ownerName = name);

    if (!mounted) return;
    setState(() => _loading = false);

    Navigator.of(context).push(
      SmoothRoute(page: BusinessDetailsScreen(email: widget.email)),
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
          padding: EdgeInsets.fromLTRB(
            28,
            40,
            28,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
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
                currentStep: 2,
                totalSteps: 7,
                stepLabels: OnboardingStepIndicator.pathALabels,
              ),
              const SizedBox(height: 16),
              // Logo
              Center(
                child: Image.asset(
                  'assets/images/reebaplus_logo.png',
                  height: 90,
                  color: isDark ? null : theme.colorScheme.primary,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.storefront, size: 90, color: textColor),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Welcome to Reebaplus',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  "What's your name?",
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Name input card
              Container(
                decoration: AppDecorations.glassCard(context),
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _loading ? null : _submit(),
                  style: TextStyle(color: textColor),
                  decoration: AppDecorations.authInputDecoration(
                    context,
                    label: 'Full Name',
                    prefixIcon: Icons.person_outline,
                  ),
                ),
              ),
              const SizedBox(height: 24),

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
