import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/core/theme/design_tokens.dart';

enum ApprovalType { credit, crates, transfer, other }

class ApprovalCard extends StatelessWidget {
  final ApprovalType type;
  final String title;
  final String subtitle;
  final String amount;
  final String date;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  const ApprovalCard({
    super.key,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.onApprove,
    required this.onDecline,
  });

  IconData get _icon {
    switch (type) {
      case ApprovalType.credit:
        return FontAwesomeIcons.handHoldingDollar;
      case ApprovalType.crates:
        return FontAwesomeIcons.boxesStacked;
      case ApprovalType.transfer:
        return FontAwesomeIcons.truckArrowRight;
      case ApprovalType.other:
        return FontAwesomeIcons.circleExclamation;
    }
  }

  Color _getStatusColor(BuildContext context) {
    switch (type) {
      case ApprovalType.credit:
        return context.primaryColor;
      case ApprovalType.crates:
        return Colors.orange;
      case ApprovalType.transfer:
        return Colors.blue;
      case ApprovalType.other:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(context);

    return Container(
      margin: EdgeInsets.only(bottom: context.spacingM),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(context.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: context.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(context.spacingM),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(context.spacingS),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(context.radiusM),
                  ),
                  child: Icon(
                    _icon,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                SizedBox(width: context.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: context.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            amount,
                            style: context.bodyLarge.copyWith(
                              fontWeight: FontWeight.w900,
                              color: context.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: context.bodySmall.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            FontAwesomeIcons.clock,
                            size: 10,
                            color: Theme.of(context).hintColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            date,
                            style: context.bodySmall.copyWith(
                              fontSize: 10,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.spacingM,
              vertical: context.spacingS,
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: 'Decline',
                    variant: AppButtonVariant.danger,
                    size: AppButtonSize.small,
                    onPressed: onDecline,
                  ),
                ),
                SizedBox(width: context.spacingM),
                Expanded(
                  child: AppButton(
                    text: 'Approve',
                    size: AppButtonSize.small,
                    onPressed: onApprove,
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

extension on BuildContext {
  Color get dividerColor => Theme.of(this).dividerColor;
}
