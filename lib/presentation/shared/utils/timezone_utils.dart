library;

/// Timezone conversion and formatting utilities for business dates and schedules.
/// Follows C-4 Baseline: standard business timezone is Asia/Ho_Chi_Minh (UTC+7).

/// Converts a [DateTime] (typically in UTC from API/Repository) to the business local time.
DateTime toBusinessTime(DateTime dt, [String timeZone = 'Asia/Ho_Chi_Minh']) {
  final utc = dt.toUtc();
  final offset = switch (timeZone) {
    'Asia/Ho_Chi_Minh' || 'Asia/Saigon' || 'ICT' || '+07:00' => const Duration(hours: 7),
    _ => const Duration(hours: 7), // Vietnam business timezone default
  };
  return utc.add(offset);
}

/// Formats start and end times in HH:mm — HH:mm format.
/// Example: "16:00 — 18:00"
String formatSlotTime(DateTime start, DateTime end, [String timeZone = 'Asia/Ho_Chi_Minh']) {
  final localStart = toBusinessTime(start, timeZone);
  final localEnd = toBusinessTime(end, timeZone);
  final sH = localStart.hour.toString().padLeft(2, '0');
  final sM = localStart.minute.toString().padLeft(2, '0');
  final eH = localEnd.hour.toString().padLeft(2, '0');
  final eM = localEnd.minute.toString().padLeft(2, '0');
  return '$sH:$sM — $eH:$eM';
}

/// Formats slot time with day/month in parenthesis.
/// Example: "16:00 — 18:00 (20/10)"
String formatSlotWithDate(DateTime start, DateTime end, [String timeZone = 'Asia/Ho_Chi_Minh']) {
  final localStart = toBusinessTime(start, timeZone);
  final timeStr = formatSlotTime(start, end, timeZone);
  return '$timeStr (${localStart.day}/${localStart.month})';
}

/// Formats date and time string in business timezone.
/// Example: "16:00 — Ngày 20/10/2026"
String formatBusinessDateTime(DateTime dt, [String timeZone = 'Asia/Ho_Chi_Minh']) {
  final local = toBusinessTime(dt, timeZone);
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m — Ngày ${local.day}/${local.month}/${local.year}';
}

/// Formats full schedule with weekday and timezone label.
/// Example: "16:00 — Thứ Hai, 20/10/2026 (Asia/Ho_Chi_Minh)"
String formatBusinessSchedule(DateTime dt, [String timeZone = 'Asia/Ho_Chi_Minh']) {
  final local = toBusinessTime(dt, timeZone);
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  final weekday = local.weekday == 7 ? 'Chủ Nhật' : 'Thứ ${local.weekday + 1}';
  return '$h:$m — $weekday, ${local.day}/${local.month}/${local.year} ($timeZone)';
}
