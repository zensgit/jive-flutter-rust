
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

import 'package:jive_money/services/share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ShareService.shareQrCode shares expected text', (tester) async {
    ShareParams? last;
    ShareService.setDoShareForTest((params) async {
      last = params;
      return const ShareResult('', ShareResultStatus.success);
    });

    await tester.pumpWidget(
      const MaterialApp(home: SizedBox.shrink()),
    );

    final ctx = tester.element(find.byType(SizedBox));

    await ShareService.shareQrCode(
      context: ctx,
      data: 'https://example.com/q/XYZ',
      title: '示例二维码',
      description: '用于测试的二维码',
    );

    expect(last, isNotNull);
    final text = last!.text ?? '';
    expect(text, contains('示例二维码'));
    expect(text, contains('用于测试的二维码'));
    expect(text, contains('https://example.com/q/XYZ'));
  });
}
