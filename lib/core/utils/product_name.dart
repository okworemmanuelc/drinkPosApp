/// Returns the display name for a product, optionally prepending the unit
/// and appending a size abbreviation.
///
/// Examples:
///   productDisplayName('Goldberg', 'big',    unit: 'Bottle') → 'Bottle Goldberg (B)'
///   productDisplayName('Goldberg', 'medium', unit: 'Crate')  → 'Crate Goldberg (M)'
///   productDisplayName('Goldberg', null,     unit: 'Can')    → 'Can Goldberg'
///   productDisplayName('Goldberg', 'small')                  → 'Goldberg (S)'
///   productDisplayName('Goldberg', null)                     → 'Goldberg'
String productDisplayName(String name, String? size, {String? unit}) {
  final base = (unit != null && unit.isNotEmpty) ? '$unit $name' : name;
  if (size == null || size.isEmpty) return base;
  final abbr = size[0].toUpperCase();
  return '$base ($abbr)';
}
