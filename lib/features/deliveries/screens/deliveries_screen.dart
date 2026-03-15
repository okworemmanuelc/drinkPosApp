import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/number_format.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../data/models/delivery.dart';
import '../data/services/delivery_service.dart';
import '../widgets/receive_delivery_sheet.dart';
import '../../../shared/widgets/notification_bell.dart';

class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key});

  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> {
  String _filter = 'All';

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? dBg : lBg;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, child) {
        return Scaffold(
          backgroundColor: _bg,
          drawer: const AppDrawer(activeRoute: 'deliveries'),
          appBar: _buildAppBar(context),
          body: Column(
            children: [
              _buildFilterChips(context),
              Expanded(
                child: ValueListenableBuilder<List<Delivery>>(
                  valueListenable: deliveryService,
                  builder: (context, deliveries, child) {
                    final filtered = _getFilteredDeliveries(deliveries);

                    if (filtered.isEmpty) {
                      return _buildEmptyState(context);
                    }

                    return _buildDeliveriesList(context, filtered);
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
              heroTag: 'deliveries_fab',
              onPressed: () {
                ReceiveDeliverySheet.show(context);
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              icon: Icon(
                FontAwesomeIcons.truckRampBox,
                size: context.getRSize(16),
                color: Colors.white,
              ),
              label: Text(
                'Receive Delivery',
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

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _surface,
      elevation: 0,
      iconTheme: IconThemeData(color: _text),
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
                    color: _text,
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
                    color: _text,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      title: Text(
        'Deliveries',
        style: TextStyle(
          color: _text,
          fontSize: context.getRFontSize(18),
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        const NotificationBell(),
        SizedBox(width: context.getRSize(8)),
      ],
    );
  }


  Widget _buildFilterChips(BuildContext context) {
    final filters = ['Today', 'This Week', 'This Month', 'This Year', 'All'];
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.symmetric(vertical: context.getRSize(16)),
      height: context.getRSize(64),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: context.getRSize(16)),
        itemCount: filters.length,
        separatorBuilder: (context, index) =>
            SizedBox(width: context.getRSize(8)),
        itemBuilder: (context, index) {
          final f = filters[index];
          final isSelected = f == _filter;
          return FilterChip(
            label: Text(
              f,
              style: TextStyle(
                fontSize: context.getRFontSize(12),
                color: isSelected ? Colors.white : _text,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            selected: isSelected,
            onSelected: (val) {
              setState(() => _filter = f);
            },
            selectedColor: blueMain,
            backgroundColor: _surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? Colors.transparent : _border,
              ),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  List<Delivery> _getFilteredDeliveries(List<Delivery> deliveries) {
    final now = DateTime.now();
    return deliveries.where((d) {
      if (_filter == 'All') return true;
      final diff = now.difference(d.deliveredAt);
      if (_filter == 'Today') {
        return diff.inDays == 0 && now.day == d.deliveredAt.day;
      }
      if (_filter == 'This Week') return diff.inDays <= 7;
      if (_filter == 'This Month') return diff.inDays <= 30;
      if (_filter == 'This Year') return diff.inDays <= 365;
      return true;
    }).toList();
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FontAwesomeIcons.boxOpen,
            size: context.getRSize(48),
            color: _border,
          ),
          SizedBox(height: context.getRSize(16)),
          Text(
            'No deliveries yet',
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

  Widget _buildDeliveriesList(BuildContext context, List<Delivery> deliveries) {
    // Group by supplier
    final Map<String, List<Delivery>> bySupplier = {};
    for (var del in deliveries) {
      bySupplier.putIfAbsent(del.supplierName, () => []).add(del);
    }

    // Convert map to a flat list for ListView with headers
    final List<dynamic> listItems = [];
    bySupplier.forEach((supplier, dels) {
      listItems.add(supplier);
      // Sort within group by date desc
      dels.sort((a, b) => b.deliveredAt.compareTo(a.deliveredAt));
      listItems.addAll(dels);
    });

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        context.getRSize(16),
        0,
        context.getRSize(16),
        context.getRSize(100),
      ),
      itemCount: listItems.length,
      itemBuilder: (context, index) {
        final item = listItems[index];
        if (item is String) {
          // Supplier Header
          return Padding(
            padding: EdgeInsets.only(
              top: index == 0 ? 0 : context.getRSize(16),
              bottom: context.getRSize(8),
              left: context.getRSize(4),
            ),
            child: Text(
              item,
              style: TextStyle(
                color: _subtext,
                fontWeight: FontWeight.bold,
                fontSize: context.getRFontSize(14),
              ),
            ),
          );
        } else if (item is Delivery) {
          return _DeliveryCard(delivery: item);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final Delivery delivery;

  const _DeliveryCard({required this.delivery});

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;
  Color get _cardBg => _isDark ? dCard : lCard;

  @override
  Widget build(BuildContext context) {
    final isPending = delivery.status == 'pending';
    final statusColor = isPending ? const Color(0xFFF59E0B) : success;

    final time = delivery.deliveredAt;
    final isToday =
        time.year == DateTime.now().year &&
        time.month == DateTime.now().month &&
        time.day == DateTime.now().day;
    final dateStr = isToday
        ? 'Today, '
        : '${time.day}/${time.month}/${time.year} ';
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: EdgeInsets.only(bottom: context.getRSize(12)),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(context.getRSize(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      FontAwesomeIcons.truck,
                      size: context.getRSize(14),
                      color: _subtext,
                    ),
                    SizedBox(width: context.getRSize(8)),
                    Text(
                      '$dateStr$timeStr',
                      style: TextStyle(
                        color: _subtext,
                        fontSize: context.getRFontSize(13),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.getRSize(8),
                    vertical: context.getRSize(4),
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    delivery.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: context.getRFontSize(10),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.getRSize(12)),
            Divider(height: 1, color: _border),
            SizedBox(height: context.getRSize(12)),

            // Items Summary
            Text(
              '${delivery.items.length} Product(s)',
              style: TextStyle(
                color: _text,
                fontWeight: FontWeight.bold,
                fontSize: context.getRFontSize(14),
              ),
            ),
            SizedBox(height: context.getRSize(4)),
            ...delivery.items.take(3).map((item) {
              return Padding(
                padding: EdgeInsets.only(bottom: context.getRSize(2)),
                child: Text(
                  '${item.quantity.toInt()}x ${item.productName}',
                  style: TextStyle(
                    color: _subtext,
                    fontSize: context.getRFontSize(13),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
            if (delivery.items.length > 3)
              Text(
                '...and ${delivery.items.length - 3} more',
                style: TextStyle(
                  color: _subtext,
                  fontSize: context.getRFontSize(12),
                  fontStyle: FontStyle.italic,
                ),
              ),

            SizedBox(height: context.getRSize(12)),
            Divider(height: 1, color: _border),
            SizedBox(height: context.getRSize(12)),

            // Total Value
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Value',
                  style: TextStyle(
                    color: _subtext,
                    fontSize: context.getRFontSize(13),
                  ),
                ),
                Text(
                  formatCurrency(delivery.totalValue),
                  style: TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w800,
                    fontSize: context.getRFontSize(15),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

