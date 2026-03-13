import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/number_format.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/services/activity_log_service.dart';

import '../../deliveries/data/services/delivery_service.dart';
import '../data/models/payment.dart';
import '../data/services/payment_service.dart';
import '../../../core/utils/currency_input_formatter.dart';
import '../../inventory/data/models/supplier.dart';
import '../../inventory/data/models/crate_group.dart';
import '../../inventory/data/services/supplier_service.dart';

class AddPaymentSheet extends StatefulWidget {
  const AddPaymentSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddPaymentSheet(),
    );
  }

  @override
  State<AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<AddPaymentSheet> {
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _supplierCtrl = TextEditingController(); // To hold the typed name
  final _formKey = GlobalKey<FormState>();

  String _paymentMethod = 'Cash';
  DateTime _selectedDate = DateTime.now();
  String? _selectedDeliveryId;
  Supplier? _selectedSupplier;

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _cardBg => _isDark ? dCard : lCard;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    _supplierCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: _isDark
                ? const ColorScheme.dark(primary: blueMain, surface: dSurface)
                : const ColorScheme.light(primary: blueMain, surface: lSurface),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final typedName = _supplierCtrl.text.trim();
    if (typedName.isEmpty) return;

    // Check if supplier exists.
    Supplier? finalSupplier = _selectedSupplier;
    if (finalSupplier == null ||
        finalSupplier.name.toLowerCase() != typedName.toLowerCase()) {
      final existing = supplierService.getAll().where(
        (s) => s.name.toLowerCase() == typedName.toLowerCase(),
      );
      if (existing.isNotEmpty) {
        finalSupplier = existing.first;
      } else {
        // Show dialog
        final create = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _surface,
            title: Text(
              'New Supplier',
              style: TextStyle(color: _text, fontWeight: FontWeight.bold),
            ),
            content: Text(
              '$typedName is not an existing supplier. Do you want to add them and record this payment?',
              style: TextStyle(color: _subtext),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: TextStyle(color: _subtext)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: blueMain,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
        if (create != true) return; // User cancelled

        finalSupplier = Supplier(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: typedName,
          crateGroup: CrateGroup.nbPlc, // Default or pick based on name?
        );
        supplierService.addSupplier(finalSupplier); // Adds to memory
      }
    }

    final amount = parseCurrency(_amountCtrl.text);

    final payment = Payment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      supplierId: finalSupplier.id,
      supplierName: finalSupplier.name,
      amount: amount,
      paymentMethod: _paymentMethod,
      referenceNumber: _refCtrl.text.isEmpty ? null : _refCtrl.text,
      notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
      deliveryId: _selectedDeliveryId,
      date: _selectedDate,
      createdAt: DateTime.now(),
    );

    // Write to the payments ledger
    paymentService.addPayment(payment);

    // Update the specific supplier's balance (no interaction with Customers)
    finalSupplier.amountPaid += amount;
    finalSupplier.supplierWallet -= amount;

    activityLogService.logAction(
      'Supplier Payment Recorded',
      'Payment of ${formatCurrency(amount)} to ${finalSupplier.name} via $_paymentMethod',
      relatedEntityId: payment.id,
      relatedEntityType: 'payment',
    );

    if (mounted) Navigator.pop(context);
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _subtext),
      filled: true,
      fillColor: _cardBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: blueMain, width: 2),
      ),
      contentPadding: EdgeInsets.all(context.getRSize(16)),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.getRSize(8)),
      child: Text(
        text,
        style: TextStyle(
          fontSize: context.getRFontSize(12),
          fontWeight: FontWeight.w700,
          color: _subtext,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recentDeliveries = deliveryService.getAll().take(10).toList();

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
                color: _surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Handle & Header
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.getRSize(20),
                        context.getRSize(12),
                        context.getRSize(20),
                        0,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: context.getRSize(40),
                            height: context.getRSize(4),
                            decoration: BoxDecoration(
                              color: _border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          SizedBox(height: context.getRSize(20)),
                          Row(
                            children: [
                              Container(
                                width: context.getRSize(44),
                                height: context.getRSize(44),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [blueLight, blueMain],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
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
                                  FontAwesomeIcons.moneyBillTransfer,
                                  color: Colors.white,
                                  size: context.getRSize(20),
                                ),
                              ),
                              SizedBox(width: context.getRSize(14)),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Record Payment',
                                    style: TextStyle(
                                      fontSize: context.getRFontSize(18),
                                      fontWeight: FontWeight.w800,
                                      color: _text,
                                    ),
                                  ),
                                  Text(
                                    'Log outgoing funds',
                                    style: TextStyle(
                                      fontSize: context.getRFontSize(13),
                                      color: blueMain,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: context.getRSize(10)),
                        ],
                      ),
                    ),

                    // Scrollable Content
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.symmetric(
                          horizontal: context.getRSize(20),
                          vertical: context.getRSize(10),
                        ),
                        children: [
                          // Supplier Autocomplete
                          _buildLabel('Supplier Name'),
                          Autocomplete<Supplier>(
                            displayStringForOption: (item) => item.name,
                            optionsBuilder:
                                (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return const Iterable<Supplier>.empty();
                              }
                              return supplierService
                                  .getAll()
                                  .where((Supplier s) {
                                    return s.name.toLowerCase().contains(
                                      textEditingValue.text.toLowerCase(),
                                    );
                                  });
                            },
                            onSelected: (Supplier selection) {
                              _selectedSupplier = selection;
                              _supplierCtrl.text = selection.name;
                            },
                            fieldViewBuilder: (
                              context,
                              controller,
                              focusNode,
                              onEditingComplete,
                            ) {
                              // Sync internal controller text to the parameter requested field view
                              if (controller.text != _supplierCtrl.text &&
                                  focusNode.hasFocus == false) {
                                controller.text = _supplierCtrl.text;
                              }
                              controller.addListener(() {
                                _supplierCtrl.text = controller.text;
                              });
                              return TextFormField(
                                controller: controller,
                                focusNode: focusNode,
                                onEditingComplete: onEditingComplete,
                                style: TextStyle(
                                  fontSize: context.getRFontSize(14),
                                  fontWeight: FontWeight.bold,
                                  color: _text,
                                ),
                                decoration: _inputDeco(
                                  'Start typing supplier name...',
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Supplier is required'
                                    : null,
                              );
                            },
                          ),
                          SizedBox(height: context.getRSize(16)),

                          // Amount
                          _buildLabel('Amount'),
                          TextFormField(
                            controller: _amountCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [CurrencyInputFormatter()],
                            style: TextStyle(
                              fontSize: context.getRFontSize(14),
                              fontWeight: FontWeight.bold,
                              color: _text,
                            ),
                            decoration: _inputDeco('0.00'),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Amount is required'
                                : null,
                          ),
                          SizedBox(height: context.getRSize(16)),

                          // Payment Method
                          _buildLabel('Payment Method'),
                          DropdownButton<String>(
                            value: _paymentMethod,
                            isExpanded: true,
                            alignment: AlignmentDirectional.bottomStart,
                            menuMaxHeight: 350,
                            borderRadius: BorderRadius.circular(12),
                            underline: const SizedBox(),
                            items: ['Cash', 'Transfer', 'Cheque', 'POS']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      style: TextStyle(color: _text),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _paymentMethod = val);
                              }
                            },
                            dropdownColor: _surface,
                          ),
                          SizedBox(height: context.getRSize(16)),

                          // Date Field
                          _buildLabel('Date'),
                          InkWell(
                            onTap: _pickDate,
                            child: Container(
                              padding: EdgeInsets.all(context.getRSize(16)),
                              decoration: BoxDecoration(
                                color: _cardBg,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('MMM d, y').format(
                                      _selectedDate,
                                    ),
                                    style: TextStyle(
                                      fontSize: context.getRFontSize(14),
                                      fontWeight: FontWeight.bold,
                                      color: _text,
                                    ),
                                  ),
                                  Icon(
                                    FontAwesomeIcons.calendar,
                                    size: context.getRSize(16),
                                    color: _subtext,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: context.getRSize(16)),

                          // Link to Delivery
                          _buildLabel('Link to Delivery (Optional)'),
                          DropdownButton<String?>(
                            value: _selectedDeliveryId,
                            isExpanded: true,
                            alignment: AlignmentDirectional.bottomStart,
                            menuMaxHeight: 350,
                            borderRadius: BorderRadius.circular(12),
                            underline: const SizedBox(),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  'None',
                                  style: TextStyle(color: _text),
                                ),
                              ),
                              ...recentDeliveries.map((d) {
                                final label =
                                    '${DateFormat('MMM d').format(d.deliveredAt)} - ${d.supplierName}';
                                return DropdownMenuItem<String?>(
                                  value: d.id,
                                  child: Text(
                                    label,
                                    style: TextStyle(color: _text),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (val) =>
                                setState(() => _selectedDeliveryId = val),
                            dropdownColor: _surface,
                          ),
                          SizedBox(height: context.getRSize(16)),

                          // Reference Number
                          _buildLabel('Reference Number (Optional)'),
                          TextFormField(
                            controller: _refCtrl,
                            style: TextStyle(
                              fontSize: context.getRFontSize(14),
                              fontWeight: FontWeight.bold,
                              color: _text,
                            ),
                            decoration: _inputDeco('e.g. TR-20938...'),
                          ),
                          SizedBox(height: context.getRSize(16)),

                          // Notes
                          _buildLabel('Notes (Optional)'),
                          TextFormField(
                            controller: _notesCtrl,
                            maxLines: 3,
                            style: TextStyle(
                              fontSize: context.getRFontSize(14),
                              fontWeight: FontWeight.bold,
                              color: _text,
                            ),
                            decoration: _inputDeco('Add remarks'),
                          ),
                          SizedBox(height: context.getRSize(24)),
                        ],
                      ),
                    ),

                    // Button
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.getRSize(20),
                        context.getRSize(16),
                        context.getRSize(20),
                        context.getRSize(
                          MediaQuery.of(context).padding.bottom + 16,
                        ),
                      ),
                      child: Container(
                        width: double.infinity,
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
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: context.getRSize(16),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _submit,
                          child: Text(
                            'Save Payment',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: context.getRFontSize(15),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
