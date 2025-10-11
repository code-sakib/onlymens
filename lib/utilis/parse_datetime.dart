import 'package:intl/intl.dart';

String formatDateTime(String dateTimeString) {
  final dateTime = DateTime.parse(dateTimeString);
  final formatted = DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  return formatted;
}
