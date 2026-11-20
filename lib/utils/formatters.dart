/// Shared display formatters for the patient portal.
///
/// Amounts are formatted with Indian digit grouping (₹1,23,456) and dates are
/// rendered in a compact, human-friendly form. Keeping these here avoids each
/// screen inventing its own slightly-different formatting.
library;

const List<String> _shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

DateTime? parseApiDate(Object? value) {
  if (value is DateTime) return value;
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value.trim());
}

/// `14 Nov 2026` — falls back to [fallback] when the value is missing.
String formatDate(Object? value, {String fallback = 'Not available'}) {
  final date = parseApiDate(value);
  if (date == null) return fallback;
  final local = date.toLocal();
  return '${local.day} ${_shortMonths[local.month - 1]} ${local.year}';
}

/// `14 Nov` — used in compact cards and timelines.
String formatShortDate(Object? value, {String fallback = '—'}) {
  final date = parseApiDate(value);
  if (date == null) return fallback;
  final local = date.toLocal();
  return '${local.day} ${_shortMonths[local.month - 1]}';
}

/// `Nov 2026` — used for "member since" style labels.
String formatMonthYear(Object? value, {String fallback = '—'}) {
  final date = parseApiDate(value);
  if (date == null) return fallback;
  final local = date.toLocal();
  return '${_shortMonths[local.month - 1]} ${local.year}';
}

/// Converts the clinic's `HH:mm` slot value to `2:30 PM`.
String formatTime(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return '';
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw);
  if (match == null) return raw;
  final hour24 = int.tryParse(match.group(1)!) ?? 0;
  final minute = match.group(2)!;
  final suffix = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$hour12:$minute $suffix';
}

/// `₹1,23,456` / `₹1,23,456.50` with Indian digit grouping.
String formatMoney(num? value, {bool alwaysDecimals = false}) {
  final amount = value ?? 0;
  final negative = amount < 0;
  final absolute = amount.abs();
  final hasPaise = (absolute * 100).round() % 100 != 0;
  final fixed = alwaysDecimals || hasPaise
      ? absolute.toStringAsFixed(2)
      : absolute.toStringAsFixed(0);
  final parts = fixed.split('.');
  final grouped = _groupIndian(parts.first);
  final decimals = parts.length > 1 ? '.${parts[1]}' : '';
  return '${negative ? '-' : ''}₹$grouped$decimals';
}

String _groupIndian(String digits) {
  if (digits.length <= 3) return digits;
  final lastThree = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);
  return '${groups.join(',')},$lastThree';
}

/// `partially_paid` → `Partially Paid`.
String formatStatus(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return '—';
  return raw
      .split(RegExp(r'[\s_]+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}

String initialsOf(String? name) {
  final words = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return 'P';
  if (words.length == 1) return words.first[0].toUpperCase();
  return '${words.first[0]}${words.last[0]}'.toUpperCase();
}

String firstNameOf(String? name) {
  final words = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  return words.isEmpty ? 'Patient' : words.first;
}

/// Whole years between [value] and today; `null` when the date is missing.
int? ageFromDate(Object? value) {
  final date = parseApiDate(value);
  if (date == null) return null;
  final now = DateTime.now();
  var age = now.year - date.year;
  if (now.month < date.month ||
      (now.month == date.month && now.day < date.day)) {
    age--;
  }
  return age < 0 ? null : age;
}

/// `14 Nov 2026, 3:20 PM` for timestamps that include a time component.
String formatDateTime(Object? value, {String fallback = 'Not available'}) {
  final date = parseApiDate(value);
  if (date == null) return fallback;
  final local = date.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${formatDate(local)}, ${formatTime('$hh:$mm')}';
}

/// Prefixes "Dr." to a doctor's name unless the name already carries it.
String doctorTitle(String? name) {
  final clean = (name ?? '').trim();
  if (clean.isEmpty) return 'Doctor';
  final lower = clean.toLowerCase();
  if (lower.startsWith('dr.') || lower.startsWith('dr ')) return clean;
  return 'Dr. $clean';
}
