import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/services/auth_service.dart';

class WarehouseAssignmentScreen extends StatefulWidget {
  final UserData user;
  const WarehouseAssignmentScreen({super.key, required this.user});

  @override
  State<WarehouseAssignmentScreen> createState() => _WarehouseAssignmentScreenState();
}

class _WarehouseAssignmentScreenState extends State<WarehouseAssignmentScreen> {
  late Timer _timer;
  Duration _timeLeft = Duration.zero;
  late DateTime _expiry;

  @override
  void initState() {
    super.initState();
    _expiry = (widget.user.createdAt ?? DateTime.now()).add(const Duration(hours: 48));
    _calculateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _calculateTimeLeft());
    
    // Poll for assignment every 5 seconds
    _assignmentCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkAssignment());
  }

  late Timer _assignmentCheckTimer;

  Future<void> _checkAssignment() async {
    final updatedUser = await (database.select(database.users)
          ..where((u) => u.id.equals(widget.user.id)))
        .getSingleOrNull();
    
    if (updatedUser != null && updatedUser.warehouseId != null) {
      // Assignment detected! 
      // Update AuthService to trigger the ValueListenableBuilder in main.dart
      authService.setCurrentUser(updatedUser);
    }
  }

  void _calculateTimeLeft() {
    final now = DateTime.now();
    final diff = _expiry.difference(now);

    if (mounted) {
      setState(() {
        _timeLeft = diff.isNegative ? Duration.zero : diff;
      });
    }

    // Auto-check for assignment every 10 seconds or similar
    // In a real app, this would be reactive to DB changes.
    // Since we're using drift, the main.dart ValueListenableBuilder 
    // on authService will trigger a rebuild if the UserData object changes.
  }

  @override
  void dispose() {
    _timer.cancel();
    _assignmentCheckTimer.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? dBg : lBg;
    final surface = isDark ? dSurface : lSurface;
    final text = isDark ? dText : lText;
    final subtext = isDark ? dSubtext : lSubtext;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: blueMain.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    FontAwesomeIcons.warehouse,
                    size: 40,
                    color: blueMain,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Waiting for Assignment',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: text,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Hello ${widget.user.name.split(' ')[0]}, your account is active but hasn\'t been assigned a warehouse yet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: subtext, height: 1.5),
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? dBorder : lBorder),
                ),
                child: Column(
                  children: [
                    const Text(
                      'TIME UNTIL ESCALATION',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: blueMain,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _formatDuration(_timeLeft),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w300,
                        fontFamily: 'monospace',
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _timeLeft.inSeconds / (48 * 3600),
                      backgroundColor: subtext.withValues(alpha: 0.1),
                      color: blueMain,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Text(
                'The CEO has been notified. This timer secures your onboarding window.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: subtext),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => authService.logout(),
                icon: const Icon(FontAwesomeIcons.rightFromBracket, size: 14),
                label: const Text('Log Out'),
                style: TextButton.styleFrom(foregroundColor: danger),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
