import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:reebaplus_pos/shared/services/notification_service.dart';
import 'package:reebaplus_pos/core/utils/responsive.dart';
import 'package:reebaplus_pos/shared/widgets/notifications_modal.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ValueListenableBuilder(
      valueListenable: notificationService,
      builder: (context, notifications, _) {
        final unreadCount = notificationService.unreadCount;

        return Padding(
          padding: EdgeInsets.only(right: context.getRSize(8)),
          child: InkWell(
            onTap: () => NotificationsModal.show(context),
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(context.getRSize(8)),
                  child: Icon(
                    FontAwesomeIcons.bell,
                    size: context.getRSize(20),
                    color: t.colorScheme.primary,
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: context.getRSize(8),
                    right: context.getRSize(8),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: t.colorScheme.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: context.getRSize(14),
                        minHeight: context.getRSize(14),
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : unreadCount.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: context.getRFontSize(8),
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
