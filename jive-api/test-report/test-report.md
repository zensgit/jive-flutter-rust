# Flutter Test Report
## Test Summary
- Date: Wed Oct  8 09:34:05 UTC 2025
- Flutter Version: 3.35.3

## Test Results
```json
Resolving dependencies...
Downloading packages...
  _fe_analyzer_shared 67.0.0 (89.0.0 available)
  analyzer 6.4.1 (8.2.0 available)
  analyzer_plugin 0.11.3 (0.13.8 available)
  build 2.4.1 (4.0.1 available)
  build_config 1.1.2 (1.2.0 available)
  build_resolvers 2.4.2 (3.0.4 available)
  build_runner 2.4.13 (2.9.0 available)
  build_runner_core 7.3.2 (9.3.2 available)
  characters 1.4.0 (1.4.1 available)
  custom_lint_core 0.6.3 (0.8.1 available)
  dart_style 2.3.6 (3.1.2 available)
  file_picker 8.3.7 (10.3.3 available)
  fl_chart 0.66.2 (1.1.1 available)
  flutter_launcher_icons 0.13.1 (0.14.4 available)
  flutter_lints 3.0.2 (6.0.0 available)
  flutter_riverpod 2.6.1 (3.0.2 available)
  freezed 2.5.2 (3.2.3 available)
  freezed_annotation 2.4.4 (3.1.0 available)
  go_router 12.1.3 (16.2.4 available)
  image_picker_android 0.8.13+2 (0.8.13+3 available)
! intl 0.19.0 (overridden) (0.20.2 available)
  json_serializable 6.8.0 (6.11.1 available)
  lints 3.0.0 (6.0.0 available)
  logger 2.6.1 (2.6.2 available)
  material_color_utilities 0.11.1 (0.13.0 available)
  meta 1.16.0 (1.17.0 available)
  pool 1.5.1 (1.5.2 available)
  protobuf 3.1.0 (5.0.0 available)
  retrofit 4.7.2 (4.7.3 available)
  retrofit_generator 8.2.1 (10.0.6 available)
  riverpod 2.6.1 (3.0.2 available)
  riverpod_analyzer_utils 0.5.1 (0.5.10 available)
  riverpod_annotation 2.6.1 (3.0.2 available)
  riverpod_generator 2.4.0 (3.0.2 available)
  shared_preferences_android 2.4.12 (2.4.14 available)
  shelf_web_socket 2.0.1 (3.0.0 available)
  source_gen 1.5.0 (4.0.1 available)
  source_helper 1.3.5 (1.3.8 available)
  test_api 0.7.6 (0.7.7 available)
  uni_links 0.5.1 (discontinued replaced by app_links)
  very_good_analysis 5.1.0 (10.0.0 available)
  watcher 1.1.3 (1.1.4 available)
  win32 5.14.0 (5.15.0 available)
Got dependencies!
1 package is discontinued.
42 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
{"protocolVersion":"0.1.1","runnerVersion":null,"pid":2467,"type":"start","time":0}
{"suite":{"id":0,"platform":"vm","path":"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_mode_test.dart"},"type":"suite","time":0}
{"test":{"id":1,"name":"loading /home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_mode_test.dart","suiteID":0,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":1}
{"count":12,"time":7,"type":"allSuites"}

[{"event":"test.startedProcess","params":{"vmServiceUri":"http://127.0.0.1:37161/j_6uG0ciADI=/"}}]
{"testID":1,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":3400}
{"group":{"id":2,"suiteID":0,"parentID":null,"name":"","metadata":{"skip":false,"skipReason":null},"testCount":14,"line":null,"column":null,"url":null},"type":"group","time":3403}
{"group":{"id":3,"suiteID":0,"parentID":2,"name":"TravelEvent Model Tests","metadata":{"skip":false,"skipReason":null},"testCount":5,"line":5,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_mode_test.dart"},"type":"group","time":3404}
{"test":{"id":4,"name":"TravelEvent Model Tests should create TravelEvent with required fields","suiteID":0,"groupIDs":[2,3],"metadata":{"skip":false,"skipReason":null},"line":6,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_mode_test.dart"},"type":"testStart","time":3404}
{"testID":4,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":3444}
{"test":{"id":5,"name":"TravelEvent Model Tests should calculate duration correctly","suiteID":0,"groupIDs":[2,3],"metadata":{"skip":false,"skipReason":null},"line":19,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_mode_test.dart"},"type":"testStart","time":3445}
{"testID":5,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":3448}
{"test":{"id":6,"name":"TravelEvent Model Tests should determine status correctly","suiteID":0,"groupIDs":[2,3],"metadata":{"skip":false,"skipReason":null},"line":29,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_mode_test.dart"},"type":"testStart","time":3448}
{"testID":6,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":3452}
{"test":{"id":7,"name":"TravelEvent Model Tests should check if date is in travel range","suiteID":0,"groupIDs":[2,3],"metadata":{"skip":false,"skipReason":null},"line":57,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_mode_test.dart"},"type":"testStart","time":3453}
{"testID":7,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":3455}
{"test":{"id":8,"name":"TravelEvent Model Tests should handle optional fields","suiteID":0,"groupIDs":[2,3],"metadata":{"skip":false,"skipReason":null},"line":71,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_mode_test.dart"},"type":"testStart","time":3456}
{"testID":8,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":3458}
{"group":{"id":9,"suiteID":0,"parentID":2,"name":"Budget Calculation Tests","metadata":{"skip":false,"skipReason":null},"testCount":3,"line":87,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_mode_test.dart"},"type":"group","time":3458}
{"test":{"id":10,"name":"Budget Calculation Tests should calculate budget usage percentage","suiteID":0,"groupIDs":[2,9],"metadata":{"skip":false,"skipReason":null},"line":88,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_mode_test.dart"},"type":"testStart","time":3459}
{"testID":10,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":3461}
{"test":{"id":11,"name":"Budget Calculation Tests should handle zero budget","suiteID":0,"groupIDs":[2,9],"metadata":{"skip":false,"skipReason":null},"line":101,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_mode_test.dart"},"type":"testStart","time":3461}
{"testID":11,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":3464}
{"test":{"id":12,"name":"Budget Calculation Tests should detect over budget","suiteID":0,"groupIDs":[2,9],"metadata":{"skip":false,"skipReason":null},"line":115,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_mode_test.dart"},"type":"testStart","time":3465}
{"testID":12,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":3467}
{"group":{"id":13,"suiteID":0,"parentID":2,"name":"Transaction Linking Tests","metadata":{"skip":false,"skipReason":null},"testCount":2,"line":129,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_mode_test.dart"},"type":"group","time":3468}
{"test":{"id":14,"name":"Transaction Linking Tests should track transaction count","suiteID":0,"groupIDs":[2,13],"metadata":{"skip":false,"skipReason":null},"line":130,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_mode_test.dart"},"type":"testStart","time":3468}
{"testID":14,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":3470}
{"test":{"id":15,"name":"Transaction Linking Tests should filter transactions by date range","suiteID":0,"groupIDs":[2,13],"metadata":{"skip":false,"skipReason":null},"line":141,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_mode_test.dart"},"type":"testStart","time":3470}
{"testID":15,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":3474}
{"group":{"id":16,"suiteID":0,"parentID":2,"name":"Currency Support Tests","metadata":{"skip":false,"skipReason":null},"testCount":2,"line":172,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_mode_test.dart"},"type":"group","time":3474}
{"test":{"id":17,"name":"Currency Support Tests should support multiple currencies","suiteID":0,"groupIDs":[2,16],"metadata":{"skip":false,"skipReason":null},"line":173,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_mode_test.dart"},"type":"testStart","time":3474}
{"testID":17,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":3478}
{"test":{"id":18,"name":"Currency Support Tests should default to CNY currency","suiteID":0,"groupIDs":[2,16],"metadata":{"skip":false,"skipReason":null},"line":188,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_mode_test.dart"},"type":"testStart","time":3478}
{"testID":18,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":3481}
{"group":{"id":19,"suiteID":0,"parentID":2,"name":"Travel Statistics Tests","metadata":{"skip":false,"skipReason":null},"testCount":2,"line":199,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_mode_test.dart"},"type":"group","time":3481}
{"test":{"id":20,"name":"Travel Statistics Tests should calculate daily average spending","suiteID":0,"groupIDs":[2,19],"metadata":{"skip":false,"skipReason":null},"line":200,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_mode_test.dart"},"type":"testStart","time":3481}
{"testID":20,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":3485}
{"test":{"id":21,"name":"Travel Statistics Tests should track travel categories","suiteID":0,"groupIDs":[2,19],"metadata":{"skip":false,"skipReason":null},"line":212,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_mode_test.dart"},"type":"testStart","time":3486}
{"testID":21,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":3489}
{"suite":{"id":22,"platform":"vm","path":"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_quiet_test.dart"},"type":"suite","time":4178}
{"test":{"id":23,"name":"loading /home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_quiet_test.dart","suiteID":22,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":4178}

[{"event":"test.startedProcess","params":{"vmServiceUri":"http://127.0.0.1:37247/m0cipL1-D78=/"}}]
{"testID":23,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":5151}
{"group":{"id":24,"suiteID":22,"parentID":null,"name":"","metadata":{"skip":false,"skipReason":null},"testCount":2,"line":null,"column":null,"url":null},"type":"group","time":5152}
{"test":{"id":25,"name":"(setUpAll)","suiteID":22,"groupIDs":[24],"metadata":{"skip":false,"skipReason":null},"line":65,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_quiet_test.dart"},"type":"testStart","time":5156}
{"testID":25,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":5256}
{"test":{"id":26,"name":"quiet mode: no calls before initialize; initialize triggers first load; explicit refresh triggers second","suiteID":22,"groupIDs":[24],"metadata":{"skip":false,"skipReason":null},"line":87,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_quiet_test.dart"},"type":"testStart","time":5257}
{"testID":26,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":5451}
{"test":{"id":27,"name":"initialize() is idempotent","suiteID":22,"groupIDs":[24],"metadata":{"skip":false,"skipReason":null},"line":103,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_quiet_test.dart"},"type":"testStart","time":5452}
{"testID":27,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":5479}
{"test":{"id":28,"name":"(tearDownAll)","suiteID":22,"groupIDs":[24],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":5480}
{"testID":28,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":5482}
{"suite":{"id":29,"platform":"vm","path":"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_export_test.dart"},"type":"suite","time":6224}
{"test":{"id":30,"name":"loading /home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_export_test.dart","suiteID":29,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":6224}

[{"event":"test.startedProcess","params":{"vmServiceUri":"http://127.0.0.1:46155/rKhIfHuXkG4=/"}}]
{"testID":30,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":7311}
{"group":{"id":31,"suiteID":29,"parentID":null,"name":"","metadata":{"skip":false,"skipReason":null},"testCount":19,"line":null,"column":null,"url":null},"type":"group","time":7312}
{"group":{"id":32,"suiteID":29,"parentID":31,"name":"TravelExportService Tests","metadata":{"skip":false,"skipReason":null},"testCount":19,"line":8,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_export_test.dart"},"type":"group","time":7312}
{"test":{"id":33,"name":"TravelExportService Tests should create TravelExportService instance","suiteID":29,"groupIDs":[31,32],"metadata":{"skip":false,"skipReason":null},"line":65,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_export_test.dart"},"type":"testStart","time":7312}
{"testID":33,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":7344}
{"test":{"id":34,"name":"TravelExportService Tests should have CurrencyFormatter instance","suiteID":29,"groupIDs":[31,32],"metadata":{"skip":false,"skipReason":null},"line":70,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_export_test.dart"},"type":"testStart","time":7344}
{"testID":34,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":7351}
{"test":{"id":35,"name":"TravelExportService Tests should calculate category breakdown correctly","suiteID":29,"groupIDs":[31,32],"metadata":{"skip":false,"skipReason":null},"line":78,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_export_test.dart"},"type":"testStart","time":7352}
{"testID":35,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":7358}
{"test":{"id":36,"name":"TravelExportService Tests should format dates correctly","suiteID":29,"groupIDs":[31,32],"metadata":{"skip":false,"skipReason":null},"line":94,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_export_test.dart"},"type":"testStart","time":7358}
{"testID":36,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":7364}
{"test":{"id":37,"name":"TravelExportService Tests should get correct category names","suiteID":29,"groupIDs":[31,32],"metadata":{"skip":false,"skipReason":null},"line":110,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_export_test.dart"},"type":"testStart","time":7364}
{"testID":37,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":7367}
{"test":{"id":38,"name":"TravelExportService Tests should get correct status labels","suiteID":29,"groupIDs":[31,32],"metadata":{"skip":false,"skipReason":null},"line":127,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_export_test.dart"},"type":"testStart","time":7368}
{"testID":38,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":7371}
{"test":{"id":39,"name":"TravelExportService Tests should calculate budget usage percentage","suiteID":29,"groupIDs":[31,32],"metadata":{"skip":false,"skipReason":null},"line":141,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_export_test.dart"},"type":"testStart","time":7372}
{"testID":39,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":7376}
{"test":{"id":40,"name":"TravelExportService Tests should calculate daily average correctly","suiteID":29,"groupIDs":[31,32],"metadata":{"skip":false,"skipReason":null},"line":147,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_export_test.dart"},"type":"testStart","time":7376}
{"testID":40,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":7381}
{"test":{"id":41,"name":"TravelExportService Tests should calculate transaction average correctly","suiteID":29,"groupIDs":[31,32],"metadata":{"skip":false,"skipReason":null},"line":152,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_export_test.dart"},"type":"testStart","time":7381}
{"testID":41,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":7384}
{"test":{"id":42,"name":"TravelExportService Tests should handle empty transactions list","suiteID":29,"groupIDs":[31,32],"metadata":{"skip":false,"skipReason":null},"line":157,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_export_test.dart"},"type":"testStart","time":7385}
{"testID":42,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":7389}
{"test":{"id":43,"name":"TravelExportService Tests should handle null budget gracefully","suiteID":29,"groupIDs":[31,32],"metadata":{"skip":false,"skipReason":null},"line":170,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_export_test.dart"},"type":"testStart","time":7389}
{"testID":43,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":7394}
{"test":{"id":44,"name":"TravelExportService Tests should escape special characters in CSV","suiteID":29,"groupIDs":[31,32],"metadata":{"skip":false,"skipReason":null},"line":189,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_export_test.dart"},"type":"testStart","time":7394}
{"testID":44,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":7398}
{"test":{"id":45,"name":"TravelExportService Tests should format currency amounts correctly","suiteID":29,"groupIDs":[31,32],"metadata":{"skip":false,"skipReason":null},"line":195,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_export_test.dart"},"type":"testStart","time":7398}
{"testID":45,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":7402}
{"test":{"id":46,"name":"TravelExportService Tests should identify over-budget status","suiteID":29,"groupIDs":[31,32],"metadata":{"skip":false,"skipReason":null},"line":205,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_export_test.dart"},"type":"testStart","time":7402}
{"testID":46,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":7405}
{"test":{"id":47,"name":"TravelExportService Tests should calculate remaining budget","suiteID":29,"groupIDs":[31,32],"metadata":{"skip":false,"skipReason":null},"line":218,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_export_test.dart"},"type":"testStart","time":7406}
{"testID":47,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":7409}
{"test":{"id":48,"name":"TravelExportService Tests should group transactions by date","suiteID":29,"groupIDs":[31,32],"metadata":{"skip":false,"skipReason":null},"line":236,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_export_test.dart"},"type":"testStart","time":7410}
{"testID":48,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":7413}
{"test":{"id":49,"name":"TravelExportService Tests should find top expenses","suiteID":29,"groupIDs":[31,32],"metadata":{"skip":false,"skipReason":null},"line":254,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_export_test.dart"},"type":"testStart","time":7414}
{"testID":49,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":7419}
{"test":{"id":50,"name":"TravelExportService Tests should handle category budgets map","suiteID":29,"groupIDs":[31,32],"metadata":{"skip":false,"skipReason":null},"line":267,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_export_test.dart"},"type":"testStart","time":7419}
{"testID":50,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":7424}
{"test":{"id":51,"name":"TravelExportService Tests should generate valid file names","suiteID":29,"groupIDs":[31,32],"metadata":{"skip":false,"skipReason":null},"line":280,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/travel_export_test.dart"},"type":"testStart","time":7425}
{"testID":51,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":7429}
{"suite":{"id":52,"platform":"vm","path":"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/services/share_service_test.dart"},"type":"suite","time":8367}
{"test":{"id":53,"name":"loading /home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/services/share_service_test.dart","suiteID":52,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":8367}

[{"event":"test.startedProcess","params":{"vmServiceUri":"http://127.0.0.1:43239/lubSy8V_p7A=/"}}]
{"testID":53,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":9427}
{"group":{"id":54,"suiteID":52,"parentID":null,"name":"","metadata":{"skip":false,"skipReason":null},"testCount":2,"line":null,"column":null,"url":null},"type":"group","time":9428}
{"group":{"id":55,"suiteID":52,"parentID":54,"name":"ShareService smoke tests","metadata":{"skip":false,"skipReason":null},"testCount":2,"line":12,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/services/share_service_test.dart"},"type":"group","time":9428}
{"test":{"id":56,"name":"ShareService smoke tests shareFamilyInvitation sends expected text","suiteID":52,"groupIDs":[54,55],"metadata":{"skip":false,"skipReason":null},"line":174,"column":5,"url":"package:flutter_test/src/widget_tester.dart","root_line":13,"root_column":5,"root_url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/services/share_service_test.dart"},"type":"testStart","time":9428}
{"testID":56,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":10067}
{"test":{"id":57,"name":"ShareService smoke tests shareToSocialMedia includes hashtags and url","suiteID":52,"groupIDs":[54,55],"metadata":{"skip":false,"skipReason":null},"line":174,"column":5,"url":"package:flutter_test/src/widget_tester.dart","root_line":49,"root_column":5,"root_url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/services/share_service_test.dart"},"type":"testStart","time":10068}
{"testID":57,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":10125}
{"suite":{"id":58,"platform":"vm","path":"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/settings_manual_overrides_navigation_test.dart"},"type":"suite","time":11042}
{"test":{"id":59,"name":"loading /home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/settings_manual_overrides_navigation_test.dart","suiteID":58,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":11042}

[{"event":"test.startedProcess","params":{"vmServiceUri":"http://127.0.0.1:35345/6dUuc-mSRys=/"}}]
{"testID":59,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":12149}
{"group":{"id":60,"suiteID":58,"parentID":null,"name":"","metadata":{"skip":false,"skipReason":null},"testCount":1,"line":null,"column":null,"url":null},"type":"group","time":12149}
{"test":{"id":61,"name":"Settings has manual overrides entry and navigates","suiteID":58,"groupIDs":[60],"metadata":{"skip":false,"skipReason":null},"line":174,"column":5,"url":"package:flutter_test/src/widget_tester.dart","root_line":41,"root_column":3,"root_url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/settings_manual_overrides_navigation_test.dart"},"type":"testStart","time":12149}
{"testID":61,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":13224}
{"suite":{"id":62,"platform":"vm","path":"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/widget_test.dart"},"type":"suite","time":14767}
{"test":{"id":63,"name":"loading /home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/widget_test.dart","suiteID":62,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":14767}

[{"event":"test.startedProcess","params":{"vmServiceUri":"http://127.0.0.1:44409/_fJQ66N7-pQ=/"}}]
{"testID":63,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":15813}
{"group":{"id":64,"suiteID":62,"parentID":null,"name":"","metadata":{"skip":false,"skipReason":null},"testCount":1,"line":null,"column":null,"url":null},"type":"group","time":15816}
{"test":{"id":65,"name":"(setUpAll)","suiteID":62,"groupIDs":[64],"metadata":{"skip":false,"skipReason":null},"line":19,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/widget_test.dart"},"type":"testStart","time":15816}
{"testID":65,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":15880}
{"test":{"id":66,"name":"App builds without exceptions","suiteID":62,"groupIDs":[64],"metadata":{"skip":false,"skipReason":null},"line":174,"column":5,"url":"package:flutter_test/src/widget_tester.dart","root_line":28,"root_column":3,"root_url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/widget_test.dart"},"type":"testStart","time":15881}
{"testID":66,"messageType":"print","message":"@@ App.builder start","type":"print","time":16459}
{"testID":66,"messageType":"print","message":"ℹ️ Skip auto refresh (token absent)","type":"print","time":16759}
{"testID":66,"messageType":"print","message":"Auth state in splash: AuthStatus.unauthenticated, user: null","type":"print","time":16759}
{"testID":66,"messageType":"print","message":"@@ App.builder start","type":"print","time":16784}
{"testID":66,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":17315}
{"test":{"id":67,"name":"(tearDownAll)","suiteID":62,"groupIDs":[64],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":17316}
{"testID":67,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":17327}
{"suite":{"id":68,"platform":"vm","path":"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_meta_test.dart"},"type":"suite","time":18207}
{"test":{"id":69,"name":"loading /home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_meta_test.dart","suiteID":68,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":18207}

[{"event":"test.startedProcess","params":{"vmServiceUri":"http://127.0.0.1:43597/HD6i-LKVIIk=/"}}]
{"testID":69,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":19057}
{"group":{"id":70,"suiteID":68,"parentID":null,"name":"","metadata":{"skip":false,"skipReason":null},"testCount":1,"line":null,"column":null,"url":null},"type":"group","time":19057}
{"test":{"id":71,"name":"(setUpAll)","suiteID":68,"groupIDs":[70],"metadata":{"skip":false,"skipReason":null},"line":22,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_meta_test.dart"},"type":"testStart","time":19057}
{"testID":71,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":19188}
{"group":{"id":72,"suiteID":68,"parentID":70,"name":"CurrencyNotifier catalog meta","metadata":{"skip":false,"skipReason":null},"testCount":1,"line":29,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_meta_test.dart"},"type":"group","time":19188}
{"test":{"id":73,"name":"CurrencyNotifier catalog meta initial usingFallback true when first fetch throws","suiteID":68,"groupIDs":[70,72],"metadata":{"skip":false,"skipReason":null},"line":31,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_notifier_meta_test.dart"},"type":"testStart","time":19189}
{"testID":73,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":19253}
{"test":{"id":74,"name":"(tearDownAll)","suiteID":68,"groupIDs":[70],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":19254}
{"testID":74,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":19259}
{"suite":{"id":75,"platform":"vm","path":"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_preferences_sync_test.dart"},"type":"suite","time":19891}
{"test":{"id":76,"name":"loading /home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_preferences_sync_test.dart","suiteID":75,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":19891}

[{"event":"test.startedProcess","params":{"vmServiceUri":"http://127.0.0.1:46581/QZSBSW0OoCE=/"}}]
{"testID":76,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":20777}
{"group":{"id":77,"suiteID":75,"parentID":null,"name":"","metadata":{"skip":false,"skipReason":null},"testCount":3,"line":null,"column":null,"url":null},"type":"group","time":20778}
{"test":{"id":78,"name":"(setUpAll)","suiteID":75,"groupIDs":[77],"metadata":{"skip":false,"skipReason":null},"line":103,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_preferences_sync_test.dart"},"type":"testStart","time":20778}
{"testID":78,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":20847}
{"test":{"id":79,"name":"debounce combines rapid preference pushes and succeeds","suiteID":75,"groupIDs":[77],"metadata":{"skip":false,"skipReason":null},"line":111,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_preferences_sync_test.dart"},"type":"testStart","time":20847}
{"testID":79,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":20902}
{"test":{"id":80,"name":"failure stores pending then flush success clears it","suiteID":75,"groupIDs":[77],"metadata":{"skip":false,"skipReason":null},"line":138,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_preferences_sync_test.dart"},"type":"testStart","time":20902}
{"testID":79,"messageType":"print","message":"Error loading exchange rates: Bad state: Tried to use CurrencyNotifier after `dispose` was called.\n\nConsider checking `mounted`.\n","type":"print","time":20931}
{"testID":80,"messageType":"print","message":"Failed to push currency preferences (will persist pending): Exception: network","type":"print","time":21420}
{"testID":80,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":21537}
{"test":{"id":81,"name":"startup flush clears preexisting pending","suiteID":75,"groupIDs":[77],"metadata":{"skip":false,"skipReason":null},"line":166,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_preferences_sync_test.dart"},"type":"testStart","time":21538}
{"testID":81,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":21544}
{"test":{"id":82,"name":"(tearDownAll)","suiteID":75,"groupIDs":[77],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":21545}
{"testID":82,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":21548}
{"suite":{"id":83,"platform":"vm","path":"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/transactions/transaction_controller_grouping_test.dart"},"type":"suite","time":22168}
{"test":{"id":84,"name":"loading /home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/transactions/transaction_controller_grouping_test.dart","suiteID":83,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":22168}

[{"event":"test.startedProcess","params":{"vmServiceUri":"http://127.0.0.1:45611/UWBrIsM0I4E=/"}}]
{"testID":84,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":23161}
{"group":{"id":85,"suiteID":83,"parentID":null,"name":"","metadata":{"skip":false,"skipReason":null},"testCount":2,"line":null,"column":null,"url":null},"type":"group","time":23161}
{"group":{"id":86,"suiteID":83,"parentID":85,"name":"TransactionController grouping & collapse persistence","metadata":{"skip":false,"skipReason":null},"testCount":2,"line":41,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/transactions/transaction_controller_grouping_test.dart"},"type":"group","time":23163}
{"test":{"id":87,"name":"TransactionController grouping & collapse persistence setGrouping persists to SharedPreferences","suiteID":83,"groupIDs":[85,86],"metadata":{"skip":false,"skipReason":null},"line":47,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/transactions/transaction_controller_grouping_test.dart"},"type":"testStart","time":23163}
{"testID":87,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":23263}
{"test":{"id":88,"name":"TransactionController grouping & collapse persistence toggleGroupCollapse persists collapsed keys","suiteID":83,"groupIDs":[85,86],"metadata":{"skip":false,"skipReason":null},"line":65,"column":5,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/transactions/transaction_controller_grouping_test.dart"},"type":"testStart","time":23263}
{"testID":88,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":23293}
{"suite":{"id":89,"platform":"vm","path":"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/transactions/transaction_list_grouping_widget_test.dart"},"type":"suite","time":24248}
{"test":{"id":90,"name":"loading /home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/transactions/transaction_list_grouping_widget_test.dart","suiteID":89,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":24248}

[{"event":"test.startedProcess","params":{"vmServiceUri":"http://127.0.0.1:41017/DZS9JVB4NVk=/"}}]
{"testID":90,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":25331}
{"group":{"id":91,"suiteID":89,"parentID":null,"name":"","metadata":{"skip":false,"skipReason":null},"testCount":1,"line":null,"column":null,"url":null},"type":"group","time":25331}
{"group":{"id":92,"suiteID":89,"parentID":91,"name":"TransactionList grouping widget","metadata":{"skip":false,"skipReason":null},"testCount":1,"line":41,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/transactions/transaction_list_grouping_widget_test.dart"},"type":"group","time":25332}
{"test":{"id":93,"name":"TransactionList grouping widget category grouping renders and collapses","suiteID":89,"groupIDs":[91,92],"metadata":{"skip":false,"skipReason":null},"line":174,"column":5,"url":"package:flutter_test/src/widget_tester.dart","root_line":42,"root_column":5,"root_url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/transactions/transaction_list_grouping_widget_test.dart"},"type":"testStart","time":25333}
{"testID":93,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":26128}
{"suite":{"id":94,"platform":"vm","path":"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/widgets/qr_share_smoke_test.dart"},"type":"suite","time":27133}
{"test":{"id":95,"name":"loading /home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/widgets/qr_share_smoke_test.dart","suiteID":94,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":27133}

[{"event":"test.startedProcess","params":{"vmServiceUri":"http://127.0.0.1:38835/UpmVoNmfzUU=/"}}]
{"testID":95,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":28103}
{"group":{"id":96,"suiteID":94,"parentID":null,"name":"","metadata":{"skip":false,"skipReason":null},"testCount":1,"line":null,"column":null,"url":null},"type":"group","time":28104}
{"test":{"id":97,"name":"ShareService.shareQrCode shares expected text","suiteID":94,"groupIDs":[96],"metadata":{"skip":false,"skipReason":null},"line":174,"column":5,"url":"package:flutter_test/src/widget_tester.dart","root_line":11,"root_column":3,"root_url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/widgets/qr_share_smoke_test.dart"},"type":"testStart","time":28105}
{"testID":97,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":28676}
{"suite":{"id":98,"platform":"vm","path":"/home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_selection_page_test.dart"},"type":"suite","time":29500}
{"test":{"id":99,"name":"loading /home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_selection_page_test.dart","suiteID":98,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":29500}

[{"event":"test.startedProcess","params":{"vmServiceUri":"http://127.0.0.1:36551/HX91GCqabiA=/"}}]
{"testID":99,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":30591}
{"group":{"id":100,"suiteID":98,"parentID":null,"name":"","metadata":{"skip":false,"skipReason":null},"testCount":2,"line":null,"column":null,"url":null},"type":"group","time":30592}
{"test":{"id":101,"name":"(setUpAll)","suiteID":98,"groupIDs":[100],"metadata":{"skip":false,"skipReason":null},"line":78,"column":3,"url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_selection_page_test.dart"},"type":"testStart","time":30592}
{"testID":101,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":30676}
{"test":{"id":102,"name":"Selecting base currency returns via Navigator.pop","suiteID":98,"groupIDs":[100],"metadata":{"skip":false,"skipReason":null},"line":174,"column":5,"url":"package:flutter_test/src/widget_tester.dart","root_line":85,"root_column":3,"root_url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_selection_page_test.dart"},"type":"testStart","time":30677}
{"testID":102,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":32128}
{"test":{"id":103,"name":"Base currency is sorted to top and marked","suiteID":98,"groupIDs":[100],"metadata":{"skip":false,"skipReason":null},"line":174,"column":5,"url":"package:flutter_test/src/widget_tester.dart","root_line":120,"root_column":3,"root_url":"file:///home/runner/work/jive-flutter-rust/jive-flutter-rust/jive-flutter/test/currency_selection_page_test.dart"},"type":"testStart","time":32129}
{"testID":103,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":32399}
{"test":{"id":104,"name":"(tearDownAll)","suiteID":98,"groupIDs":[100],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":32399}
{"testID":104,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":32404}
{"success":true,"type":"done","time":33392}
```
## Coverage Summary
Coverage data generated successfully
