/// 用户模型
class User {
  final String? id;
  final String name;
  final String email;
  final String? phone;
  final String? avatar;
  final bool emailVerified;
  final bool phoneVerified;
  final UserRole role;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? preferences;
  
  User({
    this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatar,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.role = UserRole.user,
    this.createdAt,
    this.updatedAt,
    this.preferences,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString(),
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      avatar: json['avatar'],
      emailVerified: json['email_verified'] ?? false,
      phoneVerified: json['phone_verified'] ?? false,
      role: UserRole.fromString(json['role']),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
      preferences: json['preferences'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'avatar': avatar,
      'email_verified': emailVerified,
      'phone_verified': phoneVerified,
      'role': role.value,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'preferences': preferences,
    };
  }
  
  User copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? avatar,
    bool? emailVerified,
    bool? phoneVerified,
    UserRole? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? preferences,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      preferences: preferences ?? this.preferences,
    );
  }
  
  /// 获取显示名称
  String get displayName {
    if (name.isNotEmpty) return name;
    return email.split('@').first;
  }
  
  /// 获取头像URL或默认头像
  String get avatarUrl {
    if (avatar != null && avatar!.isNotEmpty) {
      return avatar!;
    }
    // 返回默认头像（可以使用Gravatar或其他服务）
    return 'https://ui-avatars.com/api/?name=$displayName&background=6366f1&color=fff';
  }
  
  /// 是否是高级用户
  bool get isPremium {
    return role == UserRole.premium || role == UserRole.admin;
  }
  
  /// 是否是管理员
  bool get isAdmin {
    return role == UserRole.admin;
  }
}

/// 用户角色枚举
enum UserRole {
  user('user', '普通用户'),
  premium('premium', '高级用户'),
  admin('admin', '管理员');
  
  final String value;
  final String label;
  
  const UserRole(this.value, this.label);
  
  static UserRole fromString(String? value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.user,
    );
  }
}