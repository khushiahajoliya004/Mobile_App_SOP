class UserModel {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String userType;
  final String? companyId;
  final String? distributorId;
  final String? sopId;
  final bool aiEnabled;
  final List<String> permissions;
  final List<String> allowedModules;
  final List<RoleModel> roles;
  final String? branchId;
  final String? branchName;
  final String? branchRole;

  UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    required this.userType,
    this.companyId,
    this.distributorId,
    this.sopId,
    this.aiEnabled = true,
    required this.permissions,
    required this.allowedModules,
    required this.roles,
    this.branchId,
    this.branchName,
    this.branchRole,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Extract permissions from roles -> permissions
    final roles = <RoleModel>[];
    final perms = <String>{};

    if (json['roles'] != null) {
      for (final r in json['roles']) {
        roles.add(RoleModel.fromJson(r));
        if (r['permissions'] != null) {
          for (final p in r['permissions']) {
            if (p['code'] != null) perms.add(p['code']);
          }
        }
      }
    }

    return UserModel(
      id: json['id'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      userType: json['userType'] ?? 'USER',
      companyId: json['companyId'],
      distributorId: json['distributorId'],
      sopId: json['sopId'],
      aiEnabled: json['aiEnabled'] ?? true,
      permissions: perms.toList(),
      allowedModules: List<String>.from(json['_allowedModules'] ?? []),
      roles: roles,
      branchId: json['branchId'],
      branchName: json['branchName'],
      branchRole: json['branchRole'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'phone': phone,
    'userType': userType,
    'companyId': companyId,
    'distributorId': distributorId,
    'sopId': sopId,
    'aiEnabled': aiEnabled,
    '_allowedModules': allowedModules,
    'roles': roles.map((r) => r.toJson()).toList(),
    'branchId': branchId,
    'branchName': branchName,
    'branchRole': branchRole,
  };

  bool hasPermission(String permission) => permissions.contains(permission);
  bool hasModule(String moduleCode) => allowedModules.contains(moduleCode);

  /// Check if user can access a CRM module (checks MENU_VIEW, VIEW, or LIST)
  bool canAccessCrmModule(String moduleCode) {
    if (isSuperAdmin || isCompanyAdmin) return true;
    return hasPermission('${moduleCode}_MENU_VIEW') ||
        hasPermission('${moduleCode}_VIEW') ||
        hasPermission('${moduleCode}_LIST');
  }

  bool get isSuperAdmin => userType == 'SUPER_ADMIN';
  bool get isCompanyAdmin => userType == 'COMPANY';
  bool get isUser => userType == 'USER';
  bool get isTechnicalAdmin => userType == 'TECHNICAL_ADMIN';
}

class RoleModel {
  final String id;
  final String name;
  final List<PermissionModel> permissions;

  RoleModel({required this.id, required this.name, required this.permissions});

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    return RoleModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      permissions:
          (json['permissions'] as List?)
              ?.map((p) => PermissionModel.fromJson(p))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'permissions': permissions.map((p) => p.toJson()).toList(),
  };
}

class PermissionModel {
  final String id;
  final String code;

  PermissionModel({required this.id, required this.code});

  factory PermissionModel.fromJson(Map<String, dynamic> json) {
    return PermissionModel(id: json['id'] ?? '', code: json['code'] ?? '');
  }

  Map<String, dynamic> toJson() => {'id': id, 'code': code};
}
