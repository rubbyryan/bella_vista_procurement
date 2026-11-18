import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'models.dart';
import 'state.dart';

/// Departments the administrator can pick for a user. The backend stores the
/// department as free text, so any value already on a user is kept as well.
const kUserDepartments = [
  'Science', 'Mathematics', 'Humanities', 'Languages', 'Sports', 'Administration',
  'Boarding', 'Kitchen / Dining', 'Library', 'ICT', 'Facilities', 'Matron',
  'Stores', 'Transport', 'Security', 'Operations', 'Head Office',
];

// ---------------------------------------------------------------------------
// Roles. The backend (UserRole enum) has 25 roles; the app's screens and
// permissions are built around 9 (Role in models.dart). [appRole] says which
// set of screens a backend role gets. Any role not listed as something more
// specific below gets Requester-level screens: change the mapping here.
// ---------------------------------------------------------------------------
class BackendRole {
  const BackendRole(this.code, this.label, this.appRole);
  final String code;
  final String label;
  final Role appRole;
}

const kBackendRoles = <BackendRole>[
  BackendRole('REQUESTER', 'Requester', Role.requester),
  BackendRole('STOCK_CONTROLLER', 'Stock Controller', Role.stores),
  BackendRole('SCHOOL_HEAD', 'School Head', Role.head),
  BackendRole('OPERATIONS_MANAGER', 'Operations Manager', Role.om),
  BackendRole('OD1', 'OD1', Role.od1),
  BackendRole('OD2', 'OD2', Role.od2),
  BackendRole('RA', 'RA', Role.ra),
  BackendRole('SECURITY_OFFICER', 'Security Officer', Role.security),
  BackendRole('SYSTEM_ADMIN', 'System Administrator', Role.admin),
  BackendRole('SUPER_ADMIN', 'Super Administrator', Role.admin),
  BackendRole('FRO', 'FRO', Role.requester),
  BackendRole('DEPUTY_HEAD', 'Deputy Head', Role.requester),
  BackendRole('HOA', 'HOA', Role.requester),
  BackendRole('TIC_JNR', 'TIC JNR', Role.requester),
  BackendRole('TIC_HIGH', 'TIC HIGH', Role.requester),
  BackendRole('TEACHER_HIGH', 'Teacher (High)', Role.requester),
  BackendRole('TEACHER_JNR', 'Teacher (Junior)', Role.requester),
  BackendRole('GROUNDS_PERSON', 'Grounds Person', Role.requester),
  BackendRole('MAINTENANCE_OFFICER', 'Maintenance Officer', Role.requester),
  BackendRole('BOARDING_MASTER', 'Boarding Master', Role.requester),
  BackendRole('CHEF', 'Chef', Role.requester),
  BackendRole('MATRON', 'Matron', Role.requester),
  BackendRole('HOUSE_PARENT', 'House Parent', Role.requester),
  BackendRole('DTL', 'DTL', Role.requester),
  BackendRole('DRIVER', 'Driver', Role.requester),
];

BackendRole? backendRole(String code) {
  for (final r in kBackendRoles) {
    if (r.code == code) return r;
  }
  return null;
}

Role appRoleFor(String code) => backendRole(code)?.appRole ?? Role.requester;

String roleLabel(String code) => backendRole(code)?.label ?? code;

const kSuperAdmin = 'SUPER_ADMIN';
const kSystemAdmin = 'SYSTEM_ADMIN';

// ---------------------------------------------------------------------------
// User model (UserResponse) and request body (UserRequest)
// ---------------------------------------------------------------------------
String _s(dynamic v) => v == null ? '' : '$v';
bool? _b(dynamic v) => v is bool ? v : null;
DateTime? _dt(dynamic v) {
  if (v is String) return DateTime.tryParse(v);
  if (v is List && v.length >= 3) {
    int i(dynamic x) => x is num ? x.toInt() : 0;
    return DateTime(i(v[0]), i(v[1]), i(v[2]), v.length > 3 ? i(v[3]) : 0, v.length > 4 ? i(v[4]) : 0);
  }
  return null;
}

