import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/shared/widgets/main_layout.dart';
import 'package:reebaplus_pos/features/auth/screens/success_dashboard_entry_screen.dart';
import 'package:reebaplus_pos/features/auth/screens/access_granted_screen.dart';
import 'package:reebaplus_pos/shared/services/auth_service.dart';

class BiometricSetupScreen extends StatefulWidget {
  final UserData user;
  final bool isNewBusinessSetup;
  final bool isJoinFlow;

  const BiometricSetupScreen({
    super.key,
    required this.user,
    this.isNewBusinessSetup = false,
    this.isJoinFlow = false,
  });

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _loading = false;
  String? _errorMessage;

  Future<void> _enableBiometrics() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        setState(() {
          _errorMessage =
              "Biometric authentication is not supported on this device.";
          _loading = false;
        });
        return;
      }

      final authenticated = await auth.authenticate(
        localizedReason: 'Enable biometrics for quick login',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('use_biometrics', true);
        _done();
      } else {
        setState(() {
          _errorMessage = "Authentication failed or canceled.";
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "An error occurred during biometric setup.";
        _loading = false;
      });
    }
  }

  void _skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_biometrics', false);
    _done();
  }

  void _done() {
    authService.setCurrentUser(widget.user);
    if (!mounted) return;
    if (widget.isNewBusinessSetup) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SuccessDashboardEntryScreen()),
      );
    } else if (widget.isJoinFlow) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AccessGrantedScreen(user: widget.user),
        ),
      );
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainLayout()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/auth_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.black),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.fingerprint, size: 80, color: Colors.white),
                  const SizedBox(height: 24),
                  const Text(
                    'Speed up your login',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Use Face ID or Fingerprint to log into Reebaplus POS instantly and securely instead of typing your PIN every time.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFFF6B6B),
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  AppButton(
                    text: 'Enable Biometrics',
                    isLoading: _loading,
                    onPressed: _enableBiometrics,
                  ),
                  const SizedBox(height: 16),

                  AppButton(
                    text: 'Skip for now',
                    variant: AppButtonVariant.ghost,
                    onPressed: _loading ? null : _skip,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
