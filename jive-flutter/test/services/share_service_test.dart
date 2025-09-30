
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

import 'package:jive_money/models/family.dart' as family_model;
import 'package:jive_money/services/share_service.dart';

class _FakeSharePlus extends SharePlus {
  ShareParams? lastParams;

  @override
  Future<ShareResult> share(ShareParams params) async {
    lastParams = params;
    return const ShareResult(ShareResultStatus.success);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShareService smoke tests', () {
    testWidgets('shareFamilyInvitation sends expected text', (tester) async {
      final fake = _FakeSharePlus();
      SharePlus.instance = fake;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                await ShareService.shareFamilyInvitation(
                  context: context,
                  familyName: '示例家庭',
                  inviteCode: 'ABCD1234',
                  inviteLink: 'https://example.com/invite/ABCD1234',
                  role: family_model.FamilyRole.member,
                  expiresAt: DateTime.now().add(const Duration(days: 7)),
                );
              });
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(fake.lastParams, isNotNull);
      final text = fake.lastParams!.text ?? '';
      expect(text, contains('示例家庭'));
      expect(text, contains('ABCD1234'));
      expect(text, contains('邀请你加入'));
    });

    testWidgets('shareToSocialMedia includes hashtags and url', (tester) async {
      final fake = _FakeSharePlus();
      SharePlus.instance = fake;

      await tester.pumpWidget(
        const MaterialApp(home: SizedBox.shrink()),
      );

      final ctx = tester.element(find.byType(SizedBox));
      await ShareService.shareToSocialMedia(
        context: ctx,
        text: 'Hello World',
        platform: SocialPlatform.other,
        url: 'https://example.com',
        hashtags: const ['A', 'B'],
      );

      expect(fake.lastParams, isNotNull);
      final text = fake.lastParams!.text ?? '';
      expect(text, contains('Hello World'));
      expect(text, contains('#A #B'));
      expect(text, contains('https://example.com'));
    });
  });
}
