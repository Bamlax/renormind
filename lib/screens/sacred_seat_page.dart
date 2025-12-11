import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/renormind_provider.dart';

class SacredSeatPage extends StatefulWidget {
  const SacredSeatPage({super.key});

  @override
  State<SacredSeatPage> createState() => _SacredSeatPageState();
}

class _SacredSeatPageState extends State<SacredSeatPage> {
  late TextEditingController _seatController;
  late TextEditingController _reserveController;
  late TextEditingController _durationController;
  Timer? _ticker;
  String _displayTime = "00:00:00";
  bool _isOvertime = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<RenormindProvider>();
    _seatController = TextEditingController(text: provider.seatContent);
    _reserveController = TextEditingController(text: provider.reserveContent);
    _durationController = TextEditingController(
        text: provider.reserveDurationMinutes == 0 ? "" : provider.reserveDurationMinutes.toString());

    // 启动UI刷新定时器
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimerDisplay();
    });
    // 立即刷新一次
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTimerDisplay());
  }

  @override
  void dispose() {
    _seatController.dispose();
    _reserveController.dispose();
    _durationController.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  // 核心逻辑：基于 Provider 保存的 StartTime 计算当前显示
  void _updateTimerDisplay() {
    final provider = context.read<RenormindProvider>();
    if (!provider.isSeatTimerRunning || provider.seatStartTime == null) {
      if (mounted) setState(() => _displayTime = "准备开始");
      return;
    }

    final now = DateTime.now();
    final elapsedSeconds = now.difference(provider.seatStartTime!).inSeconds;
    final totalSeconds = provider.seatTotalSeconds;
    final remaining = totalSeconds - elapsedSeconds;

    bool overtime = remaining < 0;
    int showSeconds = overtime ? -remaining : remaining;

    String formatted = _formatTime(showSeconds);
    if (mounted) {
      setState(() {
        _isOvertime = overtime;
        _displayTime = (overtime ? "+" : "") + formatted;
      });
      
      // 简单提醒：如果刚好超时0秒 (实际可能跳过，这里做个简单视觉反馈，生产环境用LocalNotification)
      if (remaining == 0 || remaining == -1) {
         // 可以加入震动或声音
      }
    }
  }

  String _formatTime(int seconds) {
    int h = seconds ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  void _saveData(RenormindProvider provider) {
    int duration = int.tryParse(_durationController.text) ?? 0;
    provider.updateSeatData(_seatController.text, _reserveController.text, duration);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RenormindProvider>();
    final isRunning = provider.isSeatTimerRunning;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              // 神圣座位输入
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text("神圣座位", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextField(
                        controller: _seatController,
                        enabled: !isRunning,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: "在此输入神圣座位内容...",
                          border: InputBorder.none,
                        ),
                        onChanged: (_) => _saveData(provider),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // 预约设置
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text("预约事项", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextField(
                        controller: _reserveController,
                        enabled: !isRunning,
                        decoration: const InputDecoration(labelText: "预约内容"),
                        onChanged: (_) => _saveData(provider),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _durationController,
                              enabled: !isRunning,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "时长 (分钟)",
                                suffixText: "min",
                              ),
                              onChanged: (_) => _saveData(provider),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (!isRunning)
                          IconButton(
                            icon: const Icon(Icons.access_time),
                            onPressed: () async {
                              // 简单的 TimePicker 模拟，让用户选择分钟
                              final TimeOfDay? time = await showTimePicker(
                                context: context,
                                initialTime: const TimeOfDay(hour: 0, minute: 30),
                                helpText: "选择时长 (小时:分钟)",
                              );
                              if (time != null) {
                                int totalMins = time.hour * 60 + time.minute;
                                _durationController.text = totalMins.toString();
                                _saveData(provider);
                              }
                            },
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // 倒计时显示
              if (isRunning) ...[
                 Center(
                   child: Text(
                     _isOvertime ? "已超时" : "倒计时中",
                     style: TextStyle(
                       color: _isOvertime ? Colors.red : Colors.green,
                       fontSize: 20,
                       fontWeight: FontWeight.bold
                     ),
                   ),
                 ),
                 Center(
                   child: Text(
                     _displayTime,
                     style: TextStyle(
                       fontSize: 60,
                       fontWeight: FontWeight.bold,
                       color: _isOvertime ? Colors.red : Colors.blueAccent,
                       fontFeatures: const [FontFeature.tabularFigures()],
                     ),
                   ),
                 ),
              ],

              const SizedBox(height: 20),
              
              // 按钮
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: () {
                    if (isRunning) {
                      // 停止
                      provider.stopSeatTimer();
                    } else {
                      // 开始
                      _saveData(provider); // 再次保存确保最新
                      if (provider.reserveDurationMinutes <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请输入有效的时长")));
                        return;
                      }
                      provider.startSeatTimer();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: isRunning ? Colors.red : Colors.blue,
                  ),
                  icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
                  label: Text(isRunning ? "结束预约" : "开始预约", style: const TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}