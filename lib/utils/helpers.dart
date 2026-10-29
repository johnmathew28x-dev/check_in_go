import 'package:flutter/material.dart';

// The three attendance statuses
const List<String> statusList = ['Present', 'Absent', 'Tardy'];

const List<String> monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

// DateTime -> "2026-09-19" (this is how the date is saved)
String dateToStorage(DateTime date) {
  String month = date.month.toString().padLeft(2, '0');
  String day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

// "2026-09-19" -> "September 19, 2026" (this is how the date is shown)
String dateToReadable(String storedDate) {
  List<String> parts = storedDate.split('-');
  if (parts.length != 3) {
    return storedDate;
  }
  int? year = int.tryParse(parts[0]);
  int? month = int.tryParse(parts[1]);
  int? day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) {
    return storedDate;
  }
  if (month < 1 || month > 12) {
    return storedDate;
  }
  return '${monthNames[month - 1]} $day, $year';
}

// DateTime -> "September 19, 2026"
String dateTimeToReadable(DateTime date) {
  return dateToReadable(dateToStorage(date));
}

// Main color for each status
Color statusColor(String status) {
  if (status == 'Present') {
    return Colors.green.shade600;
  }
  if (status == 'Absent') {
    return Colors.red.shade600;
  }
  if (status == 'Tardy') {
    return Colors.orange.shade700;
  }
  return Colors.grey;
}

// Light background color for each status
Color statusLightColor(String status) {
  if (status == 'Present') {
    return Colors.green.shade50;
  }
  if (status == 'Absent') {
    return Colors.red.shade50;
  }
  if (status == 'Tardy') {
    return Colors.orange.shade50;
  }
  return Colors.grey.shade200;
}

// Icon for each status
IconData statusIcon(String status) {
  if (status == 'Present') {
    return Icons.check_circle;
  }
  if (status == 'Absent') {
    return Icons.cancel;
  }
  if (status == 'Tardy') {
    return Icons.access_time;
  }
  return Icons.help;
}
