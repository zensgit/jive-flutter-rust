import 'package:flutter/material.dart';

/// 测试分类页面 - 不依赖任何Provider
class CategoryTestPage extends StatelessWidget {
  const CategoryTestPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分类管理测试'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category,
              size: 64,
              color: Colors.blue,
            ),
            SizedBox(height: 16),
            Text(
              '分类管理页面',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '页面路由正常工作！',
              style: TextStyle(fontSize: 16, color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}