import 'dart:async';
import 'package:flutter/material.dart';

enum AppNotificationType { success, error, info }

class AppNotification {
  static final _state = ValueNotifier<_NotificationData?>(null);
  static OverlayEntry? _overlayEntry;
  static Timer? _dismissTimer;

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, AppNotificationType.success);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, AppNotificationType.error);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message, AppNotificationType.info);
  }

  static void _show(BuildContext context, String message, AppNotificationType type) {
    _dismissTimer?.cancel();
    
    final data = _NotificationData(
      message: message,
      type: type,
    );

    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        builder: (context) => _NotificationOverlay(state: _state),
      );
      Overlay.of(context).insert(_overlayEntry!);
    }

    _state.value = data;

    _dismissTimer = Timer(const Duration(seconds: 4), () {
      _state.value = null;
    });
  }

  static void hide() {
    _dismissTimer?.cancel();
    _state.value = null;
  }
}

class _NotificationData {
  final String message;
  final AppNotificationType type;

  _NotificationData({required this.message, required this.type});
}

class _NotificationOverlay extends StatefulWidget {
  final ValueNotifier<_NotificationData?> state;

  const _NotificationOverlay({required this.state});

  @override
  State<_NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<_NotificationOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;
  _NotificationData? _currentData;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _opacityAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    widget.state.addListener(_onStateChanged);
    _onStateChanged();
  }

  void _onStateChanged() {
    if (widget.state.value != null) {
      setState(() {
        _currentData = widget.state.value;
      });
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    _controller.dispose();
    super.dispose();
  }

  Color _getBackgroundColor(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.success:
        return Colors.green.shade600;
      case AppNotificationType.error:
        return Colors.red.shade700;
      case AppNotificationType.info:
        return Colors.blue.shade600;
    }
  }

  IconData _getIcon(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.success:
        return Icons.check_circle_outline;
      case AppNotificationType.error:
        return Icons.error_outline;
      case AppNotificationType.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.isDismissed && widget.state.value == null) {
          return const SizedBox.shrink();
        }
        return Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          right: 16,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: _currentData != null 
                        ? _getBackgroundColor(_currentData!.type).withValues(alpha: 0.95)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: Padding(
                      key: ValueKey(_currentData?.message ?? ''),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Icon(
                            _currentData != null ? _getIcon(_currentData!.type) : Icons.info,
                            color: Colors.white,
                            size: 26,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentData != null ? _currentData!.message : '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                            onPressed: AppNotification.hide,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
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
