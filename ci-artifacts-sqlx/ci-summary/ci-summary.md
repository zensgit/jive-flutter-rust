# CI Summary Report
## Build Status
- Date: Tue Sep 23 09:28:04 UTC 2025
- Branch: chore/flutter-analyze-cleanup-phase1-2-execution
- Commit: 80d9075adb9e9c0d8b78c033b1c361d1328649c0

## Test Results
- Flutter Tests: failure
- Rust Tests: failure
- Rust Core Check: failure
- Field Comparison: skipped

## Flutter Test Details
# Flutter Test Report
## Test Summary
- Date: Tue Sep 23 09:27:55 UTC 2025
- Flutter Version: 3.35.3

## Test Results
```json
Resolving dependencies...
Downloading packages...
  _fe_analyzer_shared 67.0.0 (89.0.0 available)
  analyzer 6.4.1 (8.2.0 available)
  analyzer_plugin 0.11.3 (0.13.8 available)
  build 2.4.1 (4.0.0 available)
  build_config 1.1.2 (1.2.0 available)
  build_resolvers 2.4.2 (3.0.4 available)
  build_runner 2.4.13 (2.8.0 available)
  build_runner_core 7.3.2 (9.3.2 available)
  characters 1.4.0 (1.4.1 available)
  custom_lint_core 0.6.3 (0.8.1 available)
  dart_style 2.3.6 (3.1.2 available)
  file_picker 8.3.7 (10.3.3 available)
  fl_chart 0.66.2 (1.1.1 available)
  flutter_launcher_icons 0.13.1 (0.14.4 available)
  flutter_lints 3.0.2 (6.0.0 available)
  flutter_riverpod 2.6.1 (3.0.0 available)
  freezed 2.5.2 (3.2.3 available)
  freezed_annotation 2.4.4 (3.1.0 available)
  go_router 12.1.3 (16.2.2 available)
  image_picker_android 0.8.13+2 (0.8.13+3 available)
! intl 0.19.0 (overridden) (0.20.2 available)
  json_serializable 6.8.0 (6.11.1 available)
  lints 3.0.0 (6.0.0 available)
  material_color_utilities 0.11.1 (0.13.0 available)
  meta 1.16.0 (1.17.0 available)
  pool 1.5.1 (1.5.2 available)
  protobuf 3.1.0 (4.2.0 available)
  retrofit_generator 8.2.1 (10.0.5 available)
  riverpod 2.6.1 (3.0.0 available)
  riverpod_analyzer_utils 0.5.1 (0.5.10 available)
  riverpod_annotation 2.6.1 (3.0.0 available)
  riverpod_generator 2.4.0 (3.0.0 available)
  shared_preferences_android 2.4.12 (2.4.13 available)
  shelf_web_socket 2.0.1 (3.0.0 available)
  source_gen 1.5.0 (4.0.1 available)
  source_helper 1.3.5 (1.3.8 available)
  test_api 0.7.6 (0.7.7 available)
  very_good_analysis 5.1.0 (10.0.0 available)
Got dependencies!
38 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
{"protocolVersion":"0.1.1","runnerVersion":null,"pid":2698,"type":"start","time":0}
{"suite":{"id":0,"platform":"vm","path":"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_preferences_sync_test.dart"},"type":"suite","time":0}
{"test":{"id":1,"name":"loading /home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_preferences_sync_test.dart","suiteID":0,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":1}
{"suite":{"id":2,"platform":"vm","path":"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_meta_test.dart"},"type":"suite","time":5}
{"test":{"id":3,"name":"loading /home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_meta_test.dart","suiteID":2,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":5}
{"count":5,"time":6,"type":"allSuites"}

[{"event":"test.startedProcess","params":{"vmServiceUri":"http://127.0.0.1:39293/eTZiaHcrGWs=/"}}]

[{"event":"test.startedProcess","params":{"vmServiceUri":"http://127.0.0.1:36355/nOrTWyOOTIM=/"}}]
{"testID":3,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":8712}
{"group":{"id":4,"suiteID":2,"parentID":null,"name":"","metadata":{"skip":false,"skipReason":null},"testCount":1,"line":null,"column":null,"url":null},"type":"group","time":8715}
{"test":{"id":5,"name":"(setUpAll)","suiteID":2,"groupIDs":[4],"metadata":{"skip":false,"skipReason":null},"line":22,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_meta_test.dart"},"type":"testStart","time":8715}
{"testID":1,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":8732}
{"group":{"id":6,"suiteID":0,"parentID":null,"name":"","metadata":{"skip":false,"skipReason":null},"testCount":3,"line":null,"column":null,"url":null},"type":"group","time":8732}
{"test":{"id":7,"name":"(setUpAll)","suiteID":0,"groupIDs":[6],"metadata":{"skip":false,"skipReason":null},"line":104,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_preferences_sync_test.dart"},"type":"testStart","time":8732}
{"testID":7,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":8795}
{"test":{"id":8,"name":"debounce combines rapid preference pushes and succeeds","suiteID":0,"groupIDs":[6],"metadata":{"skip":false,"skipReason":null},"line":112,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_preferences_sync_test.dart"},"type":"testStart","time":8796}
{"testID":5,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":8834}
{"group":{"id":9,"suiteID":2,"parentID":4,"name":"CurrencyNotifier catalog meta","metadata":{"skip":false,"skipReason":null},"testCount":1,"line":29,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_meta_test.dart"},"type":"group","time":8834}
{"test":{"id":10,"name":"CurrencyNotifier catalog meta initial usingFallback true when first fetch throws","suiteID":2,"groupIDs":[4,9],"metadata":{"skip":false,"skipReason":null},"line":31,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_meta_test.dart"},"type":"testStart","time":8835}
{"testID":8,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":8841}
{"test":{"id":11,"name":"failure stores pending then flush success clears it","suiteID":0,"groupIDs":[6],"metadata":{"skip":false,"skipReason":null},"line":139,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_preferences_sync_test.dart"},"type":"testStart","time":8841}
{"testID":10,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":8896}
{"test":{"id":12,"name":"(tearDownAll)","suiteID":2,"groupIDs":[4],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":8897}
{"testID":12,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":8900}
{"testID":11,"messageType":"print","message":"Failed to push currency preferences (will persist pending): Exception: network","type":"print","time":9360}
{"testID":11,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":9527}
{"test":{"id":13,"name":"startup flush clears preexisting pending","suiteID":0,"groupIDs":[6],"metadata":{"skip":false,"skipReason":null},"line":167,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_preferences_sync_test.dart"},"type":"testStart","time":9527}
{"testID":13,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":9533}
{"test":{"id":14,"name":"(tearDownAll)","suiteID":0,"groupIDs":[6],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":9533}
{"testID":14,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":9536}
{"suite":{"id":15,"platform":"vm","path":"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/widget_test.dart"},"type":"suite","time":9552}
{"test":{"id":16,"name":"loading /home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/widget_test.dart","suiteID":15,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":9552}
{"suite":{"id":17,"platform":"vm","path":"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_selection_page_test.dart"},"type":"suite","time":10211}
{"test":{"id":18,"name":"loading /home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_selection_page_test.dart","suiteID":17,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":10211}
{"testID":16,"error":"Failed to load \"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/widget_test.dart\":\nCompilation failed for testPath=/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/widget_test.dart: lib/screens/auth/login_screen.dart:442:36: Error: Not a constant expression.\n                        onPressed: _isLoading ? null : _login,\n                                   ^^^^^^^^^^\nlib/screens/auth/login_screen.dart:442:56: Error: Not a constant expression.\n                        onPressed: _isLoading ? null : _login,\n                                                       ^^^^^^\nlib/screens/auth/login_screen.dart:443:47: Error: Method invocation is not a constant expression.\n                        style: ElevatedButton.styleFrom(\n                                              ^^^^^^^^^\nlib/screens/auth/login_screen.dart:447:32: Error: Not a constant expression.\n                        child: _isLoading\n                               ^^^^^^^^^^\nlib/screens/auth/register_screen.dart:332:36: Error: Not a constant expression.\n                        onPressed: _isLoading ? null : _register,\n                                   ^^^^^^^^^^\nlib/screens/auth/register_screen.dart:332:56: Error: Not a constant expression.\n                        onPressed: _isLoading ? null : _register,\n                                                       ^^^^^^^^^\nlib/screens/auth/register_screen.dart:333:47: Error: Method invocation is not a constant expression.\n                        style: ElevatedButton.styleFrom(\n                                              ^^^^^^^^^\nlib/screens/auth/register_screen.dart:337:32: Error: Not a constant expression.\n                        child: _isLoading\n                               ^^^^^^^^^^\nlib/screens/dashboard/dashboard_screen.dart:337:31: Error: Not a constant expression.\n                Navigator.pop(context);\n                              ^^^^^^^\nlib/screens/dashboard/dashboard_screen.dart:337:27: Error: Method invocation is not a constant expression.\n                Navigator.pop(context);\n                          ^^^\nlib/screens/dashboard/dashboard_screen.dart:336:26: Error: Not a constant expression.\n              onPressed: () {\n                         ^^\nlib/screens/dashboard/dashboard_screen.dart:335:35: Error: Cannot invoke a non-'const' factory where a const expression is expected.\nTry using a constructor or factory that is 'const'.\n            child: OutlinedButton.icon(\n                                  ^^^^\nlib/screens/settings/profile_settings_screen.dart:1004:42: Error: Not a constant expression.\n                              onPressed: _resetAccount,\n                                         ^^^^^^^^^^^^^\nlib/screens/settings/profile_settings_screen.dart:1005:53: Error: Method invocation is not a constant expression.\n                              style: ElevatedButton.styleFrom(\n                                                    ^^^^^^^^^\nlib/screens/settings/profile_settings_screen.dart:1072:44: Error: Not a constant expression.\n                                  context: context,\n                                           ^^^^^^^\nlib/screens/settings/profile_settings_screen.dart:1080:72: Error: Not a constant expression.\n                                        onPressed: () => Navigator.pop(context),\n                                                                       ^^^^^^^\nlib/screens/settings/profile_settings_screen.dart:1080:68: Error: Method invocation is not a constant expression.\n                                        onPressed: () => Navigator.pop(context),\n                                                                   ^^^\nlib/screens/settings/profile_settings_screen.dart:1080:52: Error: Not a constant expression.\n                                        onPressed: () => Navigator.pop(context),\n                                                   ^^\nlib/screens/settings/profile_settings_screen.dart:1085:57: Error: Not a constant expression.\n                                          Navigator.pop(context);\n                                                        ^^^^^^^\nlib/screens/settings/profile_settings_screen.dart:1085:53: Error: Method invocation is not a constant expression.\n                                          Navigator.pop(context);\n                                                    ^^^\nlib/screens/settings/profile_settings_screen.dart:1086:43: Error: Not a constant expression.\n                                          _deleteAccount();\n                                          ^^^^^^^^^^^^^^\nlib/screens/settings/profile_settings_screen.dart:1084:52: Error: Not a constant expression.\n                                        onPressed: () {\n                                                   ^^\nlib/screens/settings/profile_settings_screen.dart:1073:44: Error: Not a constant expression.\n                                  builder: (context) => AlertDialog(\n                                           ^^^^^^^^^\nlib/screens/settings/profile_settings_screen.dart:1071:33: Error: Method invocation is not a constant expression.\n                                showDialog(\n                                ^^^^^^^^^^\nlib/screens/settings/profile_settings_screen.dart:1070:42: Error: Not a constant expression.\n                              onPressed: () {\n                                         ^^\nlib/screens/settings/profile_settings_screen.dart:1097:53: Error: Method invocation is not a constant expression.\n                              style: ElevatedButton.styleFrom(\n                                                    ^^^^^^^^^\nlib/screens/management/currency_management_page_v2.dart:344:44: Error: Not a constant expression.\n                      Expanded(child: Text(d.code)),\n                                           ^\nlib/screens/management/currency_management_page_v2.dart:348:46: Error: Not a constant expression.\n                          value: selectedMap[d.code],\n                                             ^\nlib/screens/management/currency_management_page_v2.dart:348:34: Error: Not a constant expression.\n                          value: selectedMap[d.code],\n                                 ^^^^^^^^^^^\nlib/screens/management/currency_management_page_v2.dart:351:42: Error: Not a constant expression.\n                                  value: c.code,\n                                         ^\nlib/screens/management/currency_management_page_v2.dart:352:50: Error: Not a constant expression.\n                                  child: Text('${c.code} · ${c.nameZh}')))\n                                                 ^\nlib/screens/management/currency_management_page_v2.dart:352:62: Error: Not a constant expression.\n                                  child: Text('${c.code} · ${c.nameZh}')))\n                                                             ^\nlib/screens/management/currency_management_page_v2.dart:350:36: Error: Not a constant expression.\n                              .map((c) => DropdownMenuItem(\n                                   ^^^\nlib/screens/management/currency_management_page_v2.dart:349:34: Error: Not a constant expression.\n                          items: available\n                                 ^^^^^^^^^\nlib/screens/management/currency_management_page_v2.dart:350:32: Error: Method invocation is not a constant expression.\n                              .map((c) => DropdownMenuItem(\n                               ^^^\nlib/screens/management/currency_management_page_v2.dart:353:32: Error: Method invocation is not a constant expression.\n                              .toList(),\n                               ^^^^^^\nlib/screens/management/currency_management_page_v2.dart:354:57: Error: Not a constant expression.\n                          onChanged: (v) => selectedMap[d.code] = v ?? d.code,\n                                                        ^\nlib/screens/management/currency_management_page_v2.dart:354:45: Error: Not a constant expression.\n                          onChanged: (v) => selectedMap[d.code] = v ?? d.code,\n                                            ^^^^^^^^^^^\nlib/screens/management/currency_management_page_v2.dart:354:72: Error: Not a constant expression.\n                          onChanged: (v) => selectedMap[d.code] = v ?? d.code,\n                                                                       ^\nlib/screens/management/currency_management_page_v2.dart:354:67: Error: Not a constant expression.\n                          onChanged: (v) => selectedMap[d.code] = v ?? d.code,\n                                                                  ^\nlib/screens/management/currency_management_page_v2.dart:354:65: Error: Not a constant expression.\n                          onChanged: (v) => selectedMap[d.code] = v ?? d.code,\n                                                                ^\nlib/screens/management/currency_management_page_v2.dart:354:38: Error: Not a constant expression.\n                          onChanged: (v) => selectedMap[d.code] = v ?? d.code,\n                                     ^^^\nlib/screens/management/currency_management_page_v2.dart:347:32: Error: Cannot invoke a non-'const' constructor where a const expression is expected.\nTry using a constructor or factory that is 'const'.\n                        child: DropdownButtonFormField<String>(\n                               ^^^^^^^^^^^^^^^^^^^^^^^\nlib/screens/management/currency_management_page_v2.dart:339:40: Error: Not a constant expression.\n              children: deprecated.map((d) {\n                                       ^^^\nlib/screens/management/currency_management_page_v2.dart:339:25: Error: Not a constant expression.\n              children: deprecated.map((d) {\n                        ^^^^^^^^^^\nlib/screens/management/currency_management_page_v2.dart:339:36: Error: Method invocation is not a constant expression.\n              children: deprecated.map((d) {\n                                   ^^^\nlib/screens/management/currency_management_page_v2.dart:362:18: Error: Method invocation is not a constant expression.\n              }).toList(),\n                 ^^^^^^\nlib/screens/family/family_dashboard_screen.dart:330:53: Error: Not a constant expression.\n                  sections: _createPieChartSections(stats.accountTypeBreakdown),\n                                                    ^^^^^\nlib/screens/family/family_dashboard_screen.dart:330:29: Error: Not a constant expression.\n                  sections: _createPieChartSections(stats.accountTypeBreakdown),\n                            ^^^^^^^^^^^^^^^^^^^^^^^\nlib/screens/family/family_dashboard_screen.dart:329:17: Error: Cannot invoke a non-'const' constructor where a const expression is expected.\nTry using a constructor or factory that is 'const'.\n                PieChartData(\n                ^^^^^^^^^^^^\nlib/screens/family/family_dashboard_screen.dart:583:47: Error: Not a constant expression.\n                    getDrawingHorizontalLine: (value) {\n                                              ^^^^^^^\nlib/screens/family/family_dashboard_screen.dart:605:31: Error: Not a constant expression.\n                          if (value.toInt() < months.length) {\n                              ^^^^^\nlib/screens/family/family_dashboard_screen.dart:605:37: Error: Method invocation is not a constant expression.\n                          if (value.toInt() < months.length) {\n                                    ^^^^^\nlib/screens/family/family_dashboard_screen.dart:605:47: Error: Not a constant expression.\n                          if (value.toInt() < months.length) {\n                                              ^^^^^^\nlib/screens/family/family_dashboard_screen.dart:607:38: Error: Not a constant expression.\n                              months[value.toInt()].substring(5),\n                                     ^^^^^\nlib/screens/family/family_dashboard_screen.dart:607:44: Error: Method invocation is not a constant expression.\n                              months[value.toInt()].substring(5),\n                                           ^^^^^\nlib/screens/family/family_dashboard_screen.dart:607:31: Error: Not a constant expression.\n                              months[value.toInt()].substring(5),\n                              ^^^^^^\nlib/screens/family/family_dashboard_screen.dart:607:53: Error: Method invocation is not a constant expression.\n                              months[value.toInt()].substring(5),\n                                                    ^^^^^^^^^\nlib/screens/family/family_dashboard_screen.dart:603:42: Error: Not a constant expression.\n                        getTitlesWidget: (value, meta) {\n                                         ^^^^^^^^^^^^^\nlib/screens/family/family_dashboard_screen.dart:616:31: Error: Cannot invoke a non-'const' constructor where a const expression is expected.\nTry using a constructor or factory that is 'const'.\n                  borderData: FlBorderData(show: false),\n                              ^^^^^^^^^^^^\nlib/screens/family/family_dashboard_screen.dart:619:30: Error: Not a constant expression.\n                      spots: monthlyTrend.entries\n                             ^^^^^^^^^^^^\nlib/screens/family/family_dashboard_screen.dart:620:28: Error: Method invocation is not a constant expression.\n                          .toList()\n                           ^^^^^^\nlib/screens/family/family_dashboard_screen.dart:621:28: Error: Method invocation is not a constant expression.\n                          .asMap()\n                           ^^^^^\nlib/screens/family/family_dashboard_screen.dart:624:39: Error: Not a constant expression.\n                        return FlSpot(entry.key.toDouble(), entry.value.value);\n                                      ^^^^^\nlib/screens/family/family_dashboard_screen.dart:624:49: Error: Method invocation is not a constant expression.\n                        return FlSpot(entry.key.toDouble(), entry.value.value);\n                                                ^^^^^^^^\nlib/screens/family/family_dashboard_screen.dart:624:61: Error: Not a constant expression.\n                        return FlSpot(entry.key.toDouble(), entry.value.value);\n                                                            ^^^^^\nlib/screens/family/family_dashboard_screen.dart:624:67: Error: Not a constant expression.\n                        return FlSpot(entry.key.toDouble(), entry.value.value);\n                                                                  ^^^^^\nlib/screens/family/family_dashboard_screen.dart:623:32: Error: Not a constant expression.\n                          .map((entry) {\n                               ^^^^^^^\nlib/screens/family/family_dashboard_screen.dart:623:28: Error: Method invocation is not a constant expression.\n                          .map((entry) {\n                           ^^^\nlib/screens/family/family_dashboard_screen.dart:625:26: Error: Method invocation is not a constant expression.\n                      }).toList(),\n                         ^^^^^^\nlib/screens/family/family_dashboard_screen.dart:627:39: Error: Not a constant expression.\n                      color: Theme.of(context).primaryColor,\n                                      ^^^^^^^\nlib/screens/family/family_dashboard_screen.dart:627:36: Error: Method invocation is not a constant expression.\n                      color: Theme.of(context).primaryColor,\n                                   ^^\nlib/screens/family/family_dashboard_screen.dart:632:41: Error: Not a constant expression.\n                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),\n                                        ^^^^^^^\nlib/screens/family/family_dashboard_screen.dart:632:38: Error: Method invocation is not a constant expression.\n                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),\n                                     ^^\nlib/screens/family/family_dashboard_screen.dart:632:63: Error: Method invocation is not a constant expression.\n                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),\n                                                              ^^^^^^^^^^\nlib/screens/family/family_dashboard_screen.dart:630:37: Error: Cannot invoke a non-'const' constructor where a const expression is expected.\nTry using a constructor or factory that is 'const'.\n                      belowBarData: BarAreaData(\n                                    ^^^^^^^^^^^\nlib/screens/family/family_dashboard_screen.dart:618:21: Error: Cannot invoke a non-'const' constructor where a const expression is expected.\nTry using a constructor or factory that is 'const'.\n                    LineChartBarData(\n                    ^^^^^^^^^^^^^^^^\nlib/screens/family/family_dashboard_screen.dart:578:17: Error: Cannot invoke a non-'const' constructor where a const expression is expected.\nTry using a constructor or factory that is 'const'.\n                LineChartData(\n                ^^^^^^^^^^^^^\nlib/widgets/wechat_login_button.dart:85:20: Error: Not a constant expression.\n        onPressed: _isLoading ? null : _handleWeChatLogin,\n                   ^^^^^^^^^^\nlib/widgets/wechat_login_button.dart:85:40: Error: Not a constant expression.\n        onPressed: _isLoading ? null : _handleWeChatLogin,\n                                       ^^^^^^^^^^^^^^^^^^\nlib/widgets/wechat_login_button.dart:90:40: Error: Cannot invoke a non-'const' constructor where a const expression is expected.\nTry using a constructor or factory that is 'const'.\n            borderRadius: BorderRadius.circular(8),\n                                       ^^^^^^^^\nlib/widgets/wechat_login_button.dart:86:31: Error: Method invocation is not a constant expression.\n        style: OutlinedButton.styleFrom(\n                              ^^^^^^^^^\nlib/widgets/wechat_login_button.dart:93:15: Error: Not a constant expression.\n        icon: _isLoading\n              ^^^^^^^^^^\nlib/widgets/wechat_login_button.dart:104:11: Error: Not a constant expression.\n          widget.buttonText,\n          ^^^^^^\nlib/widgets/wechat_login_button.dart:84:29: Error: Cannot invoke a non-'const' factory where a const expression is expected.\nTry using a constructor or factory that is 'const'.\n      child: OutlinedButton.icon(\n                            ^^^^\nlib/ui/components/dashboard/account_overview.dart:122:15: Error: Not a constant expression.\n              assets,\n              ^^^^^^\nlib/ui/components/dashboard/account_overview.dart:120:20: Error: Not a constant expression.\n            child: _buildOverviewCard(\n                   ^^^^^^^^^^^^^^^^^^\nlib/ui/components/dashboard/account_overview.dart:131:15: Error: Not a constant expression.\n              liabilities,\n              ^^^^^^^^^^^\nlib/ui/components/dashboard/account_overview.dart:129:20: Error: Not a constant expression.\n            child: _buildOverviewCard(\n                   ^^^^^^^^^^^^^^^^^^\nlib/ui/components/dashboard/account_overview.dart:141:15: Error: Not a constant expression.\n              netWorth >= 0 ? Colors.blue : Colors.orange,\n              ^^^^^^^^\nlib/ui/components/dashboard/account_overview.dart:140:15: Error: Not a constant expression.\n              netWorth,\n              ^^^^^^^^\nlib/ui/components/dashboard/account_overview.dart:138:20: Error: Not a constant expression.\n            child: _buildOverviewCard(\n                   ^^^^^^^^^^^^^^^^^^\nlib/ui/components/dashboard/budget_summary.dart:181:32: Error: Not a constant expression.\n                        value: spentPercentage.clamp(0.0, 1.0),\n                               ^^^^^^^^^^^^^^^\nlib/ui/components/dashboard/budget_summary.dart:181:48: Error: Method invocation is not a constant expression.\n                        value: spentPercentage.clamp(0.0, 1.0),\n                                               ^^^^^\nlib/ui/components/dashboard/budget_summary.dart:184:59: Error: Not a constant expression.\n                            AlwaysStoppedAnimation<Color>(warningLevel.color),\n                                                          ^^^^^^^^^^^^\nlib/widgets/dialogs/invite_member_dialog.dart:438:15: Error: Not a constant expression.\n              permission,\n              ^^^^^^^^^^\nlib/widgets/sheets/generate_invite_code_sheet.dart:297:30: Error: Not a constant expression.\n                  onPressed: _isLoading ? null : _generateInvitation,\n                             ^^^^^^^^^^\nlib/widgets/sheets/generate_invite_code_sheet.dart:297:50: Error: Not a constant expression.\n                  onPressed: _isLoading ? null : _generateInvitation,\n                                                 ^^^^^^^^^^^^^^^^^^^\nlib/widgets/sheets/generate_invite_code_sheet.dart:298:25: Error: Not a constant expression.\n                  icon: _isLoading\n                        ^^^^^^^^^^\nlib/widgets/sheets/generate_invite_code_sheet.dart:308:31: Error: Not a constant expression.\n                  label: Text(_isLoading ? '生成中...' : '生成邀请'),\n                              ^^^^^^^^^^\nlib/widgets/sheets/generate_invite_code_sheet.dart:296:37: Error: Cannot invoke a non-'const' factory where a const expression is expected.\nTry using a constructor or factory that is 'const'.\n                child: FilledButton.icon(\n                                    ^^^^\nlib/screens/auth/wechat_register_form_screen.dart:401:32: Error: Not a constant expression.\n                    onPressed: _isLoading ? null : _register,\n                               ^^^^^^^^^^\nlib/screens/auth/wechat_register_form_screen.dart:401:52: Error: Not a constant expression.\n                    onPressed: _isLoading ? null : _register,\n                                                   ^^^^^^^^^\nlib/screens/auth/wechat_register_form_screen.dart:402:43: Error: Method invocation is not a constant expression.\n                    style: ElevatedButton.styleFrom(\n                                          ^^^^^^^^^\nlib/screens/auth/wechat_register_form_screen.dart:406:28: Error: Not a constant expression.\n                    child: _isLoading\n                           ^^^^^^^^^^\n.","stackTrace":"","isFailure":false,"type":"error","time":12358}
{"testID":16,"result":"error","skipped":false,"hidden":false,"type":"testDone","time":12361}
{"suite":{"id":19,"platform":"vm","path":"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_quiet_test.dart"},"type":"suite","time":12361}
{"test":{"id":20,"name":"loading /home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_quiet_test.dart","suiteID":19,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":12362}

[{"event":"test.startedProcess","params":{"vmServiceUri":"http://127.0.0.1:36441/Z_Y8385vBiE=/"}}]
{"testID":18,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":14067}
{"group":{"id":21,"suiteID":17,"parentID":null,"name":"","metadata":{"skip":false,"skipReason":null},"testCount":2,"line":null,"column":null,"url":null},"type":"group","time":14068}
{"test":{"id":22,"name":"(setUpAll)","suiteID":17,"groupIDs":[21],"metadata":{"skip":false,"skipReason":null},"line":78,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_selection_page_test.dart"},"type":"testStart","time":14068}

[{"event":"test.startedProcess","params":{"vmServiceUri":"http://127.0.0.1:42785/wwGOWAQ73TE=/"}}]
{"testID":22,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":14132}
{"test":{"id":23,"name":"Selecting base currency returns via Navigator.pop","suiteID":17,"groupIDs":[21],"metadata":{"skip":false,"skipReason":null},"line":174,"column":5,"url":"package:flutter_test/src/widget_tester.dart","root_line":85,"root_column":3,"root_url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_selection_page_test.dart"},"type":"testStart","time":14132}
{"testID":20,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":14300}
{"group":{"id":24,"suiteID":19,"parentID":null,"name":"","metadata":{"skip":false,"skipReason":null},"testCount":2,"line":null,"column":null,"url":null},"type":"group","time":14300}
{"test":{"id":25,"name":"(setUpAll)","suiteID":19,"groupIDs":[24],"metadata":{"skip":false,"skipReason":null},"line":66,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_quiet_test.dart"},"type":"testStart","time":14300}
{"testID":25,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":14354}
{"test":{"id":26,"name":"quiet mode: no calls before initialize; initialize triggers first load; explicit refresh triggers second","suiteID":19,"groupIDs":[24],"metadata":{"skip":false,"skipReason":null},"line":88,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_quiet_test.dart"},"type":"testStart","time":14355}
{"testID":26,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":14392}
{"test":{"id":27,"name":"initialize() is idempotent","suiteID":19,"groupIDs":[24],"metadata":{"skip":false,"skipReason":null},"line":104,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_quiet_test.dart"},"type":"testStart","time":14392}
{"testID":27,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":14418}
{"test":{"id":28,"name":"(tearDownAll)","suiteID":19,"groupIDs":[24],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":14418}
{"testID":28,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":14421}
{"testID":23,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":15472}
{"test":{"id":29,"name":"Base currency is sorted to top and marked","suiteID":17,"groupIDs":[21],"metadata":{"skip":false,"skipReason":null},"line":174,"column":5,"url":"package:flutter_test/src/widget_tester.dart","root_line":120,"root_column":3,"root_url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_selection_page_test.dart"},"type":"testStart","time":15473}
{"testID":29,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":15696}
{"test":{"id":30,"name":"(tearDownAll)","suiteID":17,"groupIDs":[21],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":15696}
{"testID":30,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":15700}
{"success":false,"type":"done","time":16083}
```
## Coverage Summary
Coverage data generated successfully
## Rust Test Details
```
184 |                 base_currency: settings.base_currency,
    |                                ^^^^^^^^^^^^^^^^^^^^^^ expected `String`, found `Option<String>`
    |
    = note: expected struct `std::string::String`
                 found enum `std::option::Option<std::string::String>`
help: consider using `Option::expect` to unwrap the `std::option::Option<std::string::String>` value, panicking if the value is an `Option::None`
    |
184 |                 base_currency: settings.base_currency.expect("REASON"),
    |                                                      +++++++++++++++++

warning: value assigned to `bind_idx` is never read
  --> src/services/tag_service.rs:37:133
   |
37 | ...E ${}", bind_idx)); args.push((bind_idx, format!("%{}%", q))); bind_idx+=1; }
   |                                                                   ^^^^^^^^
   |
   = help: maybe it is overwritten before being read?

warning: unused import: `super::*`
   --> src/services/currency_service.rs:582:9
    |
582 |     use super::*;
    |         ^^^^^^^^
    |
    = note: `#[warn(unused_imports)]` on by default

