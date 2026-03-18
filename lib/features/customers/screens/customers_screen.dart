import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/number_format.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../data/models/customer.dart';
import '../data/services/customer_service.dart';
import '../widgets/add_customer_sheet.dart';
import 'customer_detail_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
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
          appBar: _buildAppBar(context, surfaceCol, textCol, borderCol),
          drawer: const AppDrawer(activeRoute: 'customers'),
          body: Column(
            children: [
              Expanded(
                child: ValueListenableBuilder<List<Customer>>(
                  valueListenable: customerService,
                  builder: (context, customers, child) {
                    if (customers.isEmpty) {
                      return const Center(child: Text('No customers found.'));
                    }
                    return ListView.separated(
                      padding: context.rPadding(16).copyWith(
                            bottom: context.getRSize(100),
                          ),
                      itemCount: customers.length,
                      separatorBuilder: (context, index) =>
                          SizedBox(height: context.getRSize(12)),
                      itemBuilder: (context, index) {
                        return _buildCustomerCard(
                          context,
                          customers[index],
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
              ),
            ],
          ),
          floatingActionButton: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [blueLight, blueDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: blueMain.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton.extended(
              heroTag: 'customers_fab',
              onPressed: () => AddCustomerSheet.show(context),
              backgroundColor: Colors.transparent,
              elevation: 0,
              icon: Icon(
                FontAwesomeIcons.userPlus,
                size: context.getRSize(16),
                color: Colors.white,
              ),
              label: Text(
                'Add New Customer',
                style: TextStyle(
                  fontSize: context.getRFontSize(15),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    Color surfaceCol,
    Color textCol,
    Color borderCol,
  ) {
    return AppBar(
      backgroundColor: surfaceCol,
      elevation: 0,
      actions: [
        const NotificationBell(),
        SizedBox(width: context.getRSize(8)),
      ],
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
              gradient: const LinearGradient(colors: [blueLight, blueMain]),
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
              FontAwesomeIcons.users,
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
                    'Customers',
                    style: TextStyle(
                      fontSize: context.getRFontSize(18),
                      fontWeight: FontWeight.w800,
                      color: textCol,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Text(
                  'Client Management',
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
    );
  }

  Widget _buildCustomerCard(
    BuildContext context,
    Customer customer,
    Color cardCol,
    Color surfaceCol,
    Color textCol,
    Color subtextCol,
    Color borderCol,
  ) {
    final balanceKobo = customer.walletBalanceKobo;
    final isNegative = balanceKobo < 0;
    final balanceColor = isNegative ? danger : success;
    final formattedBalance = formatCurrency(balanceKobo / 100.0);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerDetailScreen(customerId: customer.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(context.getRSize(16)),
      child: Container(
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: context.getRSize(24),
                backgroundColor: blueMain.withValues(alpha: 0.1),
                child: Text(
                  customer.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: blueMain,
                    fontWeight: FontWeight.bold,
                    fontSize: context.getRFontSize(18),
                  ),
                ),
              ),
              SizedBox(width: context.getRSize(16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: context.getRFontSize(16),
                        color: textCol,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: context.getRSize(4)),
                    Text(
                      customer.addressText,
                      style: TextStyle(
                        fontSize: context.getRFontSize(13),
                        color: subtextCol,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: context.getRSize(6)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.getRSize(8),
                        vertical: context.getRSize(2),
                      ),
                      decoration: BoxDecoration(
                        color: blueMain.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: blueMain.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        customer.customerGroup.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: context.getRFontSize(9),
                          fontWeight: FontWeight.w800,
                          color: blueMain,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: context.getRSize(12)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Balance',
                    style: TextStyle(
                      fontSize: context.getRFontSize(11),
                      color: subtextCol,
                    ),
                  ),
                  SizedBox(height: context.getRSize(2)),
                  Text(
                    formattedBalance,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: context.getRFontSize(16),
                      color: balanceColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

