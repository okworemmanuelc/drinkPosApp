import 'dart:ui';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/widgets/main_layout.dart';
import 'warehouse_assignment_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
      ),
    );

    // After animation, navigate to the appropriate screen
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      _navigateToNext();
    });
  }

  void _navigateToNext() {
    final user = authService.currentUser;
    Widget nextScreen;

    if (user == null) {
      nextScreen = const LoginScreen();
    } else if (user.roleTier < 5 && user.warehouseId == null) {
      nextScreen = WarehouseAssignmentScreen(user: user);
    } else {
      nextScreen = const MainLayout();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgUrl =
        'https://images.unsplash.com/photo-1543007630-9710e4a00a20?auto=format&fit=crop&q=80&w=1935&ixlib=rb-4.0.3';

    return Scaffold(
      body: Stack(
        children: [
          // ── Background Image ──────────────────────────────────────────
          Positioned.fill(
            child: Image.network(
              bgUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(color: Colors.black);
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(color: Colors.black54);
              },
            ),
          ),

          // ── Darken and Blur ───────────────────────────────────────────
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scale,
                  child: FadeTransition(
                    opacity: _opacity,
                    child: Column(
                      children: [
                        // Glassy Circle Logo Container
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 30,
                                spreadRadius: -5,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/ribaplus_logo.png',
                            height: 120,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.wine_bar,
                                    size: 100, color: Colors.blue),
                          ),
                        ),
                        const SizedBox(height: 40),
                        // App Name with neon-ish glow
                        Text(
                          'WELCOME RIBA PLUS POS',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.blue.withValues(alpha: 0.5),
                                blurRadius: 15,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'PREMIUM BAR PLATFORM',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 4,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 60),
                        // Glassy Loading Indicator
                        _GlassyLoader(),
                      ],
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

class _GlassyLoader extends StatefulWidget {
  @override
  State<_GlassyLoader> createState() => _GlassyLoaderState();
}

class _GlassyLoaderState extends State<_GlassyLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                Colors.transparent,
                Colors.blue.withValues(alpha: 0.5),
                Colors.blue,
              ],
              stops: const [0.0, 0.7, 1.0],
              transform: GradientRotation(_ctrl.value * 2 * 3.1415),
            ),
          ),
          child: Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.transparent, // Cutout via container color? No, we use a inner circle.
                shape: BoxShape.circle,
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
