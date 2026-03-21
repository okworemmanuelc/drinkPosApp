import 'dart:async';
import 'dart:ui';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient (Darker / Higher Contrast)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark 
                  ? [const Color(0xFF020617), const Color(0xFF0F172A), const Color(0xFF020617)]
                  : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9), const Color(0xFFF8FAFC)],
              ),
            ),
          ),
          
          // Decorative Blobs (More / Better Placed)
          Positioned(
            top: -120,
            right: -80,
            child: _BlurredBlob(
              color: const Color(0xFF312E81).withValues(alpha: isDark ? 0.3 : 0.1),
              size: 350,
            ),
          ),
          Positioned(
            bottom: -70,
            left: -120,
            child: _BlurredBlob(
              color: blueMain.withValues(alpha: isDark ? 0.25 : 0.08),
              size: 450,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.4,
            left: -50,
            child: _BlurredBlob(
              color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.15 : 0.05),
              size: 250,
            ),
          ),
          
          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Glass Icon Container with Glow
                    _GlassContainer(
                      padding: const EdgeInsets.all(24),
                      borderRadius: 36,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isDark ? blueLight : blueMain).withValues(alpha: 0.3),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          FontAwesomeIcons.warehouse,
                          size: 56,
                          color: isDark ? Colors.white : blueMain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    Text(
                      'Waiting for Assignment',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : lText,
                        letterSpacing: -1.2,
                        height: 1.1,
                        shadows: [
                          if (isDark)
                            const Shadow(
                              color: Colors.black45,
                              offset: Offset(0, 4),
                              blurRadius: 10,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Hello ${widget.user.name.split(' ')[0]}, your account is active but hasn\'t been assigned a warehouse yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17, 
                          color: isDark ? Colors.white.withValues(alpha: 0.7) : lSubtext, 
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    // Glassy Timer Card with Higher Contrast
                    _GlassContainer(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      borderRadius: 40,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                FontAwesomeIcons.clock,
                                size: 16,
                                color: isDark ? blueLight : blueMain,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'ACCOUNT ONBOARDING WINDOW',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  color: isDark ? blueLight : blueMain,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Text(
                            _formatDuration(_timeLeft),
                            style: TextStyle(
                              fontSize: 60,
                              fontWeight: FontWeight.w200,
                              fontFamily: 'monospace',
                              color: isDark ? Colors.white : lText,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Progress Bar with Higher Contrast and Glow
                          Stack(
                            children: [
                              Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.08 : 0.05),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: (_timeLeft.inSeconds / (48 * 3600)).clamp(0.0, 1.0),
                                child: Container(
                                  height: 10,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [blueMain, Color(0xFF6366F1), blueLight],
                                    ),
                                    borderRadius: BorderRadius.circular(5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: blueMain.withValues(alpha: 0.5),
                                        blurRadius: 12,
                                        offset: const Offset(0, 0),
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 48),
                    
                    Text(
                      'The CEO has been notified.\nThis timer secures your onboarding window.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15, 
                        color: (isDark ? Colors.white : lSubtext).withValues(alpha: 0.6),
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    // Premium Glass Logout Action
                    _GlassContainer(
                      borderRadius: 24,
                      padding: EdgeInsets.zero,
                      child: TextButton.icon(
                        onPressed: () => authService.logout(),
                        icon: const Icon(FontAwesomeIcons.rightFromBracket, size: 18),
                        label: const Text(
                          'Logout from Account',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: danger.withValues(alpha: 0.9),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
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

class _BlurredBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _BlurredBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70), // Increased blur for better blending
        child: Container(color: Colors.transparent),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // Stronger blur
        child: Container(
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.4), // Higher alpha for dark mode contrast
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.2 : 0.5), // Stronger border
              width: 2.0, // Thicker border
            ),
            boxShadow: [
              if (isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
