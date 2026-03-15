import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:ribaplus_pos/features/auth/widgets/pin_pad_view.dart';
import 'package:ribaplus_pos/core/theme/design_tokens.dart';
import 'package:ribaplus_pos/core/database/app_database.dart';

class LockOverlay extends StatelessWidget {
  final UserData staff;
  final VoidCallback onSuccess;

  const LockOverlay({
    super.key,
    required this.staff,
    required this.onSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Glassmorphism effect
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.8),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                // User info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(int.parse(staff.avatarColor.replaceFirst('#', '0xFF'))).withValues(alpha: 0.2),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Icon(
                    FontAwesomeIcons.userLock,
                    color: Color(int.parse(staff.avatarColor.replaceFirst('#', '0xFF'))),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  staff.name,
                  style: context.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Screen Locked',
                  style: context.bodyMedium.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 48),

                // PIN Pad
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.spacingL),
                    child: PinPadView(
                      staff: staff,
                      onBack: () {}, // No back on lock screen
                      onSuccess: onSuccess,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
