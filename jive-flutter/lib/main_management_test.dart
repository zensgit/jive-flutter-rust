import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/management/category_management_page.dart';

void main() {
  runApp(const ProviderScope(child: ManagementTestApp()));
}

class ManagementTestApp extends StatelessWidget {
  const ManagementTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Management Pages Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const CategoryManagementPage(),
    );
  }
}
