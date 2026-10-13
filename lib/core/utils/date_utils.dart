/// Formatting helpers for note timestamps and reminders.
class AppDateUtils {
  AppDateUtils._();

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "Just now", "5 min ago", "3 h ago", "Yesterday", "12 Mar", "12 Mar 2024".
  static String relative(DateTime dateTime, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    final Duration diff = reference.difference(dateTime);

    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';

    final DateTime today = DateTime(reference.year, reference.month, reference.day);
    final DateTime that = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final int dayGap = today.difference(that).inDays;
    if (dayGap == 1) return 'Yesterday';
    if (dayGap < 7) return '$dayGap days ago';

    final String base = '${dateTime.day} ${_months[dateTime.month - 1]}';
    if (dateTime.year == reference.year) return base;
    return '$base ${dateTime.year}';
  }

  static String time(DateTime dt) {
    final int hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final String period = dt.hour < 12 ? 'AM' : 'PM';
    final String minute = dt.minute.toString().padLeft(2, '0');
    return '$hour12:$minute $period';
  }

  static String dateTime(DateTime dt) =>
      '${dt.day} ${_months[dt.month - 1]} ${dt.year}, ${time(dt)}';

  /// Human friendly "in 2 h 15 m" for reminders.
  static String until(DateTime target, {DateTime? now}) {
    final Duration diff = target.difference(now ?? DateTime.now());
    if (diff.isNegative) return 'Overdue';
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes} min';
    if (diff.inHours < 24) {
      return 'in ${diff.inHours} h ${diff.inMinutes % 60} m';
    }
    return 'in ${diff.inDays} d';
  }
}
