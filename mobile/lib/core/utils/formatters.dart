// Formatting helpers for UI display. Keeps widget code readable.

String formatRl(double? value) {
  if (value == null) return '— mcd/m²/lx';
  return '${value.toStringAsFixed(0)} mcd/m²/lx';
}

String formatLatLng(double lat, double lng) =>
    '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}

String formatTimestamp(DateTime t) {
  final local = t.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final mo = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final mi = local.minute.toString().padLeft(2, '0');
  return '$y-$mo-$d $h:$mi';
}
