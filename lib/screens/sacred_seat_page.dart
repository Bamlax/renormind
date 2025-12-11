import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/renormind_provider.dart';
import '../task_model.dart';

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
  
  String _timerLabel = "准备开始";
  String _displayTime = "00:00:00";
  Color _timerColor = Colors.blueAccent;
  bool _isTaskPhase = false; 

  @override
  void initState() {
    super.initState();
    final provider = context.read<RenormindProvider>();
    _seatController = TextEditingController(text: provider.seatContent);
    _reserveController = TextEditingController(text: provider.reserveContent);
    _durationController = TextEditingController(
        text: provider.reserveDurationMinutes == 0 ? "" : provider.reserveDurationMinutes.toString());

    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimerLogic();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTimerLogic());
  }

  @override
  void dispose() {
    _seatController.dispose();
    _reserveController.dispose();
    _durationController.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  void _updateTimerLogic() {
    final provider = context.read<RenormindProvider>();
    final sacredTask = provider.currentSacredTask;
    
    if (!provider.isSessionRunning || provider.sessionStartTime == null) {
      if (mounted && _timerLabel != "准备开始") {
        setState(() {
          _timerLabel = "准备开始";
          _displayTime = "00:00:00";
          _timerColor = Colors.grey;
          _isTaskPhase = false;
        });
      }
      return;
    }

    final now = DateTime.now();
    final startTime = provider.sessionStartTime!;
    final reserveDuration = Duration(minutes: provider.reserveDurationMinutes);
    // 预约结束时间点 = 任务开始时间点
    final taskStartTime = startTime.add(reserveDuration);

    if (now.isBefore(taskStartTime)) {
      // --- 阶段一：预约倒计时 ---
      final remaining = taskStartTime.difference(now).inSeconds;
      if (mounted) {
        setState(() {
          _timerLabel = "预约倒计时";
          _displayTime = _formatTime(remaining);
          _timerColor = Colors.blueAccent;
          _isTaskPhase = false;
        });
      }
    } else {
      // --- 阶段二：任务阶段 ---
      final elapsed = now.difference(taskStartTime).inSeconds;
      _isTaskPhase = true;
      
      // 判断显示模式：倒计时 vs 正计时
      int plannedSeconds = 0;
      if (sacredTask != null && sacredTask.plannedMinutes > 0) {
        plannedSeconds = sacredTask.plannedMinutes * 60;
      }

      if (plannedSeconds > 0) {
        // [有计划时间] -> 倒计时模式
        final remainingTaskTime = plannedSeconds - elapsed;
        bool isOvertime = remainingTaskTime < 0;
        int showSeconds = isOvertime ? -remainingTaskTime : remainingTaskTime;
        
        if (mounted) {
          setState(() {
            _timerLabel = isOvertime ? "任务超时 (正计时)" : "任务倒计时";
            _displayTime = (isOvertime ? "+" : "") + _formatTime(showSeconds);
            _timerColor = isOvertime ? Colors.red : Colors.blueAccent;
          });
        }
      } else {
        // [无计划时间] -> 正计时模式
        if (mounted) {
          setState(() {
            _timerLabel = "任务进行中 (正计时)";
            _displayTime = "+${_formatTime(elapsed)}";
            _timerColor = Colors.green;
          });
        }
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

  void _showTaskSelector(BuildContext context, RenormindProvider provider) {
    if (provider.isSessionRunning) return; 

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("选择当前要攻克的任务", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...provider.tasks.where((t) => !t.isDone).map((task) { 
              return ListTile(
                title: Text("${task.displaySymbol} ${task.name}"),
                subtitle: Text("计划: ${task.plannedMinutes}m | 已耗时: ${task.actualSeconds}s"),
                onTap: () {
                  provider.setSacredTask(task.id);
                  Navigator.pop(ctx);
                },
                trailing: provider.sacredTaskId == task.id ? const Icon(Icons.check, color: Colors.blue) : null,
              );
            }),
            if (provider.tasks.where((t) => !t.isDone).isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text("暂无未完成任务，请去CTDP添加", textAlign: TextAlign.center),
              )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RenormindProvider>();
    final isRunning = provider.isSessionRunning;
    final sacredTask = provider.currentSacredTask;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
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
                              final TimeOfDay? time = await showTimePicker(
                                context: context,
                                initialTime: const TimeOfDay(hour: 0, minute: 5),
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
              const SizedBox(height: 20),

              Card(
                elevation: isRunning ? 4 : 2,
                color: isRunning ? Colors.blue.withValues(alpha: 0.1) : null,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: isRunning ? Colors.blue : Colors.transparent, width: 2),
                  borderRadius: BorderRadius.circular(12)
                ),
                child: ListTile(
                  title: const Text("当前目标任务"),
                  subtitle: Text(
                    sacredTask != null ? "${sacredTask.displaySymbol} ${sacredTask.name}" : "点击选择任务...",
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold,
                      color: sacredTask != null ? Colors.black87 : Colors.grey
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_drop_down),
                  onTap: () => _showTaskSelector(context, provider),
                ),
              ),

              const SizedBox(height: 30),

              Center(
                child: Text(
                  _timerLabel,
                  style: TextStyle(
                    color: _timerColor,
                    fontSize: 18,
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
                    color: _timerColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              
              SizedBox(
                height: 50,
                child: isRunning 
                  ? FilledButton.icon(
                      onPressed: () {
                        if (_isTaskPhase) {
                           provider.finishSacredSession();
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("任务完成，时长已记录")));
                        } else {
                           provider.stopSacredSession();
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("预约已取消")));
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _isTaskPhase ? Colors.green : Colors.redAccent,
                      ),
                      icon: Icon(_isTaskPhase ? Icons.check : Icons.stop),
                      label: Text(_isTaskPhase ? "完成任务 (记录时间)" : "取消预约", style: const TextStyle(fontSize: 18)),
                    )
                  : FilledButton.icon(
                      onPressed: () {
                        _saveData(provider);
                        if (provider.reserveDurationMinutes <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请输入预约时长")));
                          return;
                        }
                        if (provider.sacredTaskId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请先选择一个任务")));
                          return;
                        }
                        provider.startSacredSession();
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text("开始预约", style: TextStyle(fontSize: 18)),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}