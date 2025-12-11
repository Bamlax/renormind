import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/renormind_provider.dart';
import '../task_model.dart';

class TimerScreen extends StatefulWidget {
  final CtdpTask task;
  const TimerScreen({super.key, required this.task});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  late Timer _timer;
  late int _planSeconds;    
  late DateTime _startTime; // 本次计时的起点
  
  // UI显示用的秒数
  int _currentElapsedSeconds = 0; 

  @override
  void initState() {
    super.initState();
    final provider = context.read<RenormindProvider>();
    _planSeconds = widget.task.plannedMinutes * 60;

    // --- 核心保活逻辑 ---
    // 检查Provider里是否记录了这个任务正在跑
    if (provider.runningTaskId == widget.task.id && provider.taskStartTime != null) {
      // 如果是，恢复开始时间
      _startTime = provider.taskStartTime!;
    } else {
      // 如果不是，说明是新开的，设置开始时间并保存到Provider
      _startTime = DateTime.now();
      provider.setTaskTimerRunning(widget.task.id);
    }
    
    // 初始化显示
    _updateTime();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  void _updateTime() {
    // 永远计算：当前时间 - 开始时间
    final now = DateTime.now();
    final diff = now.difference(_startTime).inSeconds;
    
    if (mounted) {
      setState(() {
        _currentElapsedSeconds = diff;
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    int m = totalSeconds ~/ 60;
    int s = totalSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  void _finish() {
    // 清除Provider里的运行状态
    context.read<RenormindProvider>().clearTaskTimerRunning();
    Navigator.pop(context, _currentElapsedSeconds);
  }

  @override
  Widget build(BuildContext context) {
    int remaining = _planSeconds - _currentElapsedSeconds;
    bool isOvertime = remaining < 0;
    
    int displaySeconds = isOvertime ? -remaining : remaining;
    Color displayColor = isOvertime ? Colors.red : Colors.blue;
    String statusText = isOvertime ? "超时 (Overtime)" : "进行中 (Remaining)";

    return PopScope(
      // 拦截返回键，防止意外退出没保存状态（其实Provider已经保存了，这里是为了逻辑闭环）
      onPopInvokedWithResult: (didPop, result) {
         // 如果直接返回，倒计时其实还在后台"跑"（因为Provider里没清空）
         // 这种设计允许用户中途退出去看神圣座位，回来再继续
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  widget.task.name,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "计划时长: ${widget.task.plannedMinutes} 分钟",
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
              const Spacer(),
              
              Text(
                statusText,
                style: TextStyle(color: isOvertime ? Colors.redAccent : Colors.blueAccent, fontSize: 18, letterSpacing: 2),
              ),
              const SizedBox(height: 20),
              Text(
                (isOvertime ? "+" : "") + _formatTime(displaySeconds),
                style: TextStyle(
                  color: displayColor,
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              
              const Spacer(),
              
              Padding(
                padding: const EdgeInsets.all(40.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: isOvertime ? Colors.red : Colors.blue,
                    ),
                    onPressed: _finish, // 点击完成
                    child: const Text("完成打卡", style: TextStyle(fontSize: 20)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}