class AppUser {
  AppUser({
    required this.id,
    required this.employeeNumber,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.phoneNumber,
    required this.roleCode,
    required this.department,
    required this.jobTitle,
    this.active,
    this.accountLocked,
    this.lastLogin,
    this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'] is num ? (j['id'] as num).toInt() : int.tryParse('${j['id']}') ?? 0,
    employeeNumber: _s(j['employeeNumber']),
    firstName: _s(j['firstName']),
    lastName: _s(j['lastName']),
    username: _s(j['username']),
    email: _s(j['email']),
    phoneNumber: _s(j['phoneNumber']),
    roleCode: _s(j['role']),
    department: _s(j['department']),
    jobTitle: _s(j['jobTitle']),
    active: _b(j['active']),
    accountLocked: _b(j['accountLocked']),
    lastLogin: _dt(j['lastLogin']),
    createdAt: _dt(j['createdAt']),
  );

  final int id;
  final String employeeNumber;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String phoneNumber;
  final String roleCode;
  final String department;
  final String jobTitle;

  /// null when the server does not send it (UserResponse without the status
  /// fields: see backend_patch/UserResponse.java).
  final bool? active;
  final bool? accountLocked;
  final DateTime? lastLogin;
  final DateTime? createdAt;

  String get name => '$firstName $lastName'.trim();
  String get roleName => roleLabel(roleCode);
}

class UserForm {
  UserForm({
    required this.employeeNumber,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.phoneNumber,
    required this.password,
    required this.roleCode,
    required this.department,
    required this.jobTitle,
  });

  final String employeeNumber;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String phoneNumber;
  final String password; // empty = leave unchanged on update
  final String roleCode;
  final String department;
  final String jobTitle;

  String? _n(String v) => v.trim().isEmpty ? null : v.trim();

  Map<String, dynamic> toJson() => {
    'employeeNumber': employeeNumber.trim(),
    'firstName': firstName.trim(),
    'lastName': lastName.trim(),
    'username': username.trim(),
    'email': email.trim(),
    'phoneNumber': _n(phoneNumber),
    if (password.isNotEmpty) 'password': password,
    'role': roleCode,
    'department': _n(department),
    'jobTitle': _n(jobTitle),
  };
}

// ---------------------------------------------------------------------------
// Repository: one method per user-management endpoint
// ---------------------------------------------------------------------------
class UserRepo {
  UserRepo(this.api);
  final ApiClient api;

  AppUser _one(dynamic v) => AppUser.fromJson(Map<String, dynamic>.from(v as Map));

  /// GET /api/procurement/users
  Future<List<AppUser>> all() async =>
      ((await api.get('/users')) as List? ?? []).whereType<Map>().map(_one).toList();

  /// GET /api/procurement/users/{id}
  Future<AppUser> byId(int id) async => _one(await api.get('/users/$id'));

  /// POST /api/procurement/users
  Future<AppUser> create(UserForm f) async => _one(await api.post('/users', body: f.toJson()));

  /// PUT /api/procurement/users/{id}
  Future<AppUser> update(int id, UserForm f) async => _one(await api.put('/users/$id', body: f.toJson()));

  /// DELETE /api/procurement/users/{id} (deactivates the account)
  Future<void> deactivate(int id) => api.delete('/users/$id');

  /// PATCH /api/procurement/users/{id}/activate
  /// SUPER_ADMIN can activate anyone; SYSTEM_ADMIN can activate regular users only.
  Future<void> activate(int id) => api.patch('/users/$id/activate');
}

final userRepoProvider = Provider<UserRepo>((ref) => UserRepo(ref.watch(apiProvider)));
final usersP = FutureProvider.autoDispose<List<AppUser>>((ref) => ref.watch(userRepoProvider).all());
final userByIdP =
FutureProvider.autoDispose.family<AppUser, int>((ref, id) => ref.watch(userRepoProvider).byId(id));