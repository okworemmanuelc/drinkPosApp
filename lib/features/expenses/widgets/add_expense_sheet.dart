import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/number_format.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/services/activity_log_service.dart';
import '../../../core/utils/currency_input_formatter.dart';
import '../data/models/expense.dart';
import '../data/services/expense_service.dart';
import '../../../shared/services/auth_service.dart';
import '../../../core/utils/constants.dart';
import 'package:file_picker/file_picker.dart';

class AddExpenseSheet extends StatefulWidget {
  const AddExpenseSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddExpenseSheet(),
    );
  }

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    final amt = parseCurrency(_amountCtrl.text);
    if (amt != _currentAmount) {
      setState(() => _currentAmount = amt);
    }
  }

  Future<void> _pickReceipt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'pdf'],
    );

    if (result != null) {
      setState(() => _receiptFile = result.files.first);
    }
  }

  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _recordedByCtrl = TextEditingController(text: authService.currentUser?.name ?? 'Admin');
  final _formKey = GlobalKey<FormState>();

  PlatformFile? _receiptFile;
  double _currentAmount = 0;

  String _paymentMethod = 'Cash';
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Fuel';

  final List<String> _categories = [
    'Fuel',
    'Salary',
    'Rent',
    'Maintenance',
    'Utilities',
    'Supplies',
    'Others',
  ];

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _cardBg => _isDark ? dCard : lCard;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _refCtrl.dispose();
    _recordedByCtrl.dispose();
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
                ? const ColorScheme.dark(primary: danger, surface: dSurface)
                : const ColorScheme.light(primary: danger, surface: lSurface),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final amount = parseCurrency(_amountCtrl.text);
    final isOthers = _selectedCategory == 'Others';
    final desc = _descCtrl.text.trim();

    if (isOthers && desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Description is required for "Others" category.'),
          backgroundColor: danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final needsReceipt = amount >= largeExpenseThreshold;
    if (needsReceipt && _receiptFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Receipt upload is required for expenses of 20,000 and above.'),
          backgroundColor: danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final expense = Expense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      category: _selectedCategory,
      amount: amount,
      paymentMethod: _paymentMethod,
      description: desc.isEmpty ? null : desc,
      date: _selectedDate,
      createdAt: DateTime.now(),
      recordedBy: _recordedByCtrl.text.trim(),
      reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      receiptPath: _receiptFile?.name,
    );

    expenseService.addExpense(expense);

    activityLogService.logAction(
      'Expense Recorded',
      'Logged $_selectedCategory expense of ${formatCurrency(amount)} via $_paymentMethod',
      relatedEntityId: expense.id,
      relatedEntityType: 'expense',
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
        borderSide: const BorderSide(color: danger, width: 2),
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
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const [0.5, 0.9],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                              gradient: LinearGradient(
                                colors: [danger.withValues(alpha: 0.8), danger],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: danger.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              FontAwesomeIcons.fileInvoiceDollar,
                              color: Colors.white,
                              size: context.getRSize(20),
                            ),
                          ),
                          SizedBox(width: context.getRSize(14)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Record Expense',
                                style: TextStyle(
                                  fontSize: context.getRFontSize(18),
                                  fontWeight: FontWeight.w800,
                                  color: _text,
                                ),
                              ),
                              Text(
                                'Log operating costs',
                                style: TextStyle(
                                  fontSize: context.getRFontSize(13),
                                  color: danger,
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
                      // Categories
                      _buildLabel('Category'),
                      Wrap(
                        spacing: context.getRSize(8),
                        runSpacing: context.getRSize(8),
                        children: _categories.map((cat) {
                          final isSelected = _selectedCategory == cat;
                          return ChoiceChip(
                            label: Text(
                              cat,
                              style: TextStyle(
                                fontSize: context.getRFontSize(12),
                                color: isSelected ? Colors.white : _text,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) setState(() => _selectedCategory = cat);
                            },
                            selectedColor: danger,
                            backgroundColor: _cardBg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.transparent
                                    : _border,
                              ),
                            ),
                            showCheckmark: false,
                          );
                        }).toList(),
                      ),
                      SizedBox(height: context.getRSize(20)),

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
                        underline: const SizedBox(),
                        items: ['Cash', 'Transfer', 'POS', 'Credit']
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(e, style: TextStyle(color: _text)),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _paymentMethod = val);
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('MMM d, y').format(_selectedDate),
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

                      // Description
                      _buildLabel(
                        'Description ${_selectedCategory == "Others" ? "(Required)" : "(Optional)"}',
                      ),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: context.getRFontSize(14),
                          fontWeight: FontWeight.bold,
                          color: _text,
                        ),
                        decoration: _inputDeco('What was this expense for?'),
                      ),
                      SizedBox(height: context.getRSize(16)),

                      // Reference
                      _buildLabel('Reference / Receipt No. (Optional)'),
                      TextFormField(
                        controller: _refCtrl,
                        style: TextStyle(
                          fontSize: context.getRFontSize(14),
                          fontWeight: FontWeight.bold,
                          color: _text,
                        ),
                        decoration: _inputDeco('e.g. REC-0912...'),
                      ),
                      SizedBox(height: context.getRSize(16)),

                      // Receipt Upload (Large Expenses)
                      if (_currentAmount >= largeExpenseThreshold) ...[
                        _buildLabel('Receipt (Required for large expenses)'),
                        InkWell(
                          onTap: _pickReceipt,
                          child: Container(
                            padding: EdgeInsets.all(context.getRSize(16)),
                            decoration: BoxDecoration(
                              color: _cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _receiptFile == null ? danger.withValues(alpha: 0.5) : success,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _receiptFile == null
                                      ? FontAwesomeIcons.fileArrowUp
                                      : FontAwesomeIcons.fileCircleCheck,
                                  size: context.getRSize(18),
                                  color: _receiptFile == null ? danger : success,
                                ),
                                SizedBox(width: context.getRSize(12)),
                                Expanded(
                                  child: Text(
                                    _receiptFile?.name ?? 'Upload Receipt (JPG, PNG, PDF)',
                                    style: TextStyle(
                                      fontSize: context.getRFontSize(14),
                                      fontWeight: FontWeight.bold,
                                      color: _receiptFile == null ? _subtext : _text,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_receiptFile != null)
                                  Icon(
                                    FontAwesomeIcons.check,
                                    size: context.getRSize(14),
                                    color: success,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (_receiptFile == null)
                          Padding(
                            padding: EdgeInsets.only(top: context.getRSize(4), left: context.getRSize(4)),
                            child: Text(
                              'Please upload a receipt to continue',
                              style: TextStyle(color: danger, fontSize: context.getRFontSize(11)),
                            ),
                          ),
                        SizedBox(height: context.getRSize(16)),
                      ],

                      // Recorded By
                      _buildLabel('Recorded By'),
                      TextFormField(
                        controller: _recordedByCtrl,
                        enabled: false,
                        style: TextStyle(
                          fontSize: context.getRFontSize(14),
                          fontWeight: FontWeight.bold,
                          color: _text.withValues(alpha: 0.7),
                        ),
                        decoration: _inputDeco('Name of staff'),
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
                    context.getRSize(MediaQuery.of(context).padding.bottom + 16),
                  ),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [danger.withValues(alpha: 0.8), danger],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: danger.withValues(alpha: 0.3),
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
                        'Save Expense',
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
        );
      },
    );
  }
}
