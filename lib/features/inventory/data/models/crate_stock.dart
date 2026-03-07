// CrateStock model
// TODO: define CrateStock class
import 'package:flutter/material.dart';
import 'crate_group.dart';

class CrateStock {
  CrateGroup group;
  double available;
  String? customLabel;
  Color? customColor;

  CrateStock({
    required this.group,
    this.available = 0,
    this.customLabel,
    this.customColor,
  });

  /// Display label — uses customLabel if set, otherwise the enum label.
  String get label => customLabel ?? group.label;

  /// Display color — uses customColor if set, otherwise the enum color.
  Color get color => customColor ?? group.color;
}
