/// Presentation helpers for Tour UI — no API / model contract changes.
class TourDisplay {
  TourDisplay._();

  /// Returns a displayable duration, or null when the API value is junk.
  static String? meaningfulDuration(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;

    final lower = value.toLowerCase();
    const junk = <String>{
      'n/a',
      'na',
      'n.a.',
      'none',
      '-',
      '--',
      'day',
      'days',
      'null',
    };
    if (junk.contains(lower)) return null;

    // Bare numbers like "5" are not meaningful without a unit.
    if (RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) return null;

    return value;
  }

  static String formatFromPrice(double price) {
    if (price <= 0) return 'Price on request';
    if (price == price.roundToDouble()) {
      return 'From \$${price.toStringAsFixed(0)}';
    }
    return 'From \$${price.toStringAsFixed(2)}';
  }

  static String formatPrice(double price) {
    if (price <= 0) return 'Price on request';
    if (price == price.roundToDouble()) {
      return '\$${price.toStringAsFixed(0)}';
    }
    return '\$${price.toStringAsFixed(2)}';
  }
}
