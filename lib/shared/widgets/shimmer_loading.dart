import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

// ── Base shimmer wrapper ───────────────────────────────────────────────────────
// All shimmer widgets use this so the sweep colour adapts to light/dark theme.

class _ShimmerWrap extends StatelessWidget {
  final Widget child;
  final Duration period;
  const _ShimmerWrap({
    required this.child,
    this.period = const Duration(milliseconds: 1500),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Darker colors for dark mode to satisfy user request.
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF0C111D) : const Color(0xFFE8EDF2),
      highlightColor: isDark
          ? const Color(0xFF1F2937)
          : const Color(0xFFF7F9FC),
      period: period,
      child: child,
    );
  }
}

// ── Primitive building blocks ─────────────────────────────────────────────────

/// A plain shimmering rectangle with rounded corners.
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrap(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// A shimmer box that fills its parent's width.
class ShimmerLine extends StatelessWidget {
  final double height;
  final double radius;
  final double? widthFraction; // 0–1, null = full width

  const ShimmerLine({
    super.key,
    this.height = 14,
    this.radius = 6,
    this.widthFraction,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        final w = widthFraction != null ? maxW * widthFraction! : maxW;
        return _ShimmerWrap(
          child: Container(
            width: w,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        );
      },
    );
  }
}

// ── Composite shimmer skeletons ───────────────────────────────────────────────

/// A shimmer skeleton that looks like a list tile (avatar + two text lines).
class ShimmerListTile extends StatelessWidget {
  final bool hasAvatar;
  const ShimmerListTile({super.key, this.hasAvatar = true});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardCol = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardCol,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          if (hasAvatar) ...[
            _ShimmerWrap(
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const ShimmerLine(height: 14, widthFraction: 0.6),
                const SizedBox(height: 8),
                const ShimmerLine(height: 11, widthFraction: 0.4),
                const SizedBox(height: 12),
                _ShimmerWrap(
                  child: Container(
                    width: 60,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ShimmerWrap(
                child: Container(
                  width: 40,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const ShimmerBox(width: 70, height: 18, radius: 6),
            ],
          ),
        ],
      ),
    );
  }
}

/// A shimmer skeleton for a stat/metric card.
class ShimmerStatCard extends StatelessWidget {
  const ShimmerStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardCol = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      height: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardCol,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _ShimmerWrap(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShimmerLine(height: 12, widthFraction: 0.4),
                SizedBox(height: 10),
                ShimmerLine(height: 22, widthFraction: 0.6),
                SizedBox(height: 10),
                ShimmerLine(height: 10, widthFraction: 0.8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A shimmer skeleton for a product/inventory grid card.
class ShimmerGridCard extends StatelessWidget {
  const ShimmerGridCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _ShimmerWrap(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey[200]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(12) : Colors.grey[100],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withAlpha(20)
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withAlpha(20)
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 50,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withAlpha(15)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withAlpha(15)
                              : Colors.grey[200],
                          shape: BoxShape.circle,
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
    );
  }
}

/// A shimmer skeleton for an order card.
class ShimmerOrderCard extends StatelessWidget {
  const ShimmerOrderCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardCol = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? Colors.white10 : Colors.grey[200]!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardCol,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const ShimmerLine(height: 13, widthFraction: 0.3),
                _ShimmerWrap(
                  child: Container(
                    width: 70,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: borderCol),
          const Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerLine(height: 12, widthFraction: 0.4),
                    ShimmerLine(height: 12, widthFraction: 0.2),
                  ],
                ),
                SizedBox(height: 12),
                ShimmerLine(height: 10, widthFraction: 0.5),
                SizedBox(height: 6),
                ShimmerLine(height: 10, widthFraction: 0.3),
              ],
            ),
          ),
          Container(height: 1, color: borderCol),
          const Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerLine(height: 14, widthFraction: 0.4),
                ShimmerBox(width: 80, height: 24, radius: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Full-screen shimmer lists ─────────────────────────────────────────────────

/// A list of [ShimmerListTile]s — use this while a list screen loads.
class ShimmerList extends StatelessWidget {
  final int count;
  final bool hasAvatar;

  const ShimmerList({super.key, this.count = 8, this.hasAvatar = true});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (_, __) => ShimmerListTile(hasAvatar: hasAvatar),
    );
  }
}

/// A 2-column grid of [ShimmerGridCard]s — use this while an inventory/POS grid loads.
class ShimmerGrid extends StatelessWidget {
  final int count;
  final int? crossAxisCount;

  const ShimmerGrid({super.key, this.count = 6, this.crossAxisCount});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final axisCount =
        crossAxisCount ?? (screenWidth < 360 ? 2 : (screenWidth > 500 ? 4 : 3));

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: axisCount,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: count,
      itemBuilder: (_, __) => const ShimmerGridCard(),
    );
  }
}

