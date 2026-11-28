import 'package:flutter/foundation.dart';

export '../../../core/domain/status_filter.dart';

/// An employee as returned by `/staff` (never includes the password).
@immutable
class Employee {
  const Employee({
    required this.id,
    required this.fullName,
    required this.roleId,
    required this.roleName,
    required this.isActive,
    required this.performsServices,
    required this.version,
    this.mobile,
    this.email,
    this.joinedOn,
    this.username,
  });

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
    id: json['id'] as int,
    fullName: json['fullName'] as String,
    mobile: json['mobile'] as String?,
    email: json['email'] as String?,
    roleId: json['roleId'] as int,
    roleName: json['roleName'] as String,
    isActive: json['isActive'] as bool,
    performsServices: json['performsServices'] as bool,
    joinedOn: json['joinedOn'] as String?,
    username: json['username'] as String?,
    version: json['version'] as int,
  );

  final int id;
  final String fullName;
  final String? mobile;
  final String? email;
  final int roleId;
  final String roleName;
  final bool isActive;
  final bool performsServices;

  /// 'YYYY-MM-DD'.
  final String? joinedOn;

  /// Null when this employee cannot sign in.
  final String? username;

  /// Sent back with every edit so two people can't overwrite each other.
  final int version;

  bool get canSignIn => username != null;
}

@immutable
class RoleOption {
  const RoleOption({required this.id, required this.name});

  factory RoleOption.fromJson(Map<String, dynamic> json) =>
      RoleOption(id: json['id'] as int, name: json['name'] as String);

  final int id;
  final String name;

  @override
  bool operator ==(Object other) => other is RoleOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// One page of the employee list.
@immutable
class EmployeePage {
  const EmployeePage({required this.items, required this.total});

  final List<Employee> items;
  final int total;

  bool get hasMore => items.length < total;
}

/// Values the employee form sends. Null optional fields clear the value.
@immutable
class EmployeeDraft {
  const EmployeeDraft({
    required this.fullName,
    required this.roleId,
    required this.performsServices,
    this.mobile,
    this.email,
    this.joinedOn,
  });

  final String fullName;
  final String? mobile;
  final String? email;
  final int roleId;
  final bool performsServices;
  final String? joinedOn;

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'mobile': mobile,
    'email': email,
    'roleId': roleId,
    'performsServices': performsServices,
    'joinedOn': joinedOn,
  };
}
