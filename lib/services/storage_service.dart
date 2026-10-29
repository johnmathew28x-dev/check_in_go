import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../utils/helpers.dart';

/// Persists debug demo data locally or production data in the signed-in
/// teacher's Supabase account.
class StorageService {
  static const _sectionsPreferenceKey = 'managed_sections';
  static const _secureStorage = FlutterSecureStorage();
  static const _maxCachedAttendanceRows = 10000;
  final Set<String> _offlineTables = {};

  SupabaseClient get _client => Supabase.instance.client;
  bool get isUsingOfflineCache => _offlineTables.isNotEmpty;

  String get _ownerId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in before accessing Supabase data.');
    }
    return userId;
  }

  void _requireDemoMode() {
    if (!SupabaseConfig.isDemoMode) {
      throw StateError('Cloud sign-in is required to access attendance data.');
    }
  }

  String _cacheKey(String ownerId, String table) =>
      'checkingo.offline.$ownerId.$table';

  String _pendingAttendanceKey(String ownerId) =>
      'checkingo.offline.$ownerId.pending_attendance';

  bool _isNetworkFailure(Object error) {
    final message = '${error.runtimeType} $error'.toLowerCase();
    return message.contains('socketexception') ||
        message.contains('clientexception') ||
        message.contains('failed host lookup') ||
        message.contains('failed to fetch') ||
        message.contains('networkerror') ||
        message.contains('xmlhttprequest') ||
        message.contains('network is unreachable') ||
        message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('connection closed') ||
        message.contains('handshakeexception') ||
        message.contains('timed out') ||
        message.contains('timeout');
  }

  Future<dynamic> _readOfflineCache(String ownerId, String table) async {
    final value = await _secureStorage.read(key: _cacheKey(ownerId, table));
    return value == null ? null : jsonDecode(value);
  }

  Future<void> _writeOfflineCache(
    String ownerId,
    String table,
    Object value,
  ) async {
    try {
      await _secureStorage.write(
        key: _cacheKey(ownerId, table),
        value: jsonEncode(value),
      );
    } catch (_) {
      // A cache failure must not make a successful cloud read fail.
    }
  }

  Future<List<String>> loadSections() async {
    if (SupabaseConfig.isConfigured) {
      final ownerId = _ownerId;
      try {
        final table = _client.from('checkingo_sections');
        final rows =
            await table.select('name').eq('owner_id', ownerId).order('name');
        final sections = (rows as List<dynamic>)
            .map((row) => row['name'] as String)
            .toList();
        await _writeOfflineCache(ownerId, 'sections', sections);
        _offlineTables.remove('sections');
        return sections;
      } catch (error) {
        if (!_isNetworkFailure(error)) rethrow;
        final cached = await _readOfflineCache(ownerId, 'sections');
        if (cached is! List<dynamic>) rethrow;
        _offlineTables.add('sections');
        return cached.map((section) => section as String).toList();
      }
    }

    _requireDemoMode();
    final prefs = await SharedPreferences.getInstance();
    final storedSections = prefs.getStringList(_sectionsPreferenceKey);
    if (storedSections == null) {
      await prefs.setStringList(_sectionsPreferenceKey, const []);
      return [];
    }
    return storedSections;
  }

  Future<void> addSection(String value) async {
    final name = value.trim().toUpperCase();
    if (name.isEmpty || name.length > 80) {
      throw const FormatException('Section names must be 1–80 characters.');
    }

    final sections = await loadSections();
    if (sections
        .any((section) => section.toLowerCase() == name.toLowerCase())) {
      throw const FormatException('That section already exists.');
    }

    if (SupabaseConfig.isConfigured) {
      await _client.from('checkingo_sections').insert({
        'owner_id': _ownerId,
        'name': name,
      });
      return;
    }

    _requireDemoMode();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_sectionsPreferenceKey, [...sections, name]);
  }

  Future<void> renameSection(String currentName, String value) async {
    final newName = value.trim().toUpperCase();
    if (newName.isEmpty || newName.length > 80) {
      throw const FormatException('Section names must be 1–80 characters.');
    }
    if (newName == currentName) return;

    final sections = await loadSections();
    if (sections.any((section) =>
        section != currentName &&
        section.toLowerCase() == newName.toLowerCase())) {
      throw const FormatException('That section already exists.');
    }

    if (SupabaseConfig.isConfigured) {
      final updated = await _client
          .from('checkingo_sections')
          .update({'name': newName})
          .eq('owner_id', _ownerId)
          .eq('name', currentName)
          .select('name');
      if ((updated as List<dynamic>).isEmpty) {
        throw StateError('The section could not be found. Refresh and retry.');
      }
      return;
    }

    _requireDemoMode();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _sectionsPreferenceKey,
      sections
          .map((section) => section == currentName ? newName : section)
          .toList(),
    );

    final storedStudents = prefs.getString('students');
    if (storedStudents != null) {
      final rows = jsonDecode(storedStudents) as List<dynamic>;
      for (final row in rows) {
        final student = row as Map<String, dynamic>;
        if (student['section'] == currentName) student['section'] = newName;
      }
      await prefs.setString('students', jsonEncode(rows));
    }

    final storedAttendance = prefs.getString('attendance');
    if (storedAttendance != null) {
      final rows = jsonDecode(storedAttendance) as List<dynamic>;
      for (final row in rows) {
        final record = row as Map<String, dynamic>;
        if (record['section'] == currentName) record['section'] = newName;
      }
      await prefs.setString('attendance', jsonEncode(rows));
    }
  }

  Future<void> removeSection(String name) async {
    final sections = await loadSections();
    final students = await loadStudents();
    if (students.any((student) => student.section == name)) {
      throw StateError('Move or remove this section’s students first.');
    }
    final attendance = await loadAttendance();
    if (attendance.any((record) => record.section == name)) {
      throw StateError(
          'This section has attendance history and can’t be removed.');
    }

    if (SupabaseConfig.isConfigured) {
      await _client
          .from('checkingo_sections')
          .delete()
          .eq('owner_id', _ownerId)
          .eq('name', name);
      return;
    }

    _requireDemoMode();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _sectionsPreferenceKey,
      sections.where((section) => section != name).toList(),
    );
  }

  Future<void> saveStudents(List<Student> students) async {
    if (SupabaseConfig.isConfigured) {
      final ownerId = _ownerId;
      if (students.isNotEmpty) {
        await _client.from('checkingo_students').upsert(
              students
                  .map((student) => student.toSupabaseJson(ownerId))
                  .toList(),
              onConflict: 'owner_id,id',
            );
      }
      return;
    }

    _requireDemoMode();
    final prefs = await SharedPreferences.getInstance();
    final existingData = prefs.getString('students');
    final byId = <String, Student>{
      if (existingData != null)
        for (final row in jsonDecode(existingData) as List<dynamic>)
          (row as Map<String, dynamic>)['id'] as String: Student.fromJson(row),
    };
    for (final student in students) {
      byId[student.id] = student;
    }
    await prefs.setString(
      'students',
      jsonEncode(byId.values.map((student) => student.toJson()).toList()),
    );
  }

  Future<void> saveStudent(Student student, {String? originalId}) async {
    if (SupabaseConfig.isConfigured) {
      final ownerId = _ownerId;
      final table = _client.from('checkingo_students');
      if (originalId == null) {
        await table.insert(student.toSupabaseJson(ownerId));
      } else {
        final updated = await table
            .update(student.toSupabaseJson(ownerId))
            .eq('owner_id', ownerId)
            .eq('id', originalId)
            .select('id');
        if ((updated as List<dynamic>).isEmpty) {
          throw StateError('Student not found. Refresh and try again.');
        }
        await _client
            .from('checkingo_attendance')
            .update({'student_name': student.name})
            .eq('owner_id', ownerId)
            .eq('student_id', student.id);
      }
      return;
    }

    _requireDemoMode();
    final prefs = await SharedPreferences.getInstance();
    final students = await loadStudents();
    if (originalId == null) {
      students.add(student);
    } else {
      final index = students.indexWhere((current) => current.id == originalId);
      if (index < 0) throw StateError('Student not found. Refresh and retry.');
      students[index] = student;
      final records = await loadAttendance();
      for (final record
          in records.where((record) => record.studentId == originalId)) {
        record.studentId = student.id;
        record.studentName = student.name;
      }
      await prefs.setString(
        'attendance',
        jsonEncode(records.map((record) => record.toJson()).toList()),
      );
    }
    await prefs.setString(
      'students',
      jsonEncode(students.map((current) => current.toJson()).toList()),
    );
  }

  Future<void> deleteStudent(String id) async {
    if (SupabaseConfig.isConfigured) {
      await _client
          .from('checkingo_students')
          .delete()
          .eq('owner_id', _ownerId)
          .eq('id', id);
      return;
    }

    _requireDemoMode();
    final prefs = await SharedPreferences.getInstance();
    final students =
        (await loadStudents()).where((student) => student.id != id).toList();
    final records = (await loadAttendance())
        .where((record) => record.studentId != id)
        .toList();
    await prefs.setString(
      'students',
      jsonEncode(students.map((student) => student.toJson()).toList()),
    );
    await prefs.setString(
      'attendance',
      jsonEncode(records.map((record) => record.toJson()).toList()),
    );
  }

  Future<List<Student>> loadStudents() async {
    if (SupabaseConfig.isConfigured) {
      final ownerId = _ownerId;
      try {
        final rows = await _client
            .from('checkingo_students')
            .select('id, name, course, section')
            .eq('owner_id', ownerId)
            .order('name');
        final students = (rows as List<dynamic>)
            .map((row) => Student.fromSupabaseJson(row))
            .toList();
        await _writeOfflineCache(
          ownerId,
          'students',
          students.map((student) => student.toJson()).toList(),
        );
        _offlineTables.remove('students');
        return students;
      } catch (error) {
        if (!_isNetworkFailure(error)) rethrow;
        final cached = await _readOfflineCache(ownerId, 'students');
        if (cached is! List<dynamic>) rethrow;
        _offlineTables.add('students');
        return cached
            .map((row) => Student.fromJson(row as Map<String, dynamic>))
            .toList();
      }
    }

    _requireDemoMode();
    await _addSampleDataIfFirstTime();
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('students');
    if (data == null) return [];

    final jsonList = jsonDecode(data) as List<dynamic>;
    return jsonList
        .map((row) => Student.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<bool> saveAttendanceSession({
    required String date,
    required String section,
    required List<Attendance> records,
  }) =>
      _saveAttendanceSession(
        date: date,
        section: section,
        records: records,
        replaceSession: true,
      );

  Future<int> importAttendanceRecords(List<Attendance> records) async {
    final sessions = <String, List<Attendance>>{};
    for (final record in records) {
      final key = jsonEncode([record.date, record.section]);
      sessions.putIfAbsent(key, () => []).add(record);
    }
    for (final session in sessions.values) {
      await _saveAttendanceSession(
        date: session.first.date,
        section: session.first.section,
        records: session,
        replaceSession: false,
      );
    }
    return records.length;
  }

  Future<bool> _saveAttendanceSession({
    required String date,
    required String section,
    required List<Attendance> records,
    required bool replaceSession,
  }) async {
    if (records.isEmpty ||
        records.any(
            (record) => record.date != date || record.section != section)) {
      throw const FormatException(
          'Attendance rows must use one date and section.');
    }

    if (SupabaseConfig.isConfigured) {
      final ownerId = _ownerId;
      try {
        await _client.rpc(
          'checkingo_save_attendance_session',
          params: {
            'p_attendance_date': date,
            'p_section': section,
            'p_records': records
                .map((record) => {
                      'student_id': record.studentId,
                      'student_name': record.studentName,
                      'status': record.status,
                    })
                .toList(),
            'p_replace_session': replaceSession,
          },
        );
        try {
          final cached = await _readCachedAttendance(ownerId);
          if (cached != null) {
            final updated = _mergeAttendanceSession(
              cached,
              date,
              section,
              records,
              replaceSession: replaceSession,
            );
            await _cacheAttendance(ownerId, updated);
          }
        } catch (_) {
          // A local cache failure must not make a successful cloud save fail.
        }
        _offlineTables.remove('attendance');
        return true;
      } catch (error) {
        if (!_isNetworkFailure(error)) rethrow;
        await _enqueueAttendanceSession(
          ownerId,
          date,
          section,
          records,
          replaceSession: replaceSession,
        );
        try {
          final cached = await _readCachedAttendance(ownerId) ?? <Attendance>[];
          await _cacheAttendance(
            ownerId,
            _mergeAttendanceSession(
              cached,
              date,
              section,
              records,
              replaceSession: replaceSession,
            ),
          );
        } catch (_) {
          // The queued draft is authoritative if refreshing the cache fails.
        }
        _offlineTables.add('attendance');
        return false;
      }
    }

    _requireDemoMode();
    final prefs = await SharedPreferences.getInstance();
    final current = await loadAttendance();
    final updated = _mergeAttendanceSession(
      current,
      date,
      section,
      records,
      replaceSession: replaceSession,
    );
    await prefs.setString(
      'attendance',
      jsonEncode(updated.map((record) => record.toJson()).toList()),
    );
    return true;
  }

  List<Attendance> _mergeAttendanceSession(
    List<Attendance> current,
    String date,
    String section,
    List<Attendance> incoming, {
    required bool replaceSession,
  }) {
    final byKey = <String, Attendance>{
      for (final record in current)
        if (!(replaceSession &&
            record.date == date &&
            record.section == section))
          _attendanceKey(record): record,
    };
    for (final record in incoming) {
      byKey[_attendanceKey(record)] = record;
    }
    return byKey.values.toList()
      ..sort((left, right) => right.date.compareTo(left.date));
  }

  Future<void> _enqueueAttendanceSession(
    String ownerId,
    String date,
    String section,
    List<Attendance> records, {
    required bool replaceSession,
  }) async {
    final key = _pendingAttendanceKey(ownerId);
    final raw = await _secureStorage.read(key: key);
    final sessions =
        raw == null ? <dynamic>[] : jsonDecode(raw) as List<dynamic>;
    final sessionKey = jsonEncode([date, section]);
    final existingIndex = sessions.indexWhere((item) {
      final row = item as Map<String, dynamic>;
      return jsonEncode([row['date'], row['section']]) == sessionKey;
    });
    var savedRecords = records;
    var shouldReplace = replaceSession;
    if (existingIndex >= 0) {
      final existing = sessions.removeAt(existingIndex);
      shouldReplace = replaceSession || existing['replace_session'] == true;
      if (!replaceSession) {
        final merged = <String, Attendance>{
          for (final row in existing['records'] as List<dynamic>)
            _attendanceKey(
              Attendance.fromJson(row),
            ): Attendance.fromJson(row),
          for (final record in records) _attendanceKey(record): record,
        };
        savedRecords = merged.values.toList();
      }
    }
    sessions.add({
      'date': date,
      'section': section,
      'replace_session': shouldReplace,
      'records': savedRecords.map((record) => record.toJson()).toList(),
    });
    await _secureStorage.write(key: key, value: jsonEncode(sessions));
  }

  Future<void> _syncPendingAttendance(String ownerId) async {
    final key = _pendingAttendanceKey(ownerId);
    final raw = await _secureStorage.read(key: key);
    if (raw == null) return;
    final sessions = jsonDecode(raw) as List<dynamic>;
    final remaining = <dynamic>[];
    for (final item in sessions) {
      final session = item as Map<String, dynamic>;
      final records = (session['records'] as List<dynamic>)
          .map((row) => Attendance.fromJson(row as Map<String, dynamic>))
          .toList();
      try {
        await _client.rpc(
          'checkingo_save_attendance_session',
          params: {
            'p_attendance_date': session['date'],
            'p_section': session['section'],
            'p_records': records
                .map((record) => {
                      'student_id': record.studentId,
                      'student_name': record.studentName,
                      'status': record.status,
                    })
                .toList(),
            'p_replace_session': session['replace_session'] == true,
          },
        );
      } catch (_) {
        remaining.add(item);
        remaining.addAll(sessions.skip(sessions.indexOf(item) + 1));
        _offlineTables.add('attendance');
        await _secureStorage.write(key: key, value: jsonEncode(remaining));
        return;
      }
    }
    await _secureStorage.delete(key: key);
    _offlineTables.remove('attendance');
  }

  Future<List<Attendance>?> _readCachedAttendance(String ownerId) async {
    final cached = await _readOfflineCache(ownerId, 'attendance');
    if (cached is! List<dynamic>) return null;
    return cached
        .map((row) => Attendance.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> _cacheAttendance(
    String ownerId,
    List<Attendance> records,
  ) async {
    final recent = records.take(_maxCachedAttendanceRows).toList();
    await _writeOfflineCache(
      ownerId,
      'attendance',
      recent.map((record) => record.toJson()).toList(),
    );
  }

  Future<List<Attendance>> loadAttendance() async {
    if (SupabaseConfig.isConfigured) {
      final ownerId = _ownerId;
      await _syncPendingAttendance(ownerId);
      try {
        final rows = await _client
            .from('checkingo_attendance')
            .select(
                'student_id, student_name, attendance_date, section, status')
            .eq('owner_id', ownerId)
            .order('attendance_date', ascending: false);
        var attendance = (rows as List<dynamic>)
            .map((row) => Attendance.fromSupabaseJson(row))
            .toList();
        attendance = await _mergePendingIntoCache(ownerId, attendance);
        await _cacheAttendance(ownerId, attendance);
        if (await _pendingSessionCount(ownerId) == 0) {
          _offlineTables.remove('attendance');
        }
        return attendance;
      } catch (error) {
        if (!_isNetworkFailure(error)) rethrow;
        final cached = await _readCachedAttendance(ownerId);
        if (cached == null) rethrow;
        final attendance = await _mergePendingIntoCache(ownerId, cached);
        _offlineTables.add('attendance');
        return attendance;
      }
    }

    _requireDemoMode();
    await _addSampleDataIfFirstTime();
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('attendance');
    if (data == null) return [];

    final jsonList = jsonDecode(data) as List<dynamic>;
    return jsonList
        .map((row) => Attendance.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  String _attendanceKey(Attendance record) =>
      jsonEncode([record.studentId, record.date, record.section]);

  Future<int> _pendingSessionCount(String ownerId) async {
    final raw = await _secureStorage.read(key: _pendingAttendanceKey(ownerId));
    if (raw == null) return 0;
    return (jsonDecode(raw) as List<dynamic>).length;
  }

  Future<List<Attendance>> _mergePendingIntoCache(
    String ownerId,
    List<Attendance> records,
  ) async {
    final raw = await _secureStorage.read(key: _pendingAttendanceKey(ownerId));
    if (raw == null) return records;
    var result = records;
    for (final item in jsonDecode(raw) as List<dynamic>) {
      final session = item as Map<String, dynamic>;
      final incoming = (session['records'] as List<dynamic>)
          .map((row) => Attendance.fromJson(row as Map<String, dynamic>))
          .toList();
      result = _mergeAttendanceSession(
        result,
        session['date'] as String,
        session['section'] as String,
        incoming,
        replaceSession: session['replace_session'] == true,
      );
    }
    return result;
  }

  Future<void> _addSampleDataIfFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('sample_data_added') ?? false) return;

    final students = _getSampleStudents();
    await prefs.setString(
      'students',
      jsonEncode(students.map((student) => student.toJson()).toList()),
    );
    final records = _getSampleAttendance(students);
    await prefs.setString(
      'attendance',
      jsonEncode(records.map((record) => record.toJson()).toList()),
    );
    await prefs.setBool('sample_data_added', true);
  }

  List<Student> _getSampleStudents() {
    const course = 'BS Information Technology';
    const section = 'BSIT-3B';
    return [
      Student(
          id: '001', name: 'Juan Dela Cruz', course: course, section: section),
      Student(
          id: '002', name: 'Maria Santos', course: course, section: section),
      Student(
          id: '003', name: 'Pedro Garcia', course: course, section: section),
      Student(id: '004', name: 'Ana Reyes', course: course, section: section),
      Student(id: '005', name: 'Mark Reyes', course: course, section: section),
      Student(id: '006', name: 'John Santos', course: course, section: section),
      Student(
          id: '007', name: 'Carla Garcia', course: course, section: section),
      Student(
          id: '008', name: 'Michael Cruz', course: course, section: section),
    ];
  }

  List<Attendance> _getSampleAttendance(List<Student> students) {
    final records = <Attendance>[];
    final today = DateTime.now();

    for (var day = 1; day <= 4; day++) {
      final dateText = dateToStorage(today.subtract(Duration(days: day)));
      for (var i = 0; i < students.length; i++) {
        var status = 'Present';
        if ((i + day) % 5 == 0) {
          status = 'Absent';
        } else if ((i + day) % 4 == 0) {
          status = 'Tardy';
        }
        records.add(Attendance(
          studentId: students[i].id,
          studentName: students[i].name,
          date: dateText,
          section: students[i].section,
          status: status,
        ));
      }
    }
    return records;
  }
}
