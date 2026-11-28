/// Form checks shared by screens. They catch typing mistakes early; the
/// server re-checks everything.
abstract final class Validators {
  static final _money = RegExp(r'^\d{1,10}(\.\d{1,2})?$');
  static final _percent = RegExp(r'^\d{1,3}(\.\d{1,2})?$');

  static String? required(String? v, String message) => (v ?? '').trim().isEmpty ? message : null;

  /// Rupees with up to 2 decimals. [positive] rejects 0.
  static String? money(String? v, {bool positive = false, bool optional = false}) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return optional ? null : 'Enter an amount';
    if (!_money.hasMatch(value)) return 'Use numbers with up to 2 decimals';
    if (positive && double.parse(value) <= 0) return 'Must be more than 0';
    return null;
  }

  static String? percent(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return null;
    if (!_percent.hasMatch(value) || double.parse(value) > 100) return 'Enter 0 to 100';
    return null;
  }

  /// Whole number of units; [min] 1 for quantities, 0 for thresholds.
  static String? wholeNumber(String? v, {int min = 1, bool optional = false}) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return optional ? null : 'Enter a number';
    final n = int.tryParse(value);
    if (n == null) return 'Whole numbers only';
    if (n < min) return min == 1 ? 'At least 1' : 'Cannot be negative';
    return null;
  }
}
