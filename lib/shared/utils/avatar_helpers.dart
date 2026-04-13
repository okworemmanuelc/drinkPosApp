import 'package:flutter/material.dart';

/// Returns the initials from a name (first letter of first two words).
String avatarInitials(String name) {
  final parts = name.trim().split(' ');
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
}

/// Parses a hex color string like '#3B82F6' into a [Color].
/// Returns null if parsing fails.
Color? parseHexColor(String hex) {
  try {
    final cleaned = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  } catch (_) {
    return null;
  }
}
