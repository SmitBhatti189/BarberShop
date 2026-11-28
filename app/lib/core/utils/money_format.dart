import 'package:intl/intl.dart';

import '../../config/app_strings.dart';

final _rupees = NumberFormat.currency(locale: 'en_IN', symbol: AppStrings.currencySymbol, decimalDigits: 2);

/// "1800.00" (as the API sends money) → "₹1,800.00" (Indian grouping).
/// Formatting only — amounts are always calculated by the server.
String formatMoney(String? amount) {
  if (amount == null) return '—';
  final value = double.tryParse(amount);
  return value == null ? amount : _rupees.format(value);
}

/// "10.00" → "10%", "12.50" → "12.5%".
String formatPercent(String pct) {
  final value = double.tryParse(pct);
  if (value == null) return '$pct%';
  return '${value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString()}%';
}
