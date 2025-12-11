import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/renormind_provider.dart';
import '../task_model.dart'; 

class CtdpView extends StatefulWidget {
  const CtdpView({super.key});

  @override
  State<CtdpView> createState() => _CtdpViewState();
}

class _CtdpViewState extends State<CtdpView> {
  final ScrollController _scrollController = ScrollController();
  bool _needsScrollToBottom = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RenormindProvider>(
      builder: (context, provider, child) {
        if (provider.tasks.isEmpty) {
          return const Center(child: Text("暂无 CTDP 任务，点击右上角添加"));
        }

        if (_needsScrollToBottom && provider.tasks.isNotEmpty) {
          _scrollToBottom();
          _needsScrollToBottom = false;
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: provider.tasks.length,
          itemBuilder: (context, index) {
            final task = provider.tasks[index];
            return _buildTaskCard(context, provider, task);
          },
        );
      },
    );
  }

  Widget _buildTaskCard(BuildContext context, RenormindProvider provider, CtdpTask task) {
    final isSelected = task.id == provider.selectedTaskId;
    final isSacred = task.id == provider.sacredTaskId; 
    final isFailed = task.isFailed;
    final isDone = task.isDone;

    Color textColor = isFailed ? Colors.red : (isDone ? Colors.grey : Colors.black87);
    TextDecoration decoration = isFailed ? TextDecoration.lineThrough : TextDecoration.none;
    
    Color cardColor = isSelected 
        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3) 
        : Colors.white;
    Color borderColor = isSelected 
        ? Theme.of(context).colorScheme.primary 
        : (isFailed ? Colors.red : Colors.transparent);
    
    if (isSacred && provider.isSessionRunning) {
      borderColor = Colors.orange;
      cardColor = Colors.orange.withValues(alpha: 0.05);
    }

    double indent = 10 + (task.level - 1) * 20.0;

    return GestureDetector(
      onTap: () {
        provider.selectTask(task.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: EdgeInsets.only(
          left: indent,
          right: 10,
          top: 4,
          bottom: 4
        ),
        decoration: BoxDecoration(
          color: isFailed ? Colors.red.withValues(alpha: 0.05) : cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isSelected || (isSacred && provider.isSessionRunning) ? 2.0 : 1.0,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${task.displaySymbol} ${task.displayId} ${task.name}",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: textColor,
                            decoration: decoration,
                          ),
                        ),
                        if (task.plannedMinutes > 0 || task.actualSeconds > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: _buildTimeInfo(task),
                          ),
                        if (task.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              task.description,
                              style: TextStyle(
                                fontSize: 13, 
                                color: Colors.grey[700],
                                fontStyle: FontStyle.italic
                              ),
                            ),
                          ),
                        if (isSacred && provider.isSessionRunning)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              "🔥 正在神圣座位中进行...",
                              style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                            ),
                          )
                      ],
                    ),
                  ),
                  
                  // 右侧打卡按钮
                  InkWell(
                    onTap: () {
                      if (task.isDone || task.isFailed) {
                        provider.toggleDone(task.id);
                      } else {
                        // --- 逻辑分支 ---
                        if (task.plannedMinutes > 0) {
                          // [有计划时间] -> 跳转并开始倒计时
                          if (provider.isSessionRunning) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text("已有任务正在进行，请先完成或取消当前预约"))
                             );
                             provider.setTabIndex(1);
                          } else {
                             provider.startDirectTaskSession(task);
                          }
                        } else {
                          // [无计划时间] -> 直接完成
                          provider.toggleDone(task.id);
                        }
                      }
                    },
                    onLongPress: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("标记为未完成？"),
                          content: const Text("这将把此任务标记为失败（红色叉号）。"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text("取消"),
                            ),
                            TextButton(
                              onPressed: () {
                                provider.toggleFailed(task.id);
                                Navigator.pop(ctx);
                              },
                              child: const Text(
                                "确认失败",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isFailed ? Colors.red : Colors.grey,
                          width: 2,
                        ),
                        color: isDone ? Colors.green : Colors.transparent,
                      ),
                      child: isDone
                          ? const Icon(Icons.check, size: 20, color: Colors.white)
                          : (isFailed ? const Icon(Icons.close, size: 20, color: Colors.red) : null),
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeInfo(CtdpTask task) {
    String text = "";
    Color color = Colors.blueGrey;

    if (task.plannedMinutes > 0) {
      text = "计划: ${task.plannedMinutes}m";
    }

    if (task.actualSeconds > 0) {
      int actualMins = task.actualSeconds ~/ 60; 
      int actualSecs = task.actualSeconds % 60;  
      
      String percentStr = "";
      if (task.plannedMinutes > 0) {
        int plannedSeconds = task.plannedMinutes * 60;
        double diff = (task.actualSeconds - plannedSeconds) / plannedSeconds * 100;
        String sign = diff > 0 ? "+" : "";
        percentStr = " ($sign${diff.toStringAsFixed(2)}%)";
        if (diff > 10) color = Colors.red;
        else if (diff < -10) color = Colors.green;
        else color = Colors.black87;
      }
      
      if (text.isNotEmpty) text += " | ";
      text += "实际: ${actualMins}m ${actualSecs}s$percentStr";
    }

    return Text(
      text,
      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
    );
  }
}