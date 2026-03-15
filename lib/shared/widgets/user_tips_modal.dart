import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/theme_notifier.dart';
import '../../core/utils/responsive.dart';

class UserTipsModal extends StatefulWidget {
  const UserTipsModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const UserTipsModal(),
    );
  }

  @override
  State<UserTipsModal> createState() => _UserTipsModalState();
}

class _UserTipsModalState extends State<UserTipsModal> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _tips = [
    {
      'title': 'Quick Sale ⚡',
      'description': 'Need to sell something not in your inventory? Use the Quick Sale button on the POS screen to manually enter an item name and price.',
      'icon': FontAwesomeIcons.bolt,
      'color': blueMain,
    },
    {
      'title': 'Pricing Tiers 🏷️',
      'description': 'Easily switch between Retail, Bulk, and Distributor prices using the dropdown at the top of the POS screen. Prices update automatically!',
      'icon': FontAwesomeIcons.tag,
      'color': success,
    },
    {
      'title': 'Crate Management 🍺',
      'description': 'Track empty crates returned by customers. Total crate availability is shown in the Inventory tab to help you manage supplier returns.',
      'icon': FontAwesomeIcons.beerMugEmpty,
      'color': const Color(0xFFF59E0B),
    },
    {
      'title': 'Theme Toggle 🌓',
      'description': 'Working late? Switch to Dark Mode from the Sidebar or sync with your system theme for a more comfortable experience.',
      'icon': FontAwesomeIcons.moon,
      'color': const Color(0xFF6366F1),
    },
     {
      'title': 'Low Stock Alerts ⚠️',
      'description': 'Keep an eye on the Notification Bell! It will alert you when products drop below their threshold so you never run out of stock.',
      'icon': FontAwesomeIcons.triangleExclamation,
      'color': danger,
    },
  ];

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.getRSize(24),
                vertical: context.getRSize(8),
              ),
              child: Row(
                children: [
                  Text(
                    'Ribaplus POS Pro Tips',
                    style: TextStyle(
                      fontSize: context.getRFontSize(22),
                      fontWeight: FontWeight.w900,
                      color: _text,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: _subtext, size: context.getRSize(18)),
                    style: IconButton.styleFrom(
                      backgroundColor: _border.withValues(alpha: 0.1),
                      padding: EdgeInsets.all(context.getRSize(6)),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemCount: _tips.length,
                itemBuilder: (context, index) {
                  final tip = _tips[index];
                  return Padding(
                    padding: EdgeInsets.all(context.getRSize(24)),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(context.getRSize(24)),
                            decoration: BoxDecoration(
                              color: tip['color'].withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              tip['icon'],
                              size: context.getRSize(48),
                              color: tip['color'],
                            ),
                          ),
                          SizedBox(height: context.getRSize(16)),
                          Text(
                            tip['title'],
                            style: TextStyle(
                              fontSize: context.getRFontSize(20),
                              fontWeight: FontWeight.bold,
                              color: _text,
                            ),
                          ),
                          SizedBox(height: context.getRSize(8)),
                          Text(
                            tip['description'],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: context.getRFontSize(14),
                              color: _subtext,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: EdgeInsets.symmetric(vertical: context.getRSize(24)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _tips.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(horizontal: context.getRSize(4)),
                    width: _currentPage == index ? context.getRSize(24) : context.getRSize(8),
                    height: context.getRSize(8),
                    decoration: BoxDecoration(
                      color: _currentPage == index ? blueMain : _border,
                      borderRadius: BorderRadius.circular(context.getRSize(4)),
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(
                context.getRSize(24),
                0,
                context.getRSize(24),
                MediaQuery.of(context).padding.bottom + context.getRSize(16),
              ),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: context.getRSize(14)),
                          side: BorderSide(color: _border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text('Back', style: TextStyle(color: _text, fontWeight: FontWeight.bold, fontSize: context.getRFontSize(14))),
                      ),
                    ),
                  if (_currentPage > 0) SizedBox(width: context.getRSize(16)),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < _tips.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blueMain,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: context.getRSize(14)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage < _tips.length - 1 ? 'Next Tip' : 'Got it!',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: context.getRFontSize(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
