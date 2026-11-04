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

/// "Nov 4"
String shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

String grouped(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return n < 0 ? '-$buf' : buf.toString();
}

String _trim(double v, [int digits = 1]) =>
    v.toStringAsFixed(digits).replaceAll(RegExp(r'\.?0+$'), '');

/// Number without a trailing ".0" ("8.5", "39").
String plain(num v, [int digits = 2]) => _trim(v.toDouble(), digits);

/// "1.2K", "2.4M" style count.
String abbr(num n) {
  final a = n.abs();
  if (a >= 1e6) return '${_trim(n / 1e6)}M';
  if (a >= 1e3) return '${_trim(n / 1e3)}K';
  return grouped(n.round());
}

/// "Jul 3, 2024, 11:52 AM"
String postedOn(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final mm = d.minute.toString().padLeft(2, '0');
  final suffix = d.hour < 12 ? 'AM' : 'PM';
  return '${_months[d.month - 1]} ${d.day}, ${d.year}, $h:$mm $suffix';
}

/// "11/2/2026"
String numericDate(DateTime d) => '${d.month}/${d.day}/${d.year}';

/// Video position as "0:02" or "00:56" style clock text.
String clock(num seconds, {bool pad = false}) {
  final s = seconds.round();
  final m = s ~/ 60;
  final r = (s % 60).toString().padLeft(2, '0');
  return '${pad ? m.toString().padLeft(2, '0') : m}:$r';
}

/// "0h:06m:23s"
String playTime(int seconds) {
  final h = seconds ~/ 3600;
  final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '${h}h:${m}m:${s}s';
}

/// Share of [part] in [whole] as a whole-number percent.
int percentOf(num part, num whole) =>
    whole <= 0 ? 0 : (part / whole * 100).round();
