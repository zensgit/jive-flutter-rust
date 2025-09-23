// Forwarder for the canonical currentUserProvider.
// Importing from this file keeps existing imports working.
export 'auth_provider.dart' show currentUserProvider;

import 'package:jive_money/models/user.dart';

// Type alias for compatibility
typedef UserData = User;

// Extension to add missing properties for compatibility
extension UserDataExt on User {
  String get username => email.split('@')[0];
  bool get isSuperAdmin => role == UserRole.admin; // Map admin to super admin
}
