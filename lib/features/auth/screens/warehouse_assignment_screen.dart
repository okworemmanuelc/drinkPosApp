import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/database/app_database.dart';
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
  late Timer _assignmentCheckTimer;

  @override
  void initState() {
    super.initState();
    _expiry = (widget.user.createdAt ?? DateTime.now()).add(const Duration(hours: 48));
    _calculateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _calculateTimeLeft());
    
    // Poll for assignment every 5 seconds
    _assignmentCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkAssignment());
  }

  Future<void> _checkAssignment() async {
    final updatedUser = await (database.select(database.users)
          ..where((u) => u.id.equals(widget.user.id)))
        .getSingleOrNull();
    
    if (updatedUser != null && updatedUser.warehouseId != null) {
      // Assignment detected! 
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
    const text = Colors.white;
    final subtext = Colors.white.withValues(alpha: 0.8);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Darker Background Image with High Blur
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/auth_bg.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black54, // Darken the image
                  BlendMode.darken,
                ),
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                color: Colors.black.withValues(alpha: 0.4), // Extra darkening overlay
              ),
            ),
          ),
          
          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          FontAwesomeIcons.warehouse,
                          size: 40,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Glassy Finish for Text
                    _GlassContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      borderRadius: 16,
                      child: Column(
                        children: [
                          const Text(
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
                            style: TextStyle(
                              fontSize: 15, 
                              color: subtext, 
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    _GlassContainer(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      borderRadius: 24,
                      child: Column(
                        children: [
                          Text(
                            'TIME UNTIL ESCALATION',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _formatDuration(_timeLeft),
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w300,
                              fontFamily: 'monospace',
                              color: text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: _timeLeft.inSeconds / (48 * 3600),
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            color: Colors.white.withValues(alpha: 0.9),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    _GlassContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      borderRadius: 12,
                      child: Text(
                        'The CEO has been notified. This timer secures your onboarding window.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: subtext),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    TextButton.icon(
                      onPressed: () => authService.logout(),
                      icon: const Icon(FontAwesomeIcons.rightFromBracket, size: 14),
                      label: const Text('Log Out'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const _GlassContainer({
    required this.child,
    this.width,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.0,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
