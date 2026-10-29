class Student {
  String id;
  String name;
  String course;
  String section;

  Student({
    required this.id,
    required this.name,
    required this.course,
    required this.section,
  });

  // Convert a Student object to a Map so it can be saved as JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'course': course,
      'section': section,
    };
  }

  Map<String, dynamic> toSupabaseJson(String ownerId) {
    return {
      'owner_id': ownerId,
      'id': id,
      'name': name,
      'course': course,
      'section': section,
    };
  }

  // Create a Student object from a Map that was loaded from JSON
  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      name: json['name'],
      course: json['course'],
      section: json['section'],
    );
  }

  factory Student.fromSupabaseJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as String,
      name: json['name'] as String,
      course: json['course'] as String,
      section: json['section'] as String,
    );
  }
}
