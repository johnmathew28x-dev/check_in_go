import 'package:checkingo/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Make the test screen phone-sized and tall enough to show the lists
void setPhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// Start the app with empty storage (sample students are added automatically)
Future<void> startApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  setPhoneScreen(tester);
  await tester.pumpWidget(const CheckInGoApp());
  await tester.pumpAndSettle();
}

// Login with the sample account
Future<void> login(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'teacher');
  await tester.enterText(find.byType(TextFormField).at(1), '1234');
  await tester.tap(find.text('LOGIN'));
  await tester.pumpAndSettle();
}

// Login, then open the Students page
Future<void> openStudentsPage(WidgetTester tester) async {
  await startApp(tester);
  await login(tester);
  await tester.tap(find.text('View Students'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('App starts and shows the login page', (tester) async {
    await startApp(tester);

    expect(find.text('CheckInGo'), findsOneWidget);
    expect(find.text('Teacher Attendance Tracking System'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('Login shows validation messages for empty fields', (tester) async {
    await startApp(tester);

    await tester.tap(find.text('LOGIN'));
    await tester.pumpAndSettle();

    expect(find.text('Username is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('Login shows an error for wrong password', (tester) async {
    await startApp(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'teacher');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tester.tap(find.text('LOGIN'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid username or password.'), findsOneWidget);
  });

  testWidgets('Login with teacher / 1234 opens the dashboard', (tester) async {
    await startApp(tester);
    await login(tester);

    expect(find.text('Welcome, Teacher!'), findsOneWidget);
    expect(find.text('Total Students'), findsOneWidget);
    expect(find.text('8'), findsOneWidget); // 8 sample students
  });

  testWidgets('Students page shows the sample students', (tester) async {
    await openStudentsPage(tester);

    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('Maria Santos'), findsOneWidget);
  });

  testWidgets('Add a student', (tester) async {
    await openStudentsPage(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '009');
    await tester.enterText(find.byType(TextFormField).at(1), 'Test Student');

    Finder addButton = find.widgetWithText(ElevatedButton, 'Add Student');
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('Student added successfully.'), findsOneWidget);
  });

  testWidgets('Duplicate student ID is not allowed', (tester) async {
    await openStudentsPage(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '001');
    await tester.enterText(find.byType(TextFormField).at(1), 'Another Student');

    Finder addButton = find.widgetWithText(ElevatedButton, 'Add Student');
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('Student ID already exists.'), findsOneWidget);
  });

  testWidgets('Edit a student', (tester) async {
    await openStudentsPage(tester);

    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), 'Juan Updated');

    Finder saveButton = find.widgetWithText(ElevatedButton, 'Save Changes');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Student updated successfully.'), findsOneWidget);
    expect(find.text('Juan Updated'), findsOneWidget);
  });

  testWidgets('Delete a student', (tester) async {
    await openStudentsPage(tester);

    await tester.tap(find.byIcon(Icons.delete).first);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Are you sure you want to delete this student?'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Student deleted successfully.'), findsOneWidget);
    expect(find.text('Juan Dela Cruz'), findsNothing);
  });

  testWidgets('View student attendance summary', (tester) async {
    await openStudentsPage(tester);

    await tester.tap(find.byIcon(Icons.visibility).first);
    await tester.pumpAndSettle();

    expect(find.text('Attendance Summary'), findsOneWidget);
    expect(find.text('Attendance Rate'), findsOneWidget);
    expect(find.text('Attendance History'), findsOneWidget);
  });

  testWidgets('Take attendance, save it, and view the records', (tester) async {
    await startApp(tester);
    await login(tester);

    // Take attendance
    await tester.tap(find.text('Take Attendance'));
    await tester.pumpAndSettle();

    // Mark the first student as Absent
    await tester.tap(find.text('Absent').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Attendance'));
    await tester.pumpAndSettle();

    expect(find.text('Attendance saved successfully!'), findsOneWidget);

    // Go back to the dashboard
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Open the records
    await tester.tap(find.text('Attendance Records'));
    await tester.pumpAndSettle();

    expect(find.text('No attendance records found.'), findsNothing);
    expect(find.textContaining('BSIT-3B'), findsWidgets);
  });

  testWidgets('Logout returns to the login page', (tester) async {
    await startApp(tester);
    await login(tester);

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    expect(find.text('Are you sure you want to logout?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Logout'));
    await tester.pumpAndSettle();

    expect(find.text('Teacher Attendance Tracking System'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
  });
}
