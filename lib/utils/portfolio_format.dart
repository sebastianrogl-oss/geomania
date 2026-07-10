// Gemeinsame Formatierungs-Helfer für alle Weltportfolio-Screens.

String fmtKapital(double k, {bool mitVorzeichen = false}) {
  final rounded = k.round().abs();
  final s = rounded.toString();
  final buf = StringBuffer();
  int cnt = 0;
  for (int i = s.length - 1; i >= 0; i--) {
    if (cnt > 0 && cnt % 3 == 0) buf.write('.');
    buf.write(s[i]);
    cnt++;
  }
  final vorzeichen = k < 0 ? '-' : (mitVorzeichen && k > 0 ? '+' : '');
  return '$vorzeichen${buf.toString().split('').reversed.join('')} \$';
}

String fmtProzent(double p) {
  final sign = p >= 0 ? '+' : '';
  return '$sign${p.toStringAsFixed(1).replaceAll('.', ',')}%';
}
