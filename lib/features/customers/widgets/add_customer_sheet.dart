import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/responsive.dart';
import '../data/models/customer.dart';
import '../data/services/customer_service.dart';

class AddCustomerSheet extends StatefulWidget {
  const AddCustomerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddCustomerSheet(),
    );
  }

  @override
  State<AddCustomerSheet> createState() => _AddCustomerSheetState();
}

class _AddCustomerSheetState extends State<AddCustomerSheet> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  CustomerGroup _selectedGroup = CustomerGroup.retailer;
  final _formKey = GlobalKey<FormState>();

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _cardBg => _isDark ? dCard : lCard;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _locationCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Widget _inputField(
    String label,
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: context.getRFontSize(12),
            fontWeight: FontWeight.w700,
            color: _subtext,
          ),
        ),
        SizedBox(height: context.getRSize(8)),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: context.getRFontSize(14),
            fontWeight: FontWeight.bold,
            color: _text,
          ),
          decoration: InputDecoration(
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
          ),
          validator: (v) {
            if (required && (v == null || v.trim().isEmpty)) {
              return 'This field is required';
            }
            return null;
          },
        ),
        SizedBox(height: context.getRSize(16)),
      ],
    );
  }

  Widget _groupDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customer Group',
          style: TextStyle(
            fontSize: context.getRFontSize(12),
            fontWeight: FontWeight.w700,
            color: _subtext,
          ),
        ),
        SizedBox(height: context.getRSize(8)),
        Container(
          padding: EdgeInsets.symmetric(horizontal: context.getRSize(16)),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<CustomerGroup>(
              value: _selectedGroup,
              isExpanded: true,
              dropdownColor: _surface,
              icon: Icon(Icons.keyboard_arrow_down, color: blueMain),
              items: CustomerGroup.values.map((group) {
                String label = '';
                switch (group) {
                  case CustomerGroup.distributor:
                    label = 'Distributor';
                    break;
                  case CustomerGroup.bulkBreaker:
                    label = 'Bulk Breaker';
                    break;
                  case CustomerGroup.retailer:
                    label = 'Retailer';
                    break;
                }
                return DropdownMenuItem(
                  value: group,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: context.getRFontSize(14),
                      fontWeight: FontWeight.bold,
                      color: _text,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedGroup = val);
              },
            ),
          ),
        ),
        SizedBox(height: context.getRSize(16)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.getRSize(20),
                  context.getRSize(20),
                  context.getRSize(20),
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: context.getRSize(40),
                        height: context.getRSize(4),
                        decoration: BoxDecoration(
                          color: _border,
                          borderRadius: BorderRadius.circular(2),
                        ),
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
                            FontAwesomeIcons.userPlus,
                            color: Colors.white,
                            size: context.getRSize(20),
                          ),
                        ),
                        SizedBox(width: context.getRSize(14)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add New Customer',
                              style: TextStyle(
                                fontSize: context.getRFontSize(18),
                                fontWeight: FontWeight.w800,
                                color: _text,
                              ),
                            ),
                            Text(
                              'Client Details & Contact',
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
                    SizedBox(height: context.getRSize(24)),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.getRSize(20),
                  ),
                  child: Column(
                    children: [
                      _inputField('Customer Name', _nameCtrl, 'e.g. John Doe'),
                      _groupDropdown(),
                      _inputField(
                        'Address',
                        _addressCtrl,
                        'e.g. 123 Main Street',
                      ),
                      _inputField(
                        'Google Maps Location',
                        _locationCtrl,
                        'e.g. Plus Code or Link',
                      ),
                      _inputField(
                        'Phone Number (Optional)',
                        _phoneCtrl,
                        'e.g. 08012345678',
                        keyboardType: TextInputType.phone,
                        required: false,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.getRSize(20),
                  context.getRSize(16),
                  context.getRSize(20),
                  context.getRSize(32),
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
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final newCustomer = Customer(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: _nameCtrl.text.trim(),
                          addressText: _addressCtrl.text.trim(),
                          googleMapsLocation: _locationCtrl.text.trim(),
                          phone: _phoneCtrl.text.trim().isEmpty
                              ? null
                              : _phoneCtrl.text.trim(),
                          customerGroup: _selectedGroup,
                          isWalkIn: false,
                        );
                        customerService.addCustomer(newCustomer);
                        Navigator.pop(context);
                      }
                    },
                    child: Text(
                      'Save Customer',
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
  }
}
