const _months = [
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

String shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

String compact(num n) {
  final a = n.abs();
  if (a >= 1e6) return '${_trim(n / 1e6)}M';
  if (a >= 1e4) return '${_trim(n / 1e3)}K';
  return _group(n.round());
}

String _trim(double v) => v.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');

String _group(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return n < 0 ? '-$buf' : buf.toString();
}

String grouped(int n) => _group(n);

/// "+12 (3.1%)" style comparison text; null previous means no comparison.
String deltaText(num current, num? previous) {
  if (previous == null) return '0 (--)';
  final diff = current - previous;
  if (previous == 0)
    return '${diff >= 0 ? '+' : ''}${_group(diff.round())} (--)';
  final pct = diff / previous * 100;
  return '${diff >= 0 ? '+' : ''}${_group(diff.round())} '
      '(${pct.toStringAsFixed(1)}%)';
}

/// Like [compact] but abbreviates from 1,000 up ("1.2K", "2.4M").
String abbr(num n) {
  final a = n.abs();
  if (a >= 1e6) return '${_trim(n / 1e6)}M';
  if (a >= 1e3) return '${_trim(n / 1e3)}K';
  return _group(n.round());
}

String money(num cents) => '\$${(cents / 100).toStringAsFixed(2)}';

/// Display text for a metric's value, by metric name.
String formatMetric(String key, num v) {
  switch (key) {
    case 'Est. rewards':
      return money(v);
    case 'Total play time':
      return '${abbr(v)}h';
    default:
      return abbr(v);
  }
}

/// Signed change text ("+909K") and percentage text ("+61.6%"); the
/// percentage is null when there is nothing to compare against.
({String change, String? percent, bool? up}) deltaParts(
  String key,
  num current,
  num? previous,
) {
  if (previous == null) {
    return (change: '+${formatMetric(key, 0)}', percent: null, up: null);
  }
  final diff = current - previous;
  final sign = diff < 0 ? '-' : '+';
  final change = '$sign${formatMetric(key, diff.abs())}';
  final percent = previous == 0
      ? null
      : '${diff < 0 ? '' : '+'}${(diff / previous * 100).toStringAsFixed(1)}%';
  return (change: change, percent: percent, up: diff == 0 ? null : diff > 0);
}

String hourLabel(int h) {
  if (h == 0) return '0a';
  if (h < 12) return '${h}a';
  if (h == 12) return '12p';
  return '${h - 12}p';
}

const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "-1", "+2.4K" or "0": the change against the previous period.
String _signed(String key, num diff) {
  if (diff == 0) return key == 'Est. rewards' ? '+${money(0)}' : '0';
  return '${diff < 0 ? '-' : '+'}${formatMetric(key, diff.abs())}';
}

String _pct(double v) =>
    '${v.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}%';

/// Change shown under a tile: text plus direction (null when unchanged).
typedef Delta = ({String text, bool? up});

/// Overview style: "0", "+$0.00", "-1 (-100%)".
Delta overviewDelta(String key, num current, num? previous) {
  if (previous == null) return (text: '0', up: null);
  final diff = current - previous;
  final base = _signed(key, diff);
  if (diff == 0 || previous == 0) return (text: base, up: _dir(diff));
  return (text: '$base (${_pct(diff / previous * 100)})', up: _dir(diff));
}

/// Viewers style: the percentage is always shown, "0 (0%)".
Delta viewerDelta(String key, num current, num? previous) {
  if (previous == null) return (text: '0 (0%)', up: null);
  final diff = current - previous;
  final pct = previous == 0 ? (diff == 0 ? 0.0 : 100.0) : diff / previous * 100;
  return (text: '${_signed(key, diff)} (${_pct(pct)})', up: _dir(diff));
}

bool? _dir(num diff) => diff == 0 ? null : diff > 0;

/// "6 PM"-style clock label for the 24-hour value [h].
String clockLabel(int h) {
  final suffix = h < 12 ? 'am' : 'pm';
  final hh = h % 12 == 0 ? 12 : h % 12;
  return '$hh$suffix';
}

const weekdayLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
