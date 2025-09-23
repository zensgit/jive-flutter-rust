# CI Summary Report
## Build Status
- Date: Tue Sep 23 11:39:39 UTC 2025
- Branch: 24/merge
- Commit: c5431f519ba8b267aded29ecc89a6c055cd28543

## Test Results
- Flutter Tests: success
- Rust Tests: failure
- Rust Core Check: failure
- Field Comparison: skipped

## Flutter Test Details
# Flutter Test Report
## Test Summary
- Date: Tue Sep 23 11:39:33 UTC 2025
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
  uni_links 0.5.1 (discontinued replaced by app_links)
  very_good_analysis 5.1.0 (10.0.0 available)
Got dependencies!
1 package is discontinued.
38 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
{"protocolVersion":"0.1.1","runnerVersion":null,"pid":2604,"type":"start","time":0}
{"suite":{"id":0,"platform":"vm","path":"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_preferences_sync_test.dart"},"type":"suite","time":0}
{"test":{"id":1,"name":"loading /home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_preferences_sync_test.dart","suiteID":0,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":1}
{"suite":{"id":2,"platform":"vm","path":"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_meta_test.dart"},"type":"suite","time":5}
{"test":{"id":3,"name":"loading /home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_meta_test.dart","suiteID":2,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":5}
{"count":5,"time":6,"type":"allSuites"}
{"testID":1,"error":"Failed to load \"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_preferences_sync_test.dart\":\nCompilation failed for testPath=/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_preferences_sync_test.dart: lib/providers/currency_provider.dart:375:21: Error: The getter 'HttpClient' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'HttpClient'.\n        final dio = HttpClient.instance.dio;\n                    ^^^^^^^^^^\nlib/providers/currency_provider.dart:470:19: Error: The getter 'HttpClient' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'HttpClient'.\n      final dio = HttpClient.instance.dio;\n                  ^^^^^^^^^^\nlib/providers/currency_provider.dart:471:13: Error: The getter 'ApiReadiness' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'ApiReadiness'.\n      await ApiReadiness.ensureReady(dio);\n            ^^^^^^^^^^^^\nlib/providers/currency_provider.dart:500:19: Error: The getter 'HttpClient' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'HttpClient'.\n      final dio = HttpClient.instance.dio;\n                  ^^^^^^^^^^\nlib/providers/currency_provider.dart:501:13: Error: The getter 'ApiReadiness' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'ApiReadiness'.\n      await ApiReadiness.ensureReady(dio);\n            ^^^^^^^^^^^^\nlib/providers/currency_provider.dart:530:19: Error: The getter 'HttpClient' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'HttpClient'.\n      final dio = HttpClient.instance.dio;\n                  ^^^^^^^^^^\nlib/providers/currency_provider.dart:531:13: Error: The getter 'ApiReadiness' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'ApiReadiness'.\n      await ApiReadiness.ensureReady(dio);\n            ^^^^^^^^^^^^\n.","stackTrace":"","isFailure":false,"type":"error","time":7439}
{"testID":1,"result":"error","skipped":false,"hidden":false,"type":"testDone","time":7442}
{"suite":{"id":4,"platform":"vm","path":"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/widget_test.dart"},"type":"suite","time":7444}
{"test":{"id":5,"name":"loading /home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/widget_test.dart","suiteID":4,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":7444}
{"testID":1,"error":"Error: The Dart compiler exited unexpectedly.","stackTrace":"package:flutter_tools/src/base/common.dart 34:3  throwToolExit\npackage:flutter_tools/src/compile.dart 910:11    DefaultResidentCompiler._compile.<fn>\ndart:async/zone.dart 1538:47                     _rootRunUnary\ndart:async/zone.dart 1429:19                     _CustomZone.runUnary\ndart:async/future_impl.dart 948:45               Future._propagateToListeners.handleValueCallback\ndart:async/future_impl.dart 977:13               Future._propagateToListeners\ndart:async/future_impl.dart 862:9                Future._propagateToListeners\ndart:async/future_impl.dart 720:5                Future._completeWithValue\ndart:async/future_impl.dart 804:7                Future._asyncCompleteWithValue.<fn>\ndart:async/zone.dart 1525:13                     _rootRun\ndart:async/zone.dart 1422:19                     _CustomZone.run\ndart:async/zone.dart 1321:7                      _CustomZone.runGuarded\ndart:async/zone.dart 1362:23                     _CustomZone.bindCallbackGuarded.<fn>\ndart:async/schedule_microtask.dart 40:35         _microtaskLoop\ndart:async/schedule_microtask.dart 49:5          _startMicrotaskLoop\ndart:isolate-patch/isolate_patch.dart 127:13     _runPendingImmediateCallback\ndart:isolate-patch/isolate_patch.dart 194:5      _RawReceivePort._handleMessage\n","isFailure":false,"type":"error","time":7484}
{"testID":3,"error":"Failed to load \"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_meta_test.dart\":\nCompilation failed for testPath=/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_meta_test.dart: lib/providers/currency_provider.dart:375:21: Error: The getter 'HttpClient' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'HttpClient'.\n        final dio = HttpClient.instance.dio;\n                    ^^^^^^^^^^\nlib/providers/currency_provider.dart:470:19: Error: The getter 'HttpClient' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'HttpClient'.\n      final dio = HttpClient.instance.dio;\n                  ^^^^^^^^^^\nlib/providers/currency_provider.dart:471:13: Error: The getter 'ApiReadiness' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'ApiReadiness'.\n      await ApiReadiness.ensureReady(dio);\n            ^^^^^^^^^^^^\nlib/providers/currency_provider.dart:500:19: Error: The getter 'HttpClient' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'HttpClient'.\n      final dio = HttpClient.instance.dio;\n                  ^^^^^^^^^^\nlib/providers/currency_provider.dart:501:13: Error: The getter 'ApiReadiness' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'ApiReadiness'.\n      await ApiReadiness.ensureReady(dio);\n            ^^^^^^^^^^^^\nlib/providers/currency_provider.dart:530:19: Error: The getter 'HttpClient' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'HttpClient'.\n      final dio = HttpClient.instance.dio;\n                  ^^^^^^^^^^\nlib/providers/currency_provider.dart:531:13: Error: The getter 'ApiReadiness' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'ApiReadiness'.\n      await ApiReadiness.ensureReady(dio);\n            ^^^^^^^^^^^^\n.","stackTrace":"","isFailure":false,"type":"error","time":15041}
{"testID":3,"result":"error","skipped":false,"hidden":false,"type":"testDone","time":15041}
{"suite":{"id":6,"platform":"vm","path":"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_selection_page_test.dart"},"type":"suite","time":15042}
{"test":{"id":7,"name":"loading /home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_selection_page_test.dart","suiteID":6,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":15042}
{"testID":1,"error":"Error: The Dart compiler exited unexpectedly.","stackTrace":"package:flutter_tools/src/base/common.dart 34:3  throwToolExit\npackage:flutter_tools/src/compile.dart 910:11    DefaultResidentCompiler._compile.<fn>\ndart:async/zone.dart 1538:47                     _rootRunUnary\ndart:async/zone.dart 1429:19                     _CustomZone.runUnary\ndart:async/future_impl.dart 948:45               Future._propagateToListeners.handleValueCallback\ndart:async/future_impl.dart 977:13               Future._propagateToListeners\ndart:async/future_impl.dart 862:9                Future._propagateToListeners\ndart:async/future_impl.dart 720:5                Future._completeWithValue\ndart:async/future_impl.dart 804:7                Future._asyncCompleteWithValue.<fn>\ndart:async/zone.dart 1525:13                     _rootRun\ndart:async/zone.dart 1422:19                     _CustomZone.run\ndart:async/zone.dart 1321:7                      _CustomZone.runGuarded\ndart:async/zone.dart 1362:23                     _CustomZone.bindCallbackGuarded.<fn>\ndart:async/schedule_microtask.dart 40:35         _microtaskLoop\ndart:async/schedule_microtask.dart 49:5          _startMicrotaskLoop\ndart:isolate-patch/isolate_patch.dart 127:13     _runPendingImmediateCallback\ndart:isolate-patch/isolate_patch.dart 194:5      _RawReceivePort._handleMessage\n","isFailure":false,"type":"error","time":15081}
{"testID":5,"error":"Failed to load \"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/widget_test.dart\":\nCompilation failed for testPath=/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/widget_test.dart: lib/core/router/app_router.dart:21:8: Error: Error when reading 'lib/screens/management/manual_overrides_page.dart': No such file or directory\nimport 'package:jive_money/screens/management/manual_overrides_page.dart';\n       ^\nlib/screens/management/currency_management_page_v2.dart:11:8: Error: Error when reading 'lib/screens/management/manual_overrides_page.dart': No such file or directory\nimport 'package:jive_money/screens/management/manual_overrides_page.dart';\n       ^\nlib/core/router/app_router.dart:225:52: Error: Couldn't find constructor 'ManualOverridesPage'.\n                builder: (context, state) => const ManualOverridesPage(),\n                                                   ^^^^^^^^^^^^^^^^^^^\nlib/providers/currency_provider.dart:375:21: Error: The getter 'HttpClient' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'HttpClient'.\n        final dio = HttpClient.instance.dio;\n                    ^^^^^^^^^^\nlib/providers/currency_provider.dart:470:19: Error: The getter 'HttpClient' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'HttpClient'.\n      final dio = HttpClient.instance.dio;\n                  ^^^^^^^^^^\nlib/providers/currency_provider.dart:471:13: Error: The getter 'ApiReadiness' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'ApiReadiness'.\n      await ApiReadiness.ensureReady(dio);\n            ^^^^^^^^^^^^\nlib/providers/currency_provider.dart:500:19: Error: The getter 'HttpClient' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'HttpClient'.\n      final dio = HttpClient.instance.dio;\n                  ^^^^^^^^^^\nlib/providers/currency_provider.dart:501:13: Error: The getter 'ApiReadiness' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'ApiReadiness'.\n      await ApiReadiness.ensureReady(dio);\n            ^^^^^^^^^^^^\nlib/providers/currency_provider.dart:530:19: Error: The getter 'HttpClient' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'HttpClient'.\n      final dio = HttpClient.instance.dio;\n                  ^^^^^^^^^^\nlib/providers/currency_provider.dart:531:13: Error: The getter 'ApiReadiness' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'ApiReadiness'.\n      await ApiReadiness.ensureReady(dio);\n            ^^^^^^^^^^^^\nlib/screens/management/currency_management_page_v2.dart:74:59: Error: Not a constant expression.\n                  MaterialPageRoute(builder: (_) => const ManualOverridesPage()),\n                                                          ^^^^^^^^^^^^^^^^^^^\n.","stackTrace":"","isFailure":false,"type":"error","time":24769}
{"testID":5,"result":"error","skipped":false,"hidden":false,"type":"testDone","time":24769}
{"suite":{"id":8,"platform":"vm","path":"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_quiet_test.dart"},"type":"suite","time":24769}
{"test":{"id":9,"name":"loading /home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_quiet_test.dart","suiteID":8,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":24769}
{"testID":1,"error":"Error: The Dart compiler exited unexpectedly.","stackTrace":"package:flutter_tools/src/base/common.dart 34:3  throwToolExit\npackage:flutter_tools/src/compile.dart 910:11    DefaultResidentCompiler._compile.<fn>\ndart:async/zone.dart 1538:47                     _rootRunUnary\ndart:async/zone.dart 1429:19                     _CustomZone.runUnary\ndart:async/future_impl.dart 948:45               Future._propagateToListeners.handleValueCallback\ndart:async/future_impl.dart 977:13               Future._propagateToListeners\ndart:async/future_impl.dart 862:9                Future._propagateToListeners\ndart:async/future_impl.dart 720:5                Future._completeWithValue\ndart:async/future_impl.dart 804:7                Future._asyncCompleteWithValue.<fn>\ndart:async/zone.dart 1525:13                     _rootRun\ndart:async/zone.dart 1422:19                     _CustomZone.run\ndart:async/zone.dart 1321:7                      _CustomZone.runGuarded\ndart:async/zone.dart 1362:23                     _CustomZone.bindCallbackGuarded.<fn>\ndart:async/schedule_microtask.dart 40:35         _microtaskLoop\ndart:async/schedule_microtask.dart 49:5          _startMicrotaskLoop\ndart:isolate-patch/isolate_patch.dart 127:13     _runPendingImmediateCallback\ndart:isolate-patch/isolate_patch.dart 194:5      _RawReceivePort._handleMessage\n","isFailure":false,"type":"error","time":24817}
{"testID":7,"error":"Failed to load \"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_selection_page_test.dart\":\nCompilation failed for testPath=/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_selection_page_test.dart: lib/providers/currency_provider.dart:375:21: Error: The getter 'HttpClient' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'HttpClient'.\n        final dio = HttpClient.instance.dio;\n                    ^^^^^^^^^^\nlib/providers/currency_provider.dart:470:19: Error: The getter 'HttpClient' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'HttpClient'.\n      final dio = HttpClient.instance.dio;\n                  ^^^^^^^^^^\nlib/providers/currency_provider.dart:471:13: Error: The getter 'ApiReadiness' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'ApiReadiness'.\n      await ApiReadiness.ensureReady(dio);\n            ^^^^^^^^^^^^\nlib/providers/currency_provider.dart:500:19: Error: The getter 'HttpClient' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'HttpClient'.\n      final dio = HttpClient.instance.dio;\n                  ^^^^^^^^^^\nlib/providers/currency_provider.dart:501:13: Error: The getter 'ApiReadiness' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'ApiReadiness'.\n      await ApiReadiness.ensureReady(dio);\n            ^^^^^^^^^^^^\nlib/providers/currency_provider.dart:530:19: Error: The getter 'HttpClient' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'HttpClient'.\n      final dio = HttpClient.instance.dio;\n                  ^^^^^^^^^^\nlib/providers/currency_provider.dart:531:13: Error: The getter 'ApiReadiness' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'ApiReadiness'.\n      await ApiReadiness.ensureReady(dio);\n            ^^^^^^^^^^^^\n.","stackTrace":"","isFailure":false,"type":"error","time":32208}
{"testID":7,"result":"error","skipped":false,"hidden":false,"type":"testDone","time":32208}
{"testID":1,"error":"Error: The Dart compiler exited unexpectedly.","stackTrace":"package:flutter_tools/src/base/common.dart 34:3  throwToolExit\npackage:flutter_tools/src/compile.dart 910:11    DefaultResidentCompiler._compile.<fn>\ndart:async/zone.dart 1538:47                     _rootRunUnary\ndart:async/zone.dart 1429:19                     _CustomZone.runUnary\ndart:async/future_impl.dart 948:45               Future._propagateToListeners.handleValueCallback\ndart:async/future_impl.dart 977:13               Future._propagateToListeners\ndart:async/future_impl.dart 862:9                Future._propagateToListeners\ndart:async/future_impl.dart 720:5                Future._completeWithValue\ndart:async/future_impl.dart 804:7                Future._asyncCompleteWithValue.<fn>\ndart:async/zone.dart 1525:13                     _rootRun\ndart:async/zone.dart 1422:19                     _CustomZone.run\ndart:async/zone.dart 1321:7                      _CustomZone.runGuarded\ndart:async/zone.dart 1362:23                     _CustomZone.bindCallbackGuarded.<fn>\ndart:async/schedule_microtask.dart 40:35         _microtaskLoop\ndart:async/schedule_microtask.dart 49:5          _startMicrotaskLoop\ndart:isolate-patch/isolate_patch.dart 127:13     _runPendingImmediateCallback\ndart:isolate-patch/isolate_patch.dart 194:5      _RawReceivePort._handleMessage\n","isFailure":false,"type":"error","time":32246}
{"testID":9,"error":"Failed to load \"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_quiet_test.dart\":\nCompilation failed for testPath=/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_quiet_test.dart: lib/providers/currency_provider.dart:375:21: Error: The getter 'HttpClient' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'HttpClient'.\n        final dio = HttpClient.instance.dio;\n                    ^^^^^^^^^^\nlib/providers/currency_provider.dart:470:19: Error: The getter 'HttpClient' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'HttpClient'.\n      final dio = HttpClient.instance.dio;\n                  ^^^^^^^^^^\nlib/providers/currency_provider.dart:471:13: Error: The getter 'ApiReadiness' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'ApiReadiness'.\n      await ApiReadiness.ensureReady(dio);\n            ^^^^^^^^^^^^\nlib/providers/currency_provider.dart:500:19: Error: The getter 'HttpClient' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'HttpClient'.\n      final dio = HttpClient.instance.dio;\n                  ^^^^^^^^^^\nlib/providers/currency_provider.dart:501:13: Error: The getter 'ApiReadiness' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'ApiReadiness'.\n      await ApiReadiness.ensureReady(dio);\n            ^^^^^^^^^^^^\nlib/providers/currency_provider.dart:530:19: Error: The getter 'HttpClient' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'HttpClient'.\n      final dio = HttpClient.instance.dio;\n                  ^^^^^^^^^^\nlib/providers/currency_provider.dart:531:13: Error: The getter 'ApiReadiness' isn't defined for the type 'CurrencyNotifier'.\n - 'CurrencyNotifier' is from 'package:jive_money/providers/currency_provider.dart' ('lib/providers/currency_provider.dart').\nTry correcting the name to the name of an existing getter, or defining a getter or field named 'ApiReadiness'.\n      await ApiReadiness.ensureReady(dio);\n            ^^^^^^^^^^^^\n.","stackTrace":"","isFailure":false,"type":"error","time":39630}
{"testID":9,"result":"error","skipped":false,"hidden":false,"type":"testDone","time":39632}
{"success":false,"type":"done","time":39634}
```
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
