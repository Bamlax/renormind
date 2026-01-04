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
        initialNotificationContent: '', // 初始状态为空
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

  bool wasInReservationPhase = true;

  Future<void> tick() async {
    await prefs.reload(); 
    
    String? savedStartIso = prefs.getString('session_start_time');
    int savedReserveMinutes = prefs.getInt('reserve_duration') ?? 0;
    int plannedMinutes = prefs.getInt('current_task_planned_minutes') ?? 0;

    if (savedStartIso == null) {
      // --- 修改点：无任务时，内容为空 ---
      flutterLocalNotificationsPlugin.show(
        BackgroundTimerService.notificationId,
        'Renormind',
        '', // 内容留空
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
          ),
        ),
      );
      return;
    }

    final startTime = DateTime.parse(savedStartIso);
    final now = DateTime.now();
    final reserveDuration = Duration(minutes: savedReserveMinutes);
    final taskStartTime = startTime.add(reserveDuration);

    String title = "";
    String content = "";
    bool shouldAlert = false;

    bool isInReservationPhase = now.isBefore(taskStartTime);

    if (wasInReservationPhase && !isInReservationPhase && savedReserveMinutes > 0) {
      shouldAlert = true;
    }
    wasInReservationPhase = isInReservationPhase;

    if (isInReservationPhase) {
      final remaining = taskStartTime.difference(now).inSeconds;
      title = "预约倒计时";
      content = _formatHelper(remaining);
    } else {
      final taskElapsedSeconds = now.difference(taskStartTime).inSeconds;
      
      if (plannedMinutes > 0) {
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
  }

  // 立即执行一次，消除延迟
  await tick();

  Timer.periodic(const Duration(seconds: 1), (timer) async {
    await tick();
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