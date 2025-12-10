import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/renormind_provider.dart';

class CtdpView extends StatelessWidget {
  const CtdpView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RenormindProvider>(
      builder: (context, provider, child) {
        if (provider.tasks.isEmpty) {
          return const Center(child: Text("暂无 CTDP 任务，点击右上角添加"));
        }

        return ListView.builder(
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
                        Text(
                          "${task.displaySymbol} ${task.displayId} ${task.name}",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: textColor,
                            decoration: decoration,
                          ),
                        ),
                        if (task.sacredSeat.isNotEmpty || task.signal.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              "座位: ${task.sacredSeat} | 信号: ${task.signal} | 时长: ${task.duration}",
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
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
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => provider.toggleDone(task.id),
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
}