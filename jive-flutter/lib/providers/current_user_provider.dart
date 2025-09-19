import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';

// Type alias for compatibility
typedef UserData = User;

// Extension to add missing properties for compatibility
extension UserDataExt on User {
  String get username => email.split('@')[0];
  bool get isSuperAdmin => role == UserRole.admin; // Using admin as superAdmin doesn't exist
}

/// Stub provider for current user
/// TODO: Implement actual user state management
final currentUserProvider = StateProvider<User?>((ref) {
  // Return a minimal stub user for now
  return User(
    id: '1',
    email: 'stub@example.com',
    name: 'Stub User',
    phone: '',
    avatar: '',
    role: UserRole.admin,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
});