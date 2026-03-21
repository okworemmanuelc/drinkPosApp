import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Amber circle with a number inside.
class CartQtyBubble extends StatelessWidget {
  final int count;
  final double size;

  const CartQtyBubble({
    super.key,
    required this.count,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: amberPrimary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 1.5),
        boxShadow: const [
          BoxShadow(color: amberGlow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Text(
          count.toString(),
          style: TextStyle(
            color: Colors.black,
            fontSize: size * 0.48,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
