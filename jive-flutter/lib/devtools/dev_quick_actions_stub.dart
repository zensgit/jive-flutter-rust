import 'package:flutter/material.dart';

// Non-web (or release) no-op implementation
class DevQuickActions extends StatelessWidget {
  final Widget child;
  const DevQuickActions({super.key, required this.child});
  @override
  Widget build(BuildContext context) => child;
}
