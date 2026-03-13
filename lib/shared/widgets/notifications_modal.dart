import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../models/notification.dart';
import '../../core/utils/responsive.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/theme_notifier.dart';

class NotificationsModal extends StatelessWidget {
  const NotificationsModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotificationsModal(),
    );
  }

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? dSurface : lSurface;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(context),
      child: DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        snap: true,
        snapSizes: const [0.5, 0.9],
        builder: (context, scrollController) {
          return GestureDetector(
            onTap: () {}, // Prevent tap from reaching the barrier
            child: Container(
              decoration: BoxDecoration(
                color: _bg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Handle
                  Padding(
                    padding: EdgeInsets.only(top: context.getRSize(12)),
                    child: Container(
                      width: context.getRSize(40),
                      height: context.getRSize(4),
                      decoration: BoxDecoration(
                        color: _border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  _buildHeader(context),
                  Divider(height: 1, color: _border),
                  // List
                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable: notificationService,
                      builder: (context, notifications, _) {
                        if (notifications.isEmpty) {
                          return _buildEmptyState(context);
                        }
                        return ListView.separated(
                          controller: scrollController,
                          padding: EdgeInsets.all(context.getRSize(16)),
                          itemCount: notifications.length,
                          separatorBuilder: (context, index) =>
                              SizedBox(height: context.getRSize(12)),
                          itemBuilder: (context, index) {
                            final n = notifications[index];
                            return _NotificationCard(notification: n);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.getRSize(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                FontAwesomeIcons.bell,
                size: context.getRSize(20),
                color: blueMain,
              ),
              SizedBox(width: context.getRSize(12)),
              Text(
                'Notifications',
                style: TextStyle(
                  fontSize: context.getRFontSize(18),
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () {
              notificationService.clearAll();
            },
            child: Text(
              'Dismiss All',
              style: TextStyle(
                color: danger,
                fontWeight: FontWeight.bold,
                fontSize: context.getRFontSize(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FontAwesomeIcons.bellSlash,
            size: context.getRSize(48),
            color: _border,
          ),
          SizedBox(height: context.getRSize(16)),
          Text(
            'No notifications yet',
            style: TextStyle(
              color: _subtext,
              fontSize: context.getRFontSize(16),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;

  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    final bool isDark = themeNotifier.value == ThemeMode.dark;
    final Color cardBg = isDark ? dCard : lCard;
    final Color textCol = isDark ? dText : lText;
    final Color subtextCol = isDark ? dSubtext : lSubtext;
    final Color borderCol = isDark ? dBorder : lBorder;

    final IconData icon = _getIconForType(notification.type);
    final Color iconColor = _getColorForType(notification.type);

    return Container(
      padding: EdgeInsets.all(context.getRSize(16)),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(context.getRSize(10)),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: context.getRSize(16),
            ),
          ),
          SizedBox(width: context.getRSize(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.message,
                  style: TextStyle(
                    color: textCol,
                    fontSize: context.getRFontSize(14),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: context.getRSize(4)),
                Text(
                  DateFormat('MMM d, h:mm a').format(notification.timestamp),
                  style: TextStyle(
                    color: subtextCol,
                    fontSize: context.getRFontSize(12),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: context.getRSize(18),
              color: subtextCol,
            ),
            onPressed: () {
              notificationService.deleteNotification(notification.id);
            },
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'new_order':
        return FontAwesomeIcons.receipt;
      case 'low_stock':
        return FontAwesomeIcons.triangleExclamation;
      case 'large_expense':
        return FontAwesomeIcons.fileInvoiceDollar;
      case 'new_delivery':
        return FontAwesomeIcons.truckRampBox;
      case 'failed_transaction':
        return FontAwesomeIcons.circleExclamation;
      default:
        return FontAwesomeIcons.bell;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'new_order':
        return success;
      case 'low_stock':
        return const Color(0xFFF59E0B);
      case 'large_expense':
        return danger;
      case 'new_delivery':
        return blueMain;
      case 'failed_transaction':
        return danger;
      default:
        return blueMain;
    }
  }
}
