import 'package:flutter/material.dart';
import 'package:reebaplus_pos/core/utils/notifications.dart';
import 'package:reebaplus_pos/core/theme/design_tokens.dart';
import 'package:reebaplus_pos/shared/widgets/shared_scaffold.dart';
import 'package:reebaplus_pos/features/dashboard/widgets/approval_card.dart';

class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SharedScaffold(
      activeRoute: 'dashboard',
      appBar: AppBar(
        title: Text(
          'Pending Requests',
          style: context.h3.copyWith(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: context.backgroundColor,
        leading: BackButton(color: context.primaryColor),
      ),
      body: ListView(
        padding: EdgeInsets.all(context.spacingM),
        children: [
          _buildSectionHeader(context, 'Critical Approvals'),
          ApprovalCard(
            type: ApprovalType.credit,
            title: 'Credit Limit Increase',
            subtitle: 'Customer: Adamu Musa (Retailer)\nRequested by: Okwor Solomon (Stock Keeper)',
            amount: '₦50,000.00',
            date: '2 minutes ago',
            onApprove: () => _handleApprove(context, 'Credit Limit Increase'),
            onDecline: () => _handleDecline(context, 'Credit Limit Increase'),
          ),
          _buildSectionHeader(context, 'Operational Approvals'),
          ApprovalCard(
            type: ApprovalType.crates,
            title: 'Lower Empty Crates',
            subtitle: 'Warehouse: Pankshin Branch\nCrate Group: Big Crate 12\nReason: Damaged in transit',
            amount: '5 Crates',
            date: '15 minutes ago',
            onApprove: () => _handleApprove(context, 'Lower Empty Crates'),
            onDecline: () => _handleDecline(context, 'Lower Empty Crates'),
          ),
          ApprovalCard(
            type: ApprovalType.transfer,
            title: 'Inter-branch Transfer',
            subtitle: 'From: Keffi Branch\nTo: Pankshin Branch\nProduct: Star Lager Beer',
            amount: '20 Cases',
            date: '1 hour ago',
            onApprove: () => _handleApprove(context, 'Inter-branch Transfer'),
            onDecline: () => _handleDecline(context, 'Inter-branch Transfer'),
          ),
          _buildSectionHeader(context, 'Others'),
          ApprovalCard(
            type: ApprovalType.other,
            title: 'Price Override',
            subtitle: 'Product: Heineken Beer\nRequested by: Grace Dung (Cashier)\nNew Price: ₦1,250.00',
            amount: 'Bulk Order',
            date: '2 hours ago',
            onApprove: () => _handleApprove(context, 'Price Override'),
            onDecline: () => _handleDecline(context, 'Price Override'),
          ),
          SizedBox(height: context.spacingXxl),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacingS, top: context.spacingS),
      child: Text(
        title.toUpperCase(),
        style: context.bodySmall.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Theme.of(context).hintColor,
        ),
      ),
    );
  }

  void _handleApprove(BuildContext context, String title) {
    AppNotification.showSuccess(context, 'Approved: $title');
  }

  void _handleDecline(BuildContext context, String title) {
    AppNotification.showError(context, 'Declined: $title');
  }
}
