import 'package:flutter/material.dart';

class TransactionDetailScreen extends StatelessWidget {
  final String transactionId;

  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('交易详情'),
      ),
      body: Center(
        child: const Text('Transaction Detail: $transactionId'),
      ),
    );
  }
}
