import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_data.dart';

/// Stub provider for current user
/// TODO: Implement actual user state management
final currentUserProvider = StateProvider<UserData?>((ref) {
  // Return a minimal stub user for now
  return UserData(
    id: '1',
    email: 'stub@example.com',
    username: 'stub_user',
    phone: '',
    avatar: '',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
});