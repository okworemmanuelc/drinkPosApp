import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reebaplus_pos/shared/widgets/main_layout.dart';
import 'package:reebaplus_pos/features/auth/widgets/auth_background.dart';
import 'package:reebaplus_pos/core/providers/app_providers.dart';
import 'package:reebaplus_pos/features/inventory/widgets/add_product_sheet.dart';
import 'package:reebaplus_pos/shared/widgets/smooth_route.dart';

class SuccessDashboardEntryScreen extends ConsumerStatefulWidget {
  const SuccessDashboardEntryScreen({super.key});

  @override
  ConsumerState<SuccessDashboardEntryScreen> createState() =>
      _SuccessDashboardEntryScreenState();
}

class _SuccessDashboardEntryScreenState
    extends ConsumerState<SuccessDashboardEntryScreen> {
  @override
  void initState() {
    super.initState();
    _startAutoForward();
  }

  void _startAutoForward() {
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      
      // Navigate to the Dashboard instantly
      Navigator.of(context).pushAndRemoveUntil(
        SmoothRoute(page: const MainLayout()),
        (route) => false,
      );

      // Wait a fraction of a second for MainLayout to build, then trigger the Add Product sheet
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        final mainContext = ref.read(navigationProvider).mainScaffoldKey.currentContext;
        if (mainContext != null && mainContext.mounted) {
          showModalBottomSheet(
            context: mainContext,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const AddProductSheet(),
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return AuthBackground(
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success Icon
              Container(
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
              const SizedBox(height: 32),

              // Success Text
              Text(
                'Your business is ready!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Preparing your dashboard...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: theme.colorScheme.primary,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
