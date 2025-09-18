// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jive_money/core/app.dart';
import 'package:jive_money/services/storage_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('hive_widget_test');
    Hive.init(dir.path);
    await Hive.openBox('preferences');
    // 禁用 StorageService 模拟延迟，避免测试中挂起定时器。
    storageServiceDisableDelay = true;
  });
  testWidgets('App builds without exceptions', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: JiveApp()));
    // 延长等待时间 (>=800ms) 以完成应用初始化中使用的延迟任务，避免挂起定时器导致测试失败。
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
