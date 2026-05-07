import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:reebaplus_pos/core/providers/app_providers.dart';
import 'package:reebaplus_pos/core/theme/app_decorations.dart';

class FirstSyncScreen extends ConsumerStatefulWidget {
  final String businessId;

  const FirstSyncScreen({
    super.key,
    required this.businessId,
  });

  @override
  ConsumerState<FirstSyncScreen> createState() => _FirstSyncScreenState();
}

class _FirstSyncScreenState extends ConsumerState<FirstSyncScreen> {
  bool _syncing = false;
  String? _errorMessage;
  int _tipIndex = 0;
  Timer? _tipTimer;

  static const List<String> _syncTips = [
    'Initializing secure offline database...',
    'Downloading warehouse registries and configurations...',
    'Fetching categories and business rules...',
    'Downloading product catalogs and price lists...',
    'Syncing customer accounts and ledger balances...',
    'Establishing secure realtime communication channels...',
    'Loading historical ledgers and transaction journals...',
    'Preparing your custom POS workspace...',
  ];

  @override
  void initState() {
    super.initState();
    _startInitialSync();
    _startTipRotation();
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    super.dispose();
  }

  void _startTipRotation() {
    _tipTimer = Timer.periodic(const Duration(milliseconds: 3000), (timer) {
      if (mounted) {
        setState(() {
          _tipIndex = (_tipIndex + 1) % _syncTips.length;
        });
      }
    });
  }

  Future<void> _startInitialSync() async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
      _errorMessage = null;
    });

    try {
      final syncService = ref.read(supabaseSyncServiceProvider);
      // Run the primary full sync!
      await syncService.syncAll(widget.businessId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().contains('SocketException') ||
                  e.toString().contains('Failed host lookup')
              ? 'No internet connection detected. Please verify your connection and try again.'
              : 'Sync failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final primaryColor = t.colorScheme.primary;

    return Scaffold(
      backgroundColor: t.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            children: [
              const Spacer(),
              // Beautiful Glowing Branding Centerpiece
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer slowly pulsing glow
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.9, end: 1.1),
                      duration: const Duration(seconds: 2),
                      curve: Curves.easeInOut,
                      onEnd: () {}, // Handled by continuous cycle below if stateful, but Tween handles it neatly
                      builder: (context, scale, child) {
                        return Container(
                          width: 140 * scale,
                          height: 140 * scale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.15),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // Centered circular spinner
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        backgroundColor: primaryColor.withValues(alpha: 0.1),
                      ),
                    ),
                    // Icon core
                    Icon(
                      FontAwesomeIcons.cloudArrowDown,
                      size: 36,
                      color: primaryColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Title and Explainer
              Text(
                'Syncing Your Store',
                style: t.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: t.colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.2),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      _errorMessage != null ? 'Sync Paused' : _syncTips[_tipIndex],
                      key: ValueKey<String>(_errorMessage != null
                          ? 'error'
                          : _syncTips[_tipIndex]),
                      textAlign: TextAlign.center,
                      style: t.textTheme.bodyMedium?.copyWith(
                        color: _errorMessage != null
                            ? t.colorScheme.error
                            : t.colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Error or Action panel at the bottom
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppDecorations.glassCard(context, radius: 16),
                  child: Column(
                    children: [
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: t.textTheme.bodySmall?.copyWith(
                          color: t.colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _startInitialSync,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: t.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(FontAwesomeIcons.arrowsRotate, size: 14),
                        label: const Text('Retry Synchronization'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Safe and calming informational note
                Text(
                  'This only happens once on your fresh device login.\nPlease keep the app open.',
                  textAlign: TextAlign.center,
                  style: t.textTheme.bodySmall?.copyWith(
                    color: t.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
