import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
class BackgroundTimerService {
  static const notificationId = 888;       // 常驻通知 ID
  static const alertNotificationId = 999;  // 弹窗通知 ID
  
  // 使用 _v3 确保创建全新的通道，清除你之前的静音设置
  static const notificationChannelId = 'renormind_timer_channel_v3';
  static const alertChannelId = 'renormind_alert_channel_v3';

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // 1. 计时器通道 (静音，低干扰)
    const AndroidNotificationChannel timerChannel = AndroidNotificationChannel(
      notificationChannelId,
      'Renormind 计时器',
      description: '显示实时倒计时/正计时',
      importance: Importance.low, 
    );

    // 2. 提醒通道 (高优先级，有声音/震动)
    const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
      alertChannelId,
      'Renormind 提醒',
      description: '预约结束时的强提醒',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(timerChannel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(alertChannel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onServiceStart, 
        autoStart: false, 
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Renormind',
        initialNotificationContent: '同步数据中...',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onServiceStart,
      ),
    );
  }
}

// ==========================================
// 顶层入口函数
// ==========================================

@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final prefs = await SharedPreferences.getInstance();

  // 再次创建通道 (保险起见)
  const AndroidNotificationChannel timerChannel = AndroidNotificationChannel(
    BackgroundTimerService.notificationChannelId,
    'Renormind 计时器',
    description: '显示实时倒计时/正计时',
    importance: Importance.low,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(timerChannel);

  bool isTaskPhase = false;

  Timer.periodic(const Duration(seconds: 1), (timer) async {
    await prefs.reload(); 
    
    String? savedStartIso = prefs.getString('session_start_time');
    int savedDuration = prefs.getInt('reserve_duration') ?? 0;

    if (savedStartIso == null) return;

    final startTime = DateTime.parse(savedStartIso);
    final now = DateTime.now();
    final reserveDuration = Duration(minutes: savedDuration);
    final taskStartTime = startTime.add(reserveDuration);

    String title = "";
    String content = "";
    bool shouldAlert = false;

    if (now.isBefore(taskStartTime)) {
      final remaining = taskStartTime.difference(now).inSeconds;
      title = "预约倒计时";
      content = _formatHelper(remaining);
      isTaskPhase = false;
    } else {
      final elapsed = now.difference(taskStartTime).inSeconds;
      
      if (!isTaskPhase) {
        shouldAlert = true;
        isTaskPhase = true;
      }

      title = "任务进行中";
      content = "+${_formatHelper(elapsed)}";
    }

    // --- 1. 更新常驻通知 ---
    flutterLocalNotificationsPlugin.show(
      BackgroundTimerService.notificationId,
      title,
      content,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          BackgroundTimerService.notificationChannelId,
          'Renormind 计时器',
          icon: '@mipmap/ic_launcher',
          ongoing: true,
          onlyAlertOnce: true,
          showWhen: false,
          // 关键：在这里设置 public 即可在锁屏显示内容
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.service,
        ),
      ),
    );

    // --- 2. 触发强提醒 (弹窗) ---
    if (shouldAlert) {
      flutterLocalNotificationsPlugin.show(
        BackgroundTimerService.alertNotificationId, 
        "⏳ 预约结束！",
        "任务正计时已自动开始。",
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'renormind_alert_channel_v3', // 对应上面的 V3 ID
            'Renormind 提醒',
            importance: Importance.max, 
            priority: Priority.high,    
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
            // 关键：在这里设置 public
            visibility: NotificationVisibility.public,
            category: AndroidNotificationCategory.event, 
          ),
        ),
      );
    }
  });

  service.on('stop').listen((event) {
    service.stopSelf();
  });
}

String _formatHelper(int seconds) {
  int h = seconds ~/ 3600;
  int m = (seconds % 3600) ~/ 60;
  int s = seconds % 60;
  return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
}