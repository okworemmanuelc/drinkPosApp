import 'dart:async';
import 'package:drift/drift.dart' show innerJoin;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/providers/app_providers.dart';
import 'package:reebaplus_pos/core/theme/app_decorations.dart';
import 'package:reebaplus_pos/core/theme/colors.dart';
import 'package:reebaplus_pos/core/utils/number_format.dart';
import 'package:reebaplus_pos/core/utils/responsive.dart';
import 'package:reebaplus_pos/core/widgets/amber_button.dart';
import 'package:reebaplus_pos/core/widgets/status_badge.dart';
import 'package:reebaplus_pos/features/customers/data/models/customer.dart';
import 'package:reebaplus_pos/shared/widgets/receipt_widget.dart';
import 'package:reebaplus_pos/shared/widgets/shimmer_loading.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final Customer? customer;

  const CustomerDetailScreen({super.key, this.customer});

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  bool _contentReady = false;

  CustomerData? _customerData;
  int _walletBalance = 0;
  List<WalletTransactionData> _walletHistory = [];
  List<OrderData> _orders = [];
  List<CrateBalanceEntry> _crateBalances = [];

  StreamSubscription<CustomerData?>? _customerSub;
  StreamSubscription<int>? _balanceSub;
  StreamSubscription<List<WalletTransactionData>>? _historySub;
  StreamSubscription<List<OrderData>>? _ordersSub;
  StreamSubscription<List<CrateBalanceEntry>>? _cratesSub;

  @override
  void initState() {
    super.initState();
    if (widget.customer != null) {
      _walletBalance = widget.customer!.walletBalanceKobo;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    if (!mounted) return;
    final id = widget.customer?.id;
    if (id == null || id < 0) {
      setState(() => _contentReady = true);
      return;
    }

    final db = ref.read(databaseProvider);

    _customerSub = db.customersDao.watchCustomerById(id).listen((data) {
      if (mounted) setState(() => _customerData = data);
    });

    _balanceSub = db.customersDao.watchWalletBalance(id).listen((bal) {
      if (mounted) setState(() => _walletBalance = bal);
    });

    _historySub = db.customersDao.watchWalletHistory(id).listen((hist) {
      if (mounted) setState(() => _walletHistory = hist);
    });

    _ordersSub = db.ordersDao.watchOrdersByCustomer(id).listen((orders) {
      if (mounted) setState(() => _orders = orders);
    });

    _cratesSub = db.customersDao.watchCrateBalancesWithGroups(id).listen((
      crates,
    ) {
      if (mounted) setState(() => _crateBalances = crates);
    });

    // Artificial delay to show shimmers
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _contentReady = true);
    });
  }

  @override
  void dispose() {
    _customerSub?.cancel();
    _balanceSub?.cancel();
    _historySub?.cancel();
    _ordersSub?.cancel();
    _cratesSub?.cancel();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _name => _customerData?.name ?? widget.customer?.name ?? '?';
  String get _phone => _customerData?.phone ?? widget.customer?.phone ?? '';
  String get _address =>
      _customerData?.address ?? widget.customer?.addressText ?? '';
  String get _groupName =>
      _customerData?.customerGroup ??
      widget.customer?.customerGroup.name ??
      'retailer';
  DateTime get _joinedAt =>
      _customerData?.createdAt ?? widget.customer?.createdAt ?? DateTime.now();
  int get _limitKobo =>
      _customerData?.walletLimitKobo ?? widget.customer?.walletLimitKobo ?? 0;
  int? get _customerId => widget.customer?.id;

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String _friendlyRefType(String ref) {
    switch (ref) {
      case 'topup_cash':
        return 'Cash top-up';
      case 'topup_transfer':
        return 'Transfer top-up';
      case 'order_payment':
        return 'Order charge';
      case 'cash_received':
        return 'Cash received';
      case 'refund':
        return 'Refund';
      case 'reward':
        return 'Reward';
      case 'fee':
        return 'Fee';
      default:
        return ref;
    }
  }

  BadgeVariant _orderStatusVariant(String status) {
    switch (status) {
      case 'completed':
        return BadgeVariant.green;
      case 'cancelled':
      case 'refunded':
        return BadgeVariant.red;
      default:
        return BadgeVariant.amber;
    }
  }

  // ── Sheets ─────────────────────────────────────────────────────────────────

  void _showAddFundsSheet() {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SheetContainer(
        scrollController: ScrollController(),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHandle(),
              Text(
                'Add Funds',
                style: TextStyle(
                  fontSize: ctx.getRFontSize(18),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: ctx.getRSize(4)),
              Text(
                'Top up $_name\'s wallet',
                style: TextStyle(
                  fontSize: ctx.getRFontSize(13),
                  color: Theme.of(ctx).colorScheme.onSurface.withAlpha(128),
                ),
              ),
              SizedBox(height: ctx.getRSize(24)),
              _SheetField(
                controller: amountCtrl,
                label: 'Amount (₦)',
                keyboard: TextInputType.number,
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              SizedBox(height: ctx.getRSize(16)),
              _SheetField(
                controller: noteCtrl,
                label: 'Note (optional)',
                keyboard: TextInputType.text,
              ),
              SizedBox(height: ctx.getRSize(24)),
              AmberButton(
                label: 'Add Funds',
                icon: Icons.add,
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final amount = double.parse(amountCtrl.text.trim());
                  final note = noteCtrl.text.trim().isEmpty
                      ? 'Manual top-up'
                      : noteCtrl.text.trim();
                  final id = _customerId;
                  if (id == null) return;
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);

                  await ref.read(customerServiceProvider).updateWalletBalance(id, amount, note);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        '₦${amount.toStringAsFixed(0)} added to wallet',
                      ),
                      backgroundColor: successGreen,
                    ),
                  );
                },
              ),
              SizedBox(
                height: MediaQuery.of(ctx).viewInsets.bottom + ctx.getRSize(16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSetLimitSheet() {
    final limitCtrl = TextEditingController(
      text: _limitKobo > 0 ? (_limitKobo / 100).toStringAsFixed(0) : '',
    );
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SheetContainer(
        scrollController: ScrollController(),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHandle(),
              Text(
                'Set Debt Limit',
                style: TextStyle(
                  fontSize: ctx.getRFontSize(20),
                  fontWeight: FontWeight.w800,
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: ctx.getRSize(4)),
              Text(
                'Maximum credit allowed for $_name',
                style: TextStyle(
                  fontSize: ctx.getRFontSize(13),
                  color: Theme.of(ctx).colorScheme.onSurface.withAlpha(128),
                ),
              ),
              SizedBox(height: ctx.getRSize(24)),
              _SheetField(
                controller: limitCtrl,
                label: 'Limit Amount (₦)',
                keyboard: TextInputType.number,
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n < 0) {
                    return 'Enter a valid amount (0 to remove limit)';
                  }
                  return null;
                },
              ),
              SizedBox(height: ctx.getRSize(24)),
              AmberButton(
                label: 'Save Limit',
                icon: Icons.check,
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final amount = double.parse(limitCtrl.text.trim());
                  final id = _customerId;
                  if (id == null) return;
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  await ref.read(customerServiceProvider).updateWalletLimit(id, amount);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Debt limit set to ${formatCurrency(amount)}',
                      ),
                      backgroundColor: successGreen,
                    ),
                  );
                },
              ),
              SizedBox(
                height: MediaQuery.of(ctx).viewInsets.bottom + ctx.getRSize(16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReceipt(OrderData order) async {
    final db = ref.read(databaseProvider);
    final itemRows = await (db.select(db.orderItems).join([
      innerJoin(
        db.products,
        db.products.id.equalsExp(db.orderItems.productId),
      ),
    ])..where(db.orderItems.orderId.equals(order.id))).get();

    final items = itemRows.map((row) {
      final p = row.readTable(db.products);
      final i = row.readTable(db.orderItems);
      return {
        'name': p.name,
        'qty': i.quantity.toDouble(),
        'price': i.unitPriceKobo / 100.0,
        'manufacturerId': p.manufacturerId,
        'crateGroupId': p.crateGroupId,
        'emptyCrateValueKobo': p.emptyCrateValueKobo,
      };
    }).toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReceiptWidget(
        orderId: order.orderNumber,
        cart: items,
        subtotal: (order.totalAmountKobo - order.crateDepositPaidKobo) / 100.0,
        crateDeposit: order.crateDepositPaidKobo / 100.0,
        total: order.totalAmountKobo / 100.0,
        paymentMethod: order.paymentType,
        customerName: _name,
        customerPhone: _phone,
        customerAddress: _address,
        orderStatus: order.status[0].toUpperCase() + order.status.substring(1),
        riderName: order.riderName,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: context.getRSize(20),
              color: theme.colorScheme.onSurface,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Customer Profile',
            style: TextStyle(
              fontSize: context.getRFontSize(18),
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            _loadData();
            await Future.delayed(const Duration(milliseconds: 500));
          },
          color: amberPrimary,
          child: _contentReady ? _buildContent(theme) : _buildShimmer(theme),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(child: _buildHeader(theme)),
          SliverToBoxAdapter(child: _buildWalletCard(theme)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              child: Container(
                color: theme.scaffoldBackgroundColor,
                padding: EdgeInsets.symmetric(horizontal: context.getRSize(20)),
                child: _buildTabBar(theme),
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        children: [
          _buildWalletHistoryTab(theme),
          _buildOrdersTab(theme),
          _buildCratesTab(theme),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(ThemeData theme) {
    final isWholesaler = _groupName == 'wholesaler';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.getRSize(20),
        context.getRSize(4),
        context.getRSize(20),
        context.getRSize(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: context.getRSize(60),
            height: context.getRSize(60),
            decoration: AppDecorations.amberGradient(radius: 30),
            child: Center(
              child: Text(
                _initials(_name),
                style: TextStyle(
                  fontSize: context.getRFontSize(22),
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          SizedBox(width: context.getRSize(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _name,
                        style: TextStyle(
                          fontSize: context.getRFontSize(18),
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    SizedBox(width: context.getRSize(8)),
                    StatusBadge(
                      label: isWholesaler ? 'Wholesaler' : 'Retailer',
                      variant: isWholesaler
                          ? BadgeVariant.green
                          : BadgeVariant.amber,
                    ),
                  ],
                ),
                if (_phone.isNotEmpty) ...[
                  SizedBox(height: context.getRSize(6)),
                  _InfoRow(
                    icon: FontAwesomeIcons.phone,
                    text: _phone,
                    theme: theme,
                  ),
                ],
                if (_address.isNotEmpty && _address != 'N/A') ...[
                  SizedBox(height: context.getRSize(4)),
                  _InfoRow(
                    icon: FontAwesomeIcons.locationDot,
                    text: _address,
                    theme: theme,
                  ),
                ],
                SizedBox(height: context.getRSize(4)),
                _InfoRow(
                  icon: FontAwesomeIcons.calendarCheck,
                  text: 'Since ${DateFormat('MMM yyyy').format(_joinedAt)}',
                  theme: theme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Wallet Card ─────────────────────────────────────────────────────────────

  Widget _buildWalletCard(ThemeData theme) {
    final balance = _walletBalance / 100.0;
    final limit = _limitKobo / 100.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.getRSize(20)),
      child: Container(
        padding: EdgeInsets.all(context.getRSize(18)),
        decoration: AppDecorations.surfaceCard(context, radius: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  FontAwesomeIcons.wallet,
                  size: context.getRSize(14),
                  color: amberPrimary,
                ),
                SizedBox(width: context.getRSize(8)),
                Text(
                  'Wallet Balance',
                  style: TextStyle(
                    fontSize: context.getRFontSize(12),
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withAlpha(128),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.getRSize(6)),
            Text(
              formatCurrency(balance),
              style: TextStyle(
                fontSize: context.getRFontSize(28),
                fontWeight: FontWeight.w900,
                color: balance >= 0 ? theme.colorScheme.onSurface : dangerRed,
                letterSpacing: -1,
              ),
            ),
            SizedBox(height: context.getRSize(4)),
            Row(
              children: [
                Icon(
                  FontAwesomeIcons.creditCard,
                  size: context.getRSize(12),
                  color: theme.colorScheme.onSurface.withAlpha(102),
                ),
                SizedBox(width: context.getRSize(6)),
                Text(
                  limit > 0
                      ? 'Debt limit: ${formatCurrency(limit)}'
                      : 'No debt limit set',
                  style: TextStyle(
                    fontSize: context.getRFontSize(12),
                    color: theme.colorScheme.onSurface.withAlpha(128),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.getRSize(14)),
            Row(
              children: [
                Expanded(
                  child: AmberButton(
                    label: 'Add Funds',
                    icon: FontAwesomeIcons.plus,
                    height: 42,
                    onPressed: _showAddFundsSheet,
                  ),
                ),
                SizedBox(width: context.getRSize(10)),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showSetLimitSheet,
                    icon: Icon(
                      FontAwesomeIcons.penToSquare,
                      size: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                    label: Text(
                      'Set Limit',
                      style: TextStyle(
                        fontSize: context.getRFontSize(14),
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(0, context.getRSize(42)),
                      side: BorderSide(color: theme.dividerColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab Bar ─────────────────────────────────────────────────────────────────

  Widget _buildTabBar(ThemeData theme) {
    return TabBar(
      labelColor: amberPrimary,
      unselectedLabelColor: theme.colorScheme.onSurface.withAlpha(115),
      indicatorColor: amberPrimary,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: TextStyle(
        fontSize: context.getRFontSize(13),
        fontWeight: FontWeight.w700,
      ),
      tabs: const [
        Tab(
          icon: Icon(FontAwesomeIcons.clockRotateLeft, size: 16),
          text: 'Wallet',
        ),
        Tab(icon: Icon(FontAwesomeIcons.fileLines, size: 16), text: 'Orders'),
        Tab(icon: Icon(FontAwesomeIcons.boxOpen, size: 16), text: 'Crates'),
      ],
    );
  }

  // ── Tab: Wallet History ─────────────────────────────────────────────────────

  Widget _buildWalletHistoryTab(ThemeData theme) {
    if (_walletHistory.isEmpty) {
      return _EmptyState(
        icon: FontAwesomeIcons.hourglass,
        message: 'No wallet transactions yet',
        theme: theme,
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        context.getRSize(20),
        context.getRSize(12),
        context.getRSize(20),
        context.getRSize(20),
      ),
      itemCount: _walletHistory.length,
      itemBuilder: (ctx, i) {
        final txn = _walletHistory[i];
        final isCredit = txn.type == 'credit';
        final amount = txn.amountKobo / 100.0;
        final color = isCredit ? successGreen : dangerRed;
        return Padding(
          padding: EdgeInsets.only(bottom: ctx.getRSize(10)),
          child: Container(
            padding: EdgeInsets.all(ctx.getRSize(14)),
            decoration: AppDecorations.surfaceCard(ctx, radius: 12),
            child: Row(
              children: [
                Container(
                  width: ctx.getRSize(38),
                  height: ctx.getRSize(38),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCredit
                        ? FontAwesomeIcons.arrowDown
                        : FontAwesomeIcons.arrowUp,
                    color: color,
                    size: ctx.getRSize(16),
                  ),
                ),
                SizedBox(width: ctx.getRSize(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _friendlyRefType(txn.referenceType),
                        style: TextStyle(
                          fontSize: ctx.getRFontSize(14),
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        DateFormat('d MMM yyyy, h:mm a').format(txn.createdAt),
                        style: TextStyle(
                          fontSize: ctx.getRFontSize(11),
                          color: theme.colorScheme.onSurface.withAlpha(115),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isCredit ? '+' : '-'}${formatCurrency(amount)}',
                  style: TextStyle(
                    fontSize: ctx.getRFontSize(15),
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Tab: Orders ─────────────────────────────────────────────────────────────

  Widget _buildOrdersTab(ThemeData theme) {
    if (_orders.isEmpty) {
      return _EmptyState(
        icon: FontAwesomeIcons.receipt,
        message: 'No orders placed yet',
        theme: theme,
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        context.getRSize(20),
        context.getRSize(12),
        context.getRSize(20),
        context.getRSize(20),
      ),
      itemCount: _orders.length,
      itemBuilder: (ctx, i) {
        final order = _orders[i];
        final total = order.totalAmountKobo / 100.0;
        return Padding(
          padding: EdgeInsets.only(bottom: ctx.getRSize(10)),
          child: InkWell(
            onTap: () => _showReceipt(order),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.all(ctx.getRSize(14)),
              decoration: AppDecorations.surfaceCard(ctx, radius: 12),
              child: Row(
                children: [
                  Container(
                    width: ctx.getRSize(38),
                    height: ctx.getRSize(38),
                    decoration: BoxDecoration(
                      color: amberPrimary.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      FontAwesomeIcons.receipt,
                      color: amberPrimary,
                      size: ctx.getRSize(16),
                    ),
                  ),
                  SizedBox(width: ctx.getRSize(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${order.orderNumber}',
                          style: TextStyle(
                            fontSize: ctx.getRFontSize(14),
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          DateFormat('d MMM yyyy').format(order.createdAt),
                          style: TextStyle(
                            fontSize: ctx.getRFontSize(11),
                            color: theme.colorScheme.onSurface.withAlpha(115),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatCurrency(total),
                        style: TextStyle(
                          fontSize: ctx.getRFontSize(14),
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: ctx.getRSize(4)),
                      StatusBadge(
                        label:
                            order.status[0].toUpperCase() +
                            order.status.substring(1),
                        variant: _orderStatusVariant(order.status),
                        fontSize: 10,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Tab: Crates ─────────────────────────────────────────────────────────────

  Widget _buildCratesTab(ThemeData theme) {
    if (_crateBalances.isEmpty) {
      return _EmptyState(
        icon: FontAwesomeIcons.boxesStacked,
        message: 'No crate activity recorded',
        theme: theme,
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        context.getRSize(20),
        context.getRSize(12),
        context.getRSize(20),
        context.getRSize(20),
      ),
      itemCount: _crateBalances.length,
      itemBuilder: (ctx, i) {
        final entry = _crateBalances[i];
        final bal = entry.balance;
        final isOwe = bal > 0;
        final isClear = bal == 0;
        final color = isClear
            ? theme.colorScheme.onSurface.withAlpha(102)
            : isOwe
            ? amberPrimary
            : successGreen;
        final label = isClear
            ? 'Clear'
            : isOwe
            ? '${bal.abs()} crates owed'
            : '${bal.abs()} crates credit';
        return Padding(
          padding: EdgeInsets.only(bottom: ctx.getRSize(10)),
          child: Container(
            padding: EdgeInsets.all(ctx.getRSize(14)),
            decoration: AppDecorations.surfaceCard(ctx, radius: 12),
            child: Row(
              children: [
                Container(
                  width: ctx.getRSize(38),
                  height: ctx.getRSize(38),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    FontAwesomeIcons.boxOpen,
                    color: color,
                    size: ctx.getRSize(16),
                  ),
                ),
                SizedBox(width: ctx.getRSize(12)),
                Expanded(
                  child: Text(
                    entry.groupName,
                    style: TextStyle(
                      fontSize: ctx.getRFontSize(14),
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ctx.getRSize(10),
                    vertical: ctx.getRSize(4),
                  ),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: ctx.getRFontSize(12),
                      fontWeight: FontWeight.w700,
                      color: color,
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

  Widget _buildShimmer(ThemeData theme) {
    return Column(
      children: [
        const ShimmerCustomerProfile(),
        const ShimmerCategoryBar(),
        Expanded(
          child: ListView.builder(
            itemCount: 5,
            padding: EdgeInsets.symmetric(vertical: context.getRSize(12)),
            itemBuilder: (_, __) => const ShimmerListTile(),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final ThemeData theme;
  const _InfoRow({required this.icon, required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: context.getRSize(12),
          color: theme.colorScheme.onSurface.withAlpha(102),
        ),
        SizedBox(width: context.getRSize(6)),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: context.getRFontSize(12),
              color: theme.colorScheme.onSurface.withAlpha(153),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final ThemeData theme;
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: context.getRSize(40),
            color: theme.colorScheme.onSurface.withAlpha(51),
          ),
          SizedBox(height: context.getRSize(12)),
          Text(
            message,
            style: TextStyle(
              fontSize: context.getRFontSize(14),
              color: theme.colorScheme.onSurface.withAlpha(102),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetContainer extends StatelessWidget {
  final ScrollController scrollController;
  final Widget child;
  const _SheetContainer({required this.scrollController, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        context.getRSize(20),
        context.getRSize(12),
        context.getRSize(20),
        context.getRSize(8),
      ),
      child: child,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withAlpha(51),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType keyboard;
  final String? Function(String?)? validator;
  const _SheetField({
    required this.controller,
    required this.label,
    required this.keyboard,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SliverTabBarDelegate({required this.child});

  @override
  double get minExtent => 60;
  @override
  double get maxExtent => 60;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
