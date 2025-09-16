import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/management/currency_management_page_v2.dart';
import 'screens/currency_converter_page.dart';
import 'widgets/currency_converter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for currency preferences
  await Hive.initFlutter();
  await Hive.openBox('preferences');
  
  runApp(const ProviderScope(child: CurrencyTestApp()));
}

class CurrencyTestApp extends StatelessWidget {
  const CurrencyTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Currency Management Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('货币管理测试'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Currency Converter Widget
              const CurrencyConverter(
                initialFromCurrency: 'USD',
                initialToCurrency: 'CNY',
                initialAmount: 100,
              ),
              
              const SizedBox(height: 32),
              
              // Navigation Buttons
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CurrencyManagementPageV2(),
                    ),
                  );
                },
                icon: const Icon(Icons.settings),
                label: const Text('货币管理设置'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              
              const SizedBox(height: 16),
              
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CurrencyConverterPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.calculate),
                label: const Text('货币转换器页面'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
