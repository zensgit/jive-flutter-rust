import 'package:flutter/material.dart';

class AccountDetailScreen extends StatelessWidget {
  final String accountId;
  
  const AccountDetailScreen({
    super.key,
    required this.accountId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账户详情'),
      ),
      body: Center(
        child: Text('Account Detail: $accountId'),
      ),
    );
  }
}