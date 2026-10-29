import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import '../services/storage_service.dart';
import '../utils/helpers.dart';

class StudentAttendancePage extends StatefulWidget {
  final Student student;

  const StudentAttendancePage({super.key, required this.student});

  @override
  State<StudentAttendancePage> createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage> {
  StorageService storage = StorageService();
  List<Attendance> records = []; // only this student's records
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadRecords();
  }

  Future<void> loadRecords() async {
    List<Attendance> all = await storage.loadAttendance();

    // Keep only the records of this student
    List<Attendance> mine = [];
    for (Attendance record in all) {
      if (record.studentId == widget.student.id) {
        mine.add(record);
      }
    }

    // Newest date first
    mine.sort((a, b) => b.date.compareTo(a.date));

    if (!mounted) return;
    setState(() {
      records = mine;
      isLoading = false;
    });
  }

  int countStatus(String status) {
    int count = 0;
    for (Attendance record in records) {
      if (record.status == status) {
        count++;
      }
    }
    return count;
  }

  Widget buildInfoCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.person_outline,
                color: colorScheme.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.student.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Student ID: ${widget.student.id}'),
                  Text('Course: ${widget.student.course}'),
                  Text('Section: ${widget.student.section}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCountBox(String status, int count) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      decoration: BoxDecoration(
        color: statusLightColor(status),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: statusColor(status),
            ),
          ),
          Text(
            status,
            textAlign: TextAlign.center,
            style: TextStyle(color: statusColor(status)),
          ),
        ],
      ),
    );
  }

  Widget buildSummaryCard() {
    final colorScheme = Theme.of(context).colorScheme;
    int present = countStatus('Present');
    int absent = countStatus('Absent');
    int tardy = countStatus('Tardy');
    int total = records.length;

    // Attendance Rate = Present / Total Records x 100
    // (Tardy is NOT counted as Present)
    double rate = 0;
    if (total > 0) {
      rate = present / total * 100;
    }

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance Summary',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 16) / 3;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: buildCountBox('Present', present),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: buildCountBox('Absent', absent),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: buildCountBox('Tardy', tardy),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Total Records: $total',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'Attendance Rate',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${rate.round()}%',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const Text(
              'Rate = Present records / Total records x 100 (Tardy is not counted as Present).',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHistoryCard() {
    final colorScheme = Theme.of(context).colorScheme;
    List<Widget> rows = [];

    for (Attendance record in records) {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(dateToReadable(record.date))),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No attendance records found.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ...rows,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Details')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final landscape = constraints.maxWidth >= 700 &&
                      constraints.maxWidth > constraints.maxHeight;
                  if (landscape) {
                    final leftWidth = (constraints.maxWidth * .4)
                        .clamp(300.0, 380.0)
                        .toDouble();
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: leftWidth,
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  8,
                                  12,
                                ),
                                children: [
                                  buildInfoCard(),
                                  const SizedBox(height: 8),
                                  buildSummaryCard(),
                                ],
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(
                                  4,
                                  10,
                                  12,
                                  12,
                                ),
                                child: buildHistoryCard(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          buildInfoCard(),
                          const SizedBox(height: 8),
                          buildSummaryCard(),
                          const SizedBox(height: 8),
                          buildHistoryCard(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
