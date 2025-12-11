import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/renormind_provider.dart';
import '../task_model.dart'; 
import 'timer_screen.dart'; 

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
            width: isSelected ? 2.0 : 1.0,
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
                        // 第一行：标题
                        Text(
                          "${task.displaySymbol} ${task.displayId} ${task.name}",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: textColor,
                            decoration: decoration,
                          ),
                        ),
                        
                        // 第二行：时间统计 (如果计划时长为0则不显示)
                        if (task.plannedMinutes > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: _buildTimeInfo(task),
                          ),

                        // 第三行：描述
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
                      ],
                    ),
                  ),
                  
                  // 右侧打卡按钮
                  InkWell(
                    onTap: () async {
                      if (task.isDone || task.isFailed) {
                        // 如果已经完成或失败，点击则反转状态
                        provider.toggleDone(task.id);
                      } else {
                        // --- 修改点开始：判断是否需要倒计时 ---
                        if (task.plannedMinutes > 0) {
                          // 有计划时间 -> 跳转计时器
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => TimerScreen(task: task)),
                          );
                          
                          if (result != null && result is int) {
                            provider.completeTaskWithTime(task.id, result);
                          }
                        } else {
                          // 无计划时间 -> 直接打卡成功
                          provider.toggleDone(task.id);
                        }
                        // --- 修改点结束 ---
                      }
                    },
                    onLongPress: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("标记为未完成？"),
                          content: const Text("这将把此任务标记为失败（红色叉号），且不记录时间。"),
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

  // 构建时间信息组件
  Widget _buildTimeInfo(CtdpTask task) {
    String text = "计划: ${task.plannedMinutes}m";
    Color color = Colors.blueGrey;

    if (task.isDone) {
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

      text += " | 实际: ${actualMins}m ${actualSecs}s$percentStr";
    }

    return Text(
      text,
      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
    );
  }
}