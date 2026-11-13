import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';

/// Demo accounts only. Nothing here talks to the backend: accounts live in
/// memory and reset when the page is reloaded. Replace this file's methods with
/// API calls (register, login, list users, update access) when the backend is
/// ready.
const kDemoPassword = 'Bella@2026';

/// Departments the System Administrator can assign to a user.
const kUserDepartments = [
  'Science', 'Mathematics', 'Humanities', 'Languages', 'Sports', 'Administration',
  'Boarding', 'Kitchen / Dining', 'Library', 'ICT', 'Facilities', 'Matron',
  'Stores', 'Transport', 'Security', 'Operations', 'Head Office',
];

/// Mirrors the backend user fields (UserResponseDTO). The password is kept here
/// only because this is the in-memory demo; a real API never returns it.
class AppUser {
  AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.password,
    required this.role,
    this.employeeNumber = '',
    this.phoneNumber = '',
    this.department = '',
    this.jobTitle = '',
    this.active = true,
    this.accountLocked = false,
    this.lastLogin,
    DateTime? createdAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = createdAt ?? DateTime.now();

  final String id;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String password;
  final String employeeNumber;
  final String phoneNumber;
  final String jobTitle;
  final DateTime createdAt;
  String department; // empty until the administrator assigns one
  Role role;
  bool active;
  bool accountLocked;
  DateTime? lastLogin;
  DateTime updatedAt;

  String get name => '$firstName $lastName'.trim();
}

class UserStore extends ChangeNotifier {
  final List<AppUser> users = [
    _seed('u_requester', 'Tendai', 'Moyo', 'requester', Role.requester, 'Science', 'BV-0231'),
    _seed('u_stores', 'Rudo', 'Chigumba', 'stores', Role.stores, 'Stores', 'BV-0118'),
    _seed('u_head', 'Farai', 'Ncube', 'head', Role.head, 'Administration', 'BV-0007'),
    _seed('u_om', 'Blessing', 'Sibanda', 'om', Role.om, 'Operations', 'BV-0042'),
    _seed('u_od1', 'Tafara', 'Dube', 'od1', Role.od1, 'Head Office', 'BV-0003'),
    _seed('u_od2', 'Nyasha', 'Mutasa', 'od2', Role.od2, 'Head Office', 'BV-0004'),
    _seed('u_ra', 'Chipo', 'Mlambo', 'ra', Role.ra, 'Head Office', 'BV-0001'),
    _seed('u_security', 'S.', 'Mhlanga', 'security', Role.security, 'Security', 'BV-0390'),
    _seed('u_admin', 'Admin', 'User', 'admin', Role.admin, 'ICT', 'BV-0002'),
    AppUser(
      id: 'u_pending',
      firstName: 'Kudzai',
      lastName: 'Banda',
      username: 'kbanda',
      email: 'kbanda@bellavista.ac.zw',
      phoneNumber: '+263 77 123 4567',
      password: kDemoPassword,
      role: Role.requester,
      active: false,
    ),
  ];

  static AppUser _seed(String id, String first, String last, String mail, Role role, String dept, String emp) =>
      AppUser(
        id: id,
        firstName: first,
        lastName: last,
        username: mail,
        email: '$mail@bellavista.ac.zw',
        employeeNumber: emp,
        department: dept,
        role: role,
        password: kDemoPassword,
      );

  int _seq = 0;
  int _failedLogins = 0;
  DateTime? _lockedUntil;

  /// Sign in with email, username or employee number.
  ({AppUser? user, String? error}) login(String identifier, String password) {
    final now = DateTime.now();
    if (_lockedUntil != null && now.isBefore(_lockedUntil!)) {
      final mins = _lockedUntil!.difference(now).inMinutes + 1;
      return (user: null, error: 'Too many failed attempts. Try again in $mins min.');
    }
    final key = identifier.trim().toLowerCase();
    AppUser? u;
    for (final x in users) {
      if (x.email.toLowerCase() == key ||
          x.username.toLowerCase() == key ||
          (x.employeeNumber.isNotEmpty && x.employeeNumber.toLowerCase() == key)) {
        u = x;
        break;
      }
    }
    if (u == null || u.password != password) {
      _failedLogins++;
      if (_failedLogins >= 5) {
        _lockedUntil = now.add(const Duration(minutes: 15));
        _failedLogins = 0;
        return (user: null, error: 'Too many failed attempts. Locked for 15 minutes.');
      }
      return (user: null, error: 'Incorrect email / username or password.');
    }
    if (u.accountLocked) {
      return (user: null, error: 'Your account is locked. Please contact the System Administrator.');
    }
    if (!u.active) {
      return (user: null, error: 'Your account is pending activation by the System Administrator.');
    }
    _failedLogins = 0;
    u.lastLogin = now;
    notifyListeners();
    return (user: u, error: null);
  }

  /// Self-registration. The account starts inactive with the Requester role and
  /// no department; the System Administrator assigns those and activates it.
  String? register({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required String password,
  }) {
    final mail = email.trim().toLowerCase();
    if (users.any((u) => u.email.toLowerCase() == mail)) {
      return 'An account with that email already exists.';
    }
    // Username is derived from the email address (made unique if needed).
    final base = mail.split('@').first;
    var username = base;
    var n = 1;
    while (users.any((u) => u.username.toLowerCase() == username)) {
      username = '$base${++n}';
    }
    users.add(AppUser(
      id: 'u_new${++_seq}',
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      username: username,
      email: email.trim(),
      phoneNumber: phoneNumber.trim(),
      password: password,
      role: Role.requester,
      active: false,
    ));
    notifyListeners();
    return null;
  }

  /// Saves role, department and active flag together. Returns an error message,
  /// or null on success. [isSelf] is true when the administrator is editing
  /// their own account.
  String? updateUserAccess(
    AppUser u, {
    required Role role,
    required String department,
    required bool active,
    required bool isSelf,
  }) {
    if (isSelf && (role != u.role || !active)) {
      return 'You cannot change your own role or deactivate your own account.';
    }
    if (active && department.isEmpty) {
      return 'Select a department before activating this account.';
    }
    u.role = role;
    u.department = department;
    u.active = active;
    if (active) u.accountLocked = false;
    u.updatedAt = DateTime.now();
    notifyListeners();
    return null;
  }
}

final userStoreProvider = ChangeNotifierProvider<UserStore>((ref) => UserStore());