/// A list of [ShimmerOrderCard]s — use this while orders load.
class ShimmerOrderList extends StatelessWidget {
  final int count;

  const ShimmerOrderList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      itemBuilder: (_, __) => const ShimmerOrderCard(),
    );
  }
}

/// Dashboard shimmer: 4 stat cards + a list of recent order skeletons.
class ShimmerDashboard extends StatelessWidget {
  const ShimmerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: const [
              ShimmerStatCard(),
              ShimmerStatCard(),
              ShimmerStatCard(),
              ShimmerStatCard(),
            ],
          ),
          const SizedBox(height: 20),
          const ShimmerLine(height: 16, widthFraction: 0.4),
          const SizedBox(height: 12),
          ...List.generate(
            5,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: ShimmerOrderCard(),
            ),
          ),
        ],
      ),
    );
  }
}

/// A shimmer skeleton for select/dropdown fields.
class ShimmerDropdown extends StatelessWidget {
  const ShimmerDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _ShimmerWrap(
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 60,
              height: 14,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(20) : Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: isDark ? Colors.white.withAlpha(128) : Colors.white,
              size: 13,
            ),
          ],
        ),
      ),
    );
  }
}

/// A shimmer skeleton for the category filter bar.
class ShimmerCategoryBar extends StatelessWidget {
  const ShimmerCategoryBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return _ShimmerWrap(
            child: Container(
              width: index == 0 ? 50 : 80,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withAlpha(20)
                    : Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A shimmer skeleton for inventory summary cards.
class ShimmerInventoryStats extends StatelessWidget {
  const ShimmerInventoryStats({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final isPhone = MediaQuery.of(context).size.width < 600;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return _ShimmerWrap(
            child: Container(
              width: isPhone ? 130 : 180,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withAlpha(20) : Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 70,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withAlpha(20) : Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 50,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withAlpha(15) : Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A shimmer skeleton for a list-style product row (Inventory style).
class ShimmerInventoryRow extends StatelessWidget {
  const ShimmerInventoryRow({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardCol = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? Colors.white10 : Colors.grey[200]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardCol,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          _ShimmerWrap(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const ShimmerLine(height: 15, widthFraction: 0.5),
                    const SizedBox(width: 8),
                    _ShimmerWrap(
                      child: Container(
                        width: 60,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const ShimmerLine(height: 12, widthFraction: 0.3),
              ],
            ),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ShimmerBox(width: 30, height: 22, radius: 4),
              SizedBox(height: 6),
              ShimmerBox(width: 40, height: 11, radius: 5),
            ],
          ),
        ],
      ),
    );
  }
}

/// A shimmer skeleton for the Customer Profile header area.
class ShimmerCustomerProfile extends StatelessWidget {
  const ShimmerCustomerProfile({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Header
        const Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              ShimmerBox(width: 60, height: 60, radius: 30),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ShimmerLine(height: 20, widthFraction: 0.5),
                        Spacer(),
                        ShimmerBox(width: 80, height: 24, radius: 12),
                      ],
                    ),
                    SizedBox(height: 8),
                    ShimmerLine(height: 12, widthFraction: 0.4),
                    SizedBox(height: 4),
                    ShimmerLine(height: 12, widthFraction: 0.6),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Wallet Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 160,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey[200]!,
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLine(height: 12, widthFraction: 0.3),
                SizedBox(height: 12),
                ShimmerLine(height: 32, widthFraction: 0.5),
                SizedBox(height: 8),
                ShimmerLine(height: 12, widthFraction: 0.4),
                Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: ShimmerBox(
                        width: double.infinity,
                        height: 42,
                        radius: 12,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ShimmerBox(
                        width: double.infinity,
                        height: 42,
                        radius: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A shimmer skeleton for a staff member card.
class ShimmerStaffCard extends StatelessWidget {
  const ShimmerStaffCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: const Row(
        children: [
          ShimmerBox(width: 48, height: 48, radius: 24),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLine(height: 15, widthFraction: 0.4),
                SizedBox(height: 6),
                ShimmerBox(width: 60, height: 18, radius: 10),
              ],
            ),
          ),
          ShimmerBox(width: 32, height: 32, radius: 8),
        ],
      ),
    );
  }
}

/// A shimmer skeleton for a row in the Sales Breakdown table.
class ShimmerSaleRow extends StatelessWidget {
  final bool showProfit;
  const ShimmerSaleRow({super.key, this.showProfit = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLine(height: 13, widthFraction: 0.7),
                SizedBox(height: 4),
                ShimmerLine(height: 10, widthFraction: 0.4),
              ],
            ),
          ),
          const SizedBox(
            width: 50,
            child: Center(child: ShimmerBox(width: 24, height: 14, radius: 4)),
          ),
          const SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerRight,
              child: ShimmerLine(height: 12, widthFraction: 0.8),
            ),
          ),
          if (showProfit)
            const SizedBox(
              width: 80,
              child: Align(
                alignment: Alignment.centerRight,
                child: ShimmerLine(height: 12, widthFraction: 0.8),
              ),
            ),
        ],
      ),
    );
  }
}

/// A shimmer skeleton for a row in the Stock Count table.
class ShimmerStockCountRow extends StatelessWidget {
  const ShimmerStockCountRow({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: const Row(
        children: [
          Expanded(flex: 5, child: ShimmerLine(height: 14, widthFraction: 0.6)),
          SizedBox(
            width: 56,
            child: Center(child: ShimmerBox(width: 24, height: 14, radius: 4)),
          ),
          SizedBox(
            width: 72,
            child: ShimmerBox(width: 48, height: 32, radius: 8),
          ),
          SizedBox(
            width: 56,
            child: Center(child: ShimmerBox(width: 24, height: 14, radius: 4)),
          ),
        ],
      ),
    );
  }
}

// ── Product Detail shimmer skeleton ──────────────────────────────────────────

/// Full-page skeleton for ProductDetailScreen.
/// Mirrors every section from "Stock & Info" down to the Update Product button.
/// Uses a 2-second shimmer period for a slower, premium feel.
class ShimmerProductDetail extends StatelessWidget {
  const ShimmerProductDetail({super.key});

  static const _kPeriod = Duration(milliseconds: 2000);

  // A single info-row placeholder: icon square + label bar + trailing bar.
  Widget _shimmerRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _ShimmerWrap(
            period: _kPeriod,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _ShimmerWrap(
              period: _kPeriod,
              child: Container(
                height: 13,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _ShimmerWrap(
            period: _kPeriod,
            child: Container(
              width: 100,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // A stat row for Sales Summary: 3 text bars side by side.
  Widget _shimmerStatRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _ShimmerWrap(
              period: _kPeriod,
              child: Container(
                height: 13,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _ShimmerWrap(
              period: _kPeriod,
              child: Container(
                height: 13,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: _ShimmerWrap(
              period: _kPeriod,
              child: Container(
                height: 13,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // A target row for Sales Target: label + text + progress bar placeholder.
  Widget _shimmerTargetRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ShimmerWrap(
                period: _kPeriod,
                child: Container(
                  width: 60,
                  height: 13,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              _ShimmerWrap(
                period: _kPeriod,
                child: Container(
                  width: 120,
                  height: 13,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ShimmerWrap(
            period: _kPeriod,
            child: Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(
      height: 1,
      color: Theme.of(context).dividerColor,
      indent: 16,
      endIndent: 16,
    );
  }

  Widget _infoCard(BuildContext context, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey[200]!,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _sectionTitle(BuildContext context) {
    return _ShimmerWrap(
      period: _kPeriod,
      child: Container(
        width: 120,
        height: 16,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stock & Info (6 rows) ─────────────────────────────────
          _sectionTitle(context),
          const SizedBox(height: 12),
          _infoCard(context, [
            _shimmerRow(context),
            _divider(context),
            _shimmerRow(context),
            _divider(context),
            _shimmerRow(context),
            _divider(context),
            _shimmerRow(context),
            _divider(context),
            _shimmerRow(context),
            _divider(context),
            _shimmerRow(context),
          ]),

          const SizedBox(height: 24),

          // ── Pricing (5 rows) ──────────────────────────────────────
          _sectionTitle(context),
          const SizedBox(height: 12),
          _infoCard(context, [
            _shimmerRow(context),
            _divider(context),
            _shimmerRow(context),
            _divider(context),
            _shimmerRow(context),
            _divider(context),
            _shimmerRow(context),
            _divider(context),
            _shimmerRow(context),
          ]),

          const SizedBox(height: 24),

          // ── Sales Summary (3 stat rows) ───────────────────────────
          _sectionTitle(context),
          const SizedBox(height: 12),
          _infoCard(context, [
            _shimmerStatRow(context),
            _divider(context),
            _shimmerStatRow(context),
            _divider(context),
            _shimmerStatRow(context),
          ]),

          const SizedBox(height: 24),

          // ── Sales Target (3 rows with progress bars) ──────────────
          _sectionTitle(context),
          const SizedBox(height: 12),
          _infoCard(context, [
            _shimmerTargetRow(context),
            _divider(context),
            _shimmerTargetRow(context),
            _divider(context),
            _shimmerTargetRow(context),
          ]),

          const SizedBox(height: 24),

          // ── Last Delivery (4 rows) ────────────────────────────────
          _sectionTitle(context),
          const SizedBox(height: 12),
          _infoCard(context, [
            _shimmerRow(context),
            _divider(context),
            _shimmerRow(context),
            _divider(context),
            _shimmerRow(context),
            _divider(context),
            _shimmerRow(context),
          ]),

          const SizedBox(height: 32),

          // ── Update Product button placeholder ─────────────────────
          _ShimmerWrap(
            period: _kPeriod,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
