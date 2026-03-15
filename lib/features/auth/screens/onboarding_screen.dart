import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _contentController;
  late AnimationController _swipeIndicatorController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _swipeAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _swipeIndicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _contentController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));

    _swipeAnimation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(
        parent: _swipeIndicatorController,
        curve: Curves.easeInOut,
      ),
    );

    _contentController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _contentController.dispose();
    _swipeIndicatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildOnboardingPage(context),
          const LoginScreen(),
        ],
      ),
    );
  }

  Widget _buildOnboardingPage(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final titleFontSize = (screenWidth * 0.10).clamp(32.0, 52.0);
    final bottomGap = (screenHeight * 0.08).clamp(32.0, 64.0);

    return Stack(
      children: [
        // Background Image
        Positioned.fill(
          child: Image.asset(
            'assets/images/calculator_bg.png',
            fit: BoxFit.cover,
          ),
        ),
        // Dark overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.2),
                  Colors.black.withValues(alpha: 0.5),
                  Colors.black.withValues(alpha: 0.9),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        // Content
        SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacingL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        // App logo
                        Hero(
                          tag: 'auth_logo',
                          child: Container(
                            width: (screenWidth * 0.22).clamp(72.0, 100.0),
                            height: (screenWidth * 0.22).clamp(72.0, 100.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB)
                                      .withValues(alpha: 0.5),
                                  blurRadius: 30,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                'assets/images/ribaplus_logo.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: context.spacingL),
                        Text(
                          'Ribaplus POS',
                          textAlign: TextAlign.center,
                          style: context.h1.copyWith(
                            color: Colors.white,
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                          ),
                        ),
                        SizedBox(height: context.spacingS),
                        Text(
                          'Seamlessly manage your drinks and inventory with the modern POS experience.',
                          textAlign: TextAlign.center,
                          style: context.bodyLarge.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                            height: 1.6,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                // Swipe Indicator
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        1,
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeInOutCubic,
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Swipe up to Sign In',
                          style: context.bodyMedium.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        AnimatedBuilder(
                          animation: _swipeAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, -_swipeAnimation.value),
                              child: const Icon(
                                Icons.keyboard_double_arrow_up_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: bottomGap),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
