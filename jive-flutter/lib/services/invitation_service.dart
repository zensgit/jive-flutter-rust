import 'package:flutter/foundation.dart';
import '../models/invitation.dart';
import '../models/family.dart' as family_model;

/// 邀请服务 - 临时实现
class InvitationService {
  Future<List<Invitation>> getInvitations(String familyId) async {
    // TODO: 实现 API 调用
    return [];
  }

  Future<List<Invitation>> getFamilyInvitations(String familyId) async {
    // TODO: 实现 API 调用
    return [];
  }

  Future<InvitationStatistics> getFamilyInvitationStatistics(
      String familyId) async {
    // TODO: 实现 API 调用
    return InvitationStatistics(
      totalSent: 0,
      pendingCount: 0,
      acceptedCount: 0,
      declinedCount: 0,
      expiredCount: 0,
    );
  }

  Future<Invitation> createInvitation({
    required String familyId,
    required String email,
    required family_model.FamilyRole role,
    required int expiresInDays,
  }) async {
    // TODO: 实现 API 调用
    return Invitation(
      id: 'temp-id',
      familyId: familyId,
      email: email,
      role: role,
      token: 'temp-token',
      invitedBy: 'current-user',
      status: InvitationStatus.pending,
      expiresAt: DateTime.now().add(Duration(days: expiresInDays)),
      createdAt: DateTime.now(),
    );
  }

  Future<void> cancelInvitation(String invitationId) async {
    // TODO: 实现 API 调用
  }

  Future<void> resendInvitation(String invitationId) async {
    // TODO: 实现 API 调用
  }
}
