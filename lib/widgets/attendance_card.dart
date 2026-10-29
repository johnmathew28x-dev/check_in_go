import 'package:flutter/material.dart';
import '../models/attendance.dart';
import '../utils/helpers.dart';

// Shows all the attendance records of ONE date and ONE section.
class AttendanceCard extends StatelessWidget {
  final String date;
  final String section;
  final List<Attendance> records;

  const AttendanceCard({
    super.key,
    required this.date,
    required this.section,
    required this.records,
  });

  int countStatus(String status) {
    int count = 0;
    for (Attendance record in records) {
      if (record.status == status) {
        count++;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Build one row for each student
    List<Widget> studentRows = [];
    for (Attendance record in records) {
      studentRows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(record.studentName)),
              Icon(
                statusIcon(record.status),
                size: 18,
                color: statusColor(record.status),
              ),
              const SizedBox(width: 6),
              Text(
                record.status,
                style: TextStyle(
                  color: statusColor(record.status),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateToReadable(date),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    section,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${countStatus('Present')} present  ·  ${countStatus('Absent')} absent  ·  ${countStatus('Tardy')} tardy',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const Divider(),
            ...studentRows,
          ],
        ),
      ),
    );
  }
}