warning: unused import: `rust_decimal::prelude::*`
   --> src/services/currency_service.rs:583:9
    |
583 |     use rust_decimal::prelude::*;
    |         ^^^^^^^^^^^^^^^^^^^^^^^^

warning: unused variable: `i`
   --> src/services/avatar_service.rs:230:18
    |
230 |             for (i, part) in parts.iter().take(2).enumerate() {
    |                  ^ help: if this is intentional, prefix it with an underscore: `_i`

warning: unused variable: `from_decimal_places`
   --> src/services/currency_service.rs:386:9
    |
386 |         from_decimal_places: i32,
    |         ^^^^^^^^^^^^^^^^^^^ help: if this is intentional, prefix it with an underscore: `_from_decimal_places`

For more information about this error, try `rustc --explain E0308`.
warning: `jive-money-api` (lib) generated 7 warnings
error: could not compile `jive-money-api` (lib) due to 2 previous errors; 7 warnings emitted
warning: build failed, waiting for other jobs to finish...
warning: `jive-money-api` (lib test) generated 9 warnings (7 duplicates)
error: could not compile `jive-money-api` (lib test) due to 2 previous errors; 9 warnings emitted
```

## Manual Overrides Tests
- HTTP endpoint test (manual_overrides_http_test): executed in CI (see Rust Test Details)
- Flutter widget navigation test: attempted (no machine artifact found)

## Manual Exchange Rate Tests
- currency_manual_rate_test: executed in CI
- currency_manual_rate_batch_test: executed in CI

## Rust Core Dual Mode Check
- jive-core default mode: tested
- jive-core server mode: tested
- Overall status: failure

## Rust API Clippy (Non-blocking)
- Status: success
- Artifact: api-clippy-output.txt

## Recent EXPORT Audits (top 3)
(no audit data)
