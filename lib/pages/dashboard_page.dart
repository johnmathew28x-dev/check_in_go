import 'package:flutter/material.dart';

import '../models/attendance.dart';
import '../models/student.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../utils/helpers.dart';
import 'attendance_records_page.dart';
import 'login_page.dart';
import 'profile_page.dart';
import 'students_page.dart';
import 'take_attendance_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final StorageService storage = StorageService();
  List<Student> students = [];
  List<Attendance> attendance = [];
  bool isLoading = true;
  int selectedIndex = 0;
  final List<int> _tabVisits = [0, 0, 0, 0, 0];

  static const _pageTitles = [
    'CheckInGo',
    'Students',
    'Take Attendance',
    'Attendance Records',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final loadedStudents = await storage.loadStudents();
      final loadedAttendance = await storage.loadAttendance();
      if (!mounted) return;
      setState(() {
        students = loadedStudents;
        attendance = loadedAttendance;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load the dashboard data.')),
      );
    }
  }

  int countToday(String status) {
    final today = dateToStorage(DateTime.now());
    return attendance
        .where((record) => record.date == today && record.status == status)
        .length;
  }

  void selectTab(int index) {
    if (index < 0 || index >= _pageTitles.length) return;
    if (selectedIndex == index) {
      if (index == 0) loadData();
      return;
    }
    setState(() {
      selectedIndex = index;
      _tabVisits[index]++;
    });
    if (index == 0) loadData();
  }

  Future<void> confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign in again to manage your classes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (shouldLogout != true) return;

    try {
      await AuthService().signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please try again.')),
      );
    }
  }

  Widget buildStatCard({
    required String label,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.toString(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF17324D),
                        ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF617386),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildQuickAction({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF617386),
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final present = countToday('Present');
    final absent = countToday('Absent');
    final tardy = countToday('Tardy');
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.sizeOf(context);
    final isLandscape = screenSize.width > screenSize.height;

    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitles[selectedIndex]),
        actions: selectedIndex == 4
            ? const []
            : [
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'Sign out',
                  onPressed: confirmLogout,
                ),
                const SizedBox(width: 4),
              ],
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: loadData,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        children: [
                          Container(
                            padding: EdgeInsets.all(isLandscape ? 14 : 18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF173B59), Color(0xFF137C72)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.school_outlined,
                                      color: Colors.white70,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(
                                        'NORTHEASTERN COLLEGE',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: Colors.white70,
                                              letterSpacing: 1.1,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: isLandscape ? 9 : 16),
                                Text(
                                  'Good day, Teacher',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Your classes at a glance',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.white70),
                                ),
                                SizedBox(height: isLandscape ? 9 : 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.13),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    dateTimeToReadable(DateTime.now()),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: isLandscape ? 12 : 20),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Today’s overview',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              Text(
                                '${present + absent + tardy} marked',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(color: colorScheme.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final columns =
                                  constraints.maxWidth >= 720 ? 4 : 2;
                              return GridView.count(
                                crossAxisCount: columns,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: columns == 4
                                    ? 1.5
                                    : constraints.maxWidth < 360
                                        ? 1.45
                                        : 1.85,
                                children: [
                                  buildStatCard(
                                    label: 'Students',
                                    value: students.length,
                                    icon: Icons.people_alt_outlined,
                                    color: colorScheme.primary,
                                  ),
                                  buildStatCard(
                                    label: 'Present',
                                    value: present,
                                    icon: Icons.check_circle_outline,
                                    color: statusColor('Present'),
                                  ),
                                  buildStatCard(
                                    label: 'Absent',
                                    value: absent,
                                    icon: Icons.cancel_outlined,
                                    color: statusColor('Absent'),
                                  ),
                                  buildStatCard(
                                    label: 'Tardy',
                                    value: tardy,
                                    icon: Icons.schedule_rounded,
                                    color: statusColor('Tardy'),
                                  ),
                                ],
                              );
                            },
                          ),
                          if (present + absent + tardy == 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                'No attendance has been saved for today yet.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: const Color(0xFF617386),
                                    ),
                              ),
                            ),
                          SizedBox(height: isLandscape ? 14 : 22),
                          Text(
                            'Quick actions',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 10),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final actions = [
                                buildQuickAction(
                                  title: 'Take attendance',
                                  subtitle: 'Mark today’s class in a few taps',
                                  icon: Icons.fact_check_outlined,
                                  onTap: () => selectTab(2),
                                ),
                                buildQuickAction(
                                  title: 'Manage students',
                                  subtitle:
                                      '${students.length} students in your roster',
                                  icon: Icons.people_outline,
                                  onTap: () => selectTab(1),
                                ),
                                buildQuickAction(
                                  title: 'Attendance records',
                                  subtitle:
                                      'Review saved attendance by date and section',
                                  icon: Icons.receipt_long_outlined,
                                  onTap: () => selectTab(3),
                                ),
                              ];
                              if (constraints.maxWidth >= 720) {
                                return Row(
                                  children: [
                                    for (var index = 0;
                                        index < actions.length;
                                        index++) ...[
                                      if (index > 0) const SizedBox(width: 8),
                                      Expanded(child: actions[index]),
                                    ],
                                  ],
                                );
                              }
                              return Column(
                                children: [
                                  actions[0],
                                  const SizedBox(height: 8),
                                  actions[1],
                                  const SizedBox(height: 8),
                                  actions[2],
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          StudentsPage(
            key: ValueKey('students-${_tabVisits[1]}'),
            embedded: true,
          ),
          TakeAttendancePage(
            key: ValueKey('attendance-${_tabVisits[2]}'),
            embedded: true,
          ),
          AttendanceRecordsPage(
            key: ValueKey('records-${_tabVisits[3]}'),
            embedded: true,
          ),
          ProfilePage(onSignOut: confirmLogout),
        ],
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 390 ||
              MediaQuery.sizeOf(context).height < 500;
          return NavigationBar(
            height: compact ? 64 : 72,
            selectedIndex: selectedIndex,
            onDestinationSelected: selectTab,
            labelBehavior: compact
                ? NavigationDestinationLabelBehavior.onlyShowSelected
                : NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Home',
              ),
              const NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people_rounded),
                label: 'Students',
              ),
              NavigationDestination(
                icon: const Icon(Icons.fact_check_outlined),
                selectedIcon: const Icon(Icons.fact_check_rounded),
                label: compact ? 'Attend' : 'Attendance',
              ),
              const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Records',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          );
        },
      ),
    );
  }
}
