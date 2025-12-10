import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/renormind_provider.dart';
import 'screens/main_screen.dart'; // 确保这一行没有红色波浪线

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RenormindProvider()),
      ],
      child: const RenormindApp(),
    ),
  );
}

class RenormindApp extends StatelessWidget {
  const RenormindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Renormind', // 浏览器的标签页标题
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue.withValues(alpha: 0.8),
          error: Colors.red,
        ),
      ),
      home: const MainScreen(), // 这里指向我们在 screens/main_screen.dart 里写的界面
    );
  }
}