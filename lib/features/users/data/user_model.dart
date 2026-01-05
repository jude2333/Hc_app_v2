class User {
  final String empId;
  final String id;
  final String name;
  final String firstName;
  final String lastName;
  final String mobile;
  final String roleName;
  final dynamic roleId; // Can be String or List
  final String departmentId;
  final String departmentName;
  final String photoIdCard;
  final String idCardLocation;
  final List<dynamic> allocatedAreas;

  User({
    required this.empId,
    required this.id,
    required this.name,
    required this.firstName,
    required this.lastName,
    required this.mobile,
    required this.roleName,
    this.roleId,
    required this.departmentId,
    required this.departmentName,
    required this.photoIdCard,
    required this.idCardLocation,
    required this.allocatedAreas,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      empId: json['emp_id']?.toString() ?? '',
      id: json['_id']?.toString() ?? '',
      name: json['name'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      mobile: json['mobile'] ?? '',
      roleName: json['role_name'] ?? '',
      roleId: json['role_id'],
      departmentId: json['department_id']?.toString() ?? '',
      departmentName: json['department_name'] ?? '',
      photoIdCard: json['photo_id_card'] ?? '',
      idCardLocation: json['id_card_location'] ?? '',
      allocatedAreas:
          json['allocated_areas'] is List ? json['allocated_areas'] : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'emp_id': empId,
      '_id': id,
      'name': name,
      'first_name': firstName,
      'last_name': lastName,
      'mobile': mobile,
      'role_name': roleName,
      'role_id': roleId,
      'department_id': departmentId,
      'department_name': departmentName,
      'photo_id_card': photoIdCard,
      'id_card_location': idCardLocation,
      'allocated_areas': allocatedAreas,
    };
  }
}
