import 'package:intl/intl.dart';

String formatDateTime(DateTime dt, {String pattern = 'yyyy-MM-dd HH:mm'}) {
  return DateFormat(pattern).format(dt);
}

String formatDate(DateTime dt, {String pattern = 'yyyy-MM-dd'}) {
  return DateFormat(pattern).format(dt);
}

/// DateUtils class for compatibility with imports using date_utils.DateUtils
class DateUtils {
  static String formatDateTime(DateTime dt, {String pattern = 'yyyy-MM-dd HH:mm'}) {
    return DateFormat(pattern).format(dt);
  }

  static String formatDate(DateTime dt, {String pattern = 'yyyy-MM-dd'}) {
    return DateFormat(pattern).format(dt);
  }

  static String formatRelative(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} years ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'just now';
    }
  }

  static bool isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  static bool isYesterday(DateTime dt) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;
  }
}

