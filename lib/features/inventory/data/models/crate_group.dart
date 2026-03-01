import 'package:flutter/material.dart';

enum CrateGroup { nbPlc, guinness, cocaCola, premium }

extension CrateGroupLabel on CrateGroup {
  String get label {
    switch (this) {
      case CrateGroup.nbPlc:
        return 'NB Plc';
      case CrateGroup.guinness:
        return 'Guinness';
      case CrateGroup.cocaCola:
        return 'Coca-Cola';
      case CrateGroup.premium:
        return 'Premium';
    }
  }

  Color get color {
    switch (this) {
      case CrateGroup.nbPlc:
        return const Color(0xFFF59E0B);
      case CrateGroup.guinness:
        return const Color(0xFF334155);
      case CrateGroup.cocaCola:
        return const Color(0xFFEF4444);
      case CrateGroup.premium:
        return const Color(0xFF8B5CF6);
    }
  }
}
