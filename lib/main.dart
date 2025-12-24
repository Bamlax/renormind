import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart'; // 引入权限库
import 'providers/renormind_provider.dart';
import 'screens/main_screen.dart';
import 'services/background_timer_service.dart'; // 引入服务

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. 初始化后台服务
  await BackgroundTimerService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RenormindProvider()),
      ],
      child: const RenormindApp(),
    ),
  );
}

class RenormindApp extends StatefulWidget {
  const RenormindApp({super.key});

  @override
  State<RenormindApp> createState() => _RenormindAppState();
}

class _RenormindAppState extends State<RenormindApp> {
  
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  // 2. 申请通知权限 (Android 13+)
  Future<void> _requestPermissions() async {
    await Permission.notification.request();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Renormind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue.withValues(alpha: 0.8),
          error: Colors.red,
        ),
      ),
      home: const MainScreen(),
    );
  }
}