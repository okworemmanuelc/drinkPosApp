import 'package:flutter/material.dart';
import 'package:reebaplus_pos/core/theme/design_tokens.dart';
import 'package:reebaplus_pos/shared/widgets/shared_scaffold.dart';

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
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(context.spacingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Theme.of(context).hintColor,
              ),
              SizedBox(height: context.spacingM),
              Text(
                'No pending requests',
                style: context.h3.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
              SizedBox(height: context.spacingS),
              Text(
                'Approval requests from staff will appear here.',
                style: context.bodySmall.copyWith(
                  color: Theme.of(context).hintColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
