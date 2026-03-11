import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/theme_notifier.dart';
import '../../core/utils/responsive.dart';
import '../models/activity_log.dart';
import '../services/activity_log_service.dart';
import 'app_drawer.dart';
import 'notification_bell.dart';

class ActivityLogScreen extends StatelessWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, _) {
        final isDark = mode == ThemeMode.dark;
        final bgCol = isDark ? dBg : lBg;
        final surfaceCol = isDark ? dSurface : lSurface;
        final textCol = isDark ? dText : lText;
        final subtextCol = isDark ? dSubtext : lSubtext;
        final borderCol = isDark ? dBorder : lBorder;
        final cardCol = isDark ? dCard : lCard;

        return Scaffold(
          backgroundColor: bgCol,
          appBar: AppBar(
            backgroundColor: surfaceCol,
            elevation: 0,
            leading: Builder(
              builder: (ctx) => InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Scaffold.of(ctx).openDrawer(),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 2.5,
                        width: context.getRSize(22),
                        decoration: BoxDecoration(
                          color: textCol,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Container(
                        height: 2.5,
                        width: context.getRSize(16),
                        decoration: BoxDecoration(
                          color: blueMain,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Container(
                        height: 2.5,
                        width: context.getRSize(22),
                        decoration: BoxDecoration(
                          color: textCol,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(context.getRSize(8)),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [blueLight, blueMain],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: blueMain.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    FontAwesomeIcons.clockRotateLeft,
                    color: Colors.white,
                    size: context.getRSize(16),
                  ),
                ),
                SizedBox(width: context.getRSize(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Activity Logs',
                          style: TextStyle(
                            fontSize: context.getRFontSize(18),
                            fontWeight: FontWeight.w800,
                            color: textCol,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Text(
                        'System History',
                        style: TextStyle(
                          fontSize: context.getRFontSize(11),
                          color: blueMain,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              const NotificationBell(),
              SizedBox(width: context.getRSize(8)),
            ],
          ),
          drawer: const AppDrawer(activeRoute: 'activity_logs'),
          body: ValueListenableBuilder<List<ActivityLog>>(
            valueListenable: activityLogService,
            builder: (context, logs, child) {
              if (logs.isEmpty) {
                return _buildEmptyState(context, textCol, subtextCol);
              }

              return ListView.separated(
                padding: context.rPadding(16),
                itemCount: logs.length,
                separatorBuilder: (context, index) =>
                    SizedBox(height: context.getRSize(12)),
                itemBuilder: (context, index) {
                  return _buildLogCard(
                    context,
                    logs[index],
                    cardCol,
                    surfaceCol,
                    textCol,
                    subtextCol,
                    borderCol,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    Color textCol,
    Color subtextCol,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: context.rPadding(20),
            decoration: BoxDecoration(
              color: textCol.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              FontAwesomeIcons.clockRotateLeft,
              size: context.getRSize(48),
              color: subtextCol.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: context.getRSize(24)),
          Text(
            'No Activity Yet',
            style: TextStyle(
              fontSize: context.getRFontSize(18),
              fontWeight: FontWeight.bold,
              color: textCol,
            ),
          ),
          SizedBox(height: context.getRSize(8)),
          Text(
            'Actions performed in the app will appear here.',
            style: TextStyle(
              fontSize: context.getRFontSize(14),
              color: subtextCol,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(
    BuildContext context,
    ActivityLog log,
    Color cardCol,
    Color surfaceCol,
    Color textCol,
    Color subtextCol,
    Color borderCol,
  ) {
    // Determine the icon and color based on the action or type
    final actionLower = log.action.toLowerCase();
    IconData icon = FontAwesomeIcons.bolt;
    Color iconColor = blueMain;

    if (actionLower.contains('order') || actionLower.contains('pos')) {
      icon = FontAwesomeIcons.cashRegister;
      iconColor = success;
    } else if (actionLower.contains('inventory') ||
        actionLower.contains('stock')) {
      icon = FontAwesomeIcons.boxesStacked;
      iconColor = const Color(0xFFF59E0B); // amber
    } else if (actionLower.contains('customer')) {
      icon = FontAwesomeIcons.user;
      iconColor = const Color(0xFF8B5CF6); // purple
    }

    return Container(
      decoration: BoxDecoration(
        color: surfaceCol,
        borderRadius: BorderRadius.circular(context.getRSize(16)),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: context.rPadding(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: context.rPadding(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(context.getRSize(12)),
              ),
              child: Icon(icon, size: context.getRSize(18), color: iconColor),
            ),
            SizedBox(width: context.getRSize(16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          log.action,
                          style: TextStyle(
                            fontSize: context.getRFontSize(15),
                            fontWeight: FontWeight.w700,
                            color: textCol,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTimeAgo(log.timestamp),
                        style: TextStyle(
                          fontSize: context.getRFontSize(12),
                          fontWeight: FontWeight.w600,
                          color: subtextCol,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.getRSize(4)),
                  Text(
                    log.description,
                    style: TextStyle(
                      fontSize: context.getRFontSize(13.5),
                      height: 1.4,
                      color: subtextCol,
                    ),
                  ),
                  SizedBox(height: context.getRSize(8)),
                  Text(
                    DateFormat('MMM d, y • h:mm a').format(log.timestamp),
                    style: TextStyle(
                      fontSize: context.getRFontSize(11),
                      fontWeight: FontWeight.w500,
                      color: subtextCol.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM d').format(timestamp);
  }
}
