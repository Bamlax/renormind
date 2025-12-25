import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
class BackgroundTimerService {
  static const notificationId = 888;
  static const alertNotificationId = 999;
  
  static const notificationChannelId = 'renormind_timer_channel_v3';
  static const alertChannelId = 'renormind_alert_channel_v3';

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel timerChannel = AndroidNotificationChannel(
      notificationChannelId,
      'Renormind 计时器',
      description: '显示实时倒计时/正计时',
      importance: Importance.low, 
    );

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

@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final prefs = await SharedPreferences.getInstance();

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

  // 关键：记录上一次是否处于预约阶段
  // 初始化为 true (假设刚开始)，稍后根据实际时间修正
  // 如果直接开始任务 (reserve=0)，这个标志位会在第一次 check 时帮助我们避免弹窗
  bool wasInReservationPhase = true;

  Timer.periodic(const Duration(seconds: 1), (timer) async {
    await prefs.reload(); 
    
    String? savedStartIso = prefs.getString('session_start_time');
    int savedReserveMinutes = prefs.getInt('reserve_duration') ?? 0;
    // 读取任务计划时长 (0 或 -1 表示正计时，>0 表示倒计时)
    int plannedMinutes = prefs.getInt('current_task_planned_minutes') ?? 0;

    if (savedStartIso == null) return;

    final startTime = DateTime.parse(savedStartIso);
    final now = DateTime.now();
    final reserveDuration = Duration(minutes: savedReserveMinutes);
    final taskStartTime = startTime.add(reserveDuration);

    String title = "";
    String content = "";
    bool shouldAlert = false;

    // 判断当前是否处于预约阶段
    bool isInReservationPhase = now.isBefore(taskStartTime);

    // 逻辑：如果上一秒还在预约阶段，这一秒不在了，且预约时长不为0 => 触发弹窗
    if (wasInReservationPhase && !isInReservationPhase && savedReserveMinutes > 0) {
      shouldAlert = true;
    }
    // 更新状态
    wasInReservationPhase = isInReservationPhase;

    if (isInReservationPhase) {
      // --- 预约阶段 ---
      final remaining = taskStartTime.difference(now).inSeconds;
      title = "预约倒计时";
      content = _formatHelper(remaining);
    } else {
      // --- 任务阶段 ---
      final taskElapsedSeconds = now.difference(taskStartTime).inSeconds;
      
      if (plannedMinutes > 0) {
        // [有计划时间] -> 显示倒计时 / 超时
        final int plannedSeconds = plannedMinutes * 60;
        final int remainingTaskTime = plannedSeconds - taskElapsedSeconds;
        
        if (remainingTaskTime >= 0) {
          title = "任务倒计时";
          content = _formatHelper(remainingTaskTime);
        } else {
          title = "任务已超时";
          content = "+${_formatHelper(-remainingTaskTime)}";
        }
      } else {
        // [无计划时间 / -1] -> 显示正计时
        title = "任务进行中";
        content = "+${_formatHelper(taskElapsedSeconds)}";
      }
    }

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
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.service,
          priority: Priority.defaultPriority,
        ),
      ),
    );

    if (shouldAlert) {
      flutterLocalNotificationsPlugin.show(
        BackgroundTimerService.alertNotificationId, 
        "⏳ 预约结束！",
        "任务正计时已自动开始。",
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'renormind_alert_channel_v3', 
            'Renormind 提醒',
            importance: Importance.max, 
            priority: Priority.high,    
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
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