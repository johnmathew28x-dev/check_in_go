class Attendance {
  String studentId;
  String studentName;
  String date; // saved like this: 2026-09-19
  String section;
  String status; // Present, Absent, or Tardy

  Attendance({
    required this.studentId,
    required this.studentName,
    required this.date,
    required this.section,
    required this.status,
  });

  // Convert an Attendance object to a Map so it can be saved as JSON
  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'date': date,
      'section': section,
      'status': status,
    };
  }

  Map<String, dynamic> toSupabaseJson(String ownerId) {
    return {
      'owner_id': ownerId,
      'student_id': studentId,
      'student_name': studentName,
      'attendance_date': date,
      'section': section,
      'status': status,
    };
  }

  // Create an Attendance object from a Map that was loaded from JSON
  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      studentId: json['studentId'],
      studentName: json['studentName'],
      date: json['date'],
      section: json['section'],
      status: json['status'],
    );
  }

  factory Attendance.fromSupabaseJson(Map<String, dynamic> json) {
    return Attendance(
      studentId: json['student_id'] as String,
      studentName: json['student_name'] as String,
      date: json['attendance_date'] as String,
      section: json['section'] as String,
      status: json['status'] as String,
    );
  }
}
