import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/renormind_provider.dart';

class NumberingScreen extends StatelessWidget {
  const NumberingScreen({super.key});

  String _getHashString(int level, int maxLevel) {
    int count = maxLevel - level + 1;
    if (count < 1) count = 1;
    return "#" * count;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RenormindProvider>();
    final maxLevel = provider.currentMaxLevel;
    final configs = provider.numberingConfigs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('编号规则 (#)'),
        actions: [
          // 恢复默认按钮
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: "恢复默认规则",
            onPressed: () {
              showDialog(
                context: context, 
                builder: (ctx) => AlertDialog(
                  title: const Text("恢复默认"),
                  content: const Text("确定要清除所有手动修改，恢复到【#开启重置，其他关闭】的默认规则吗？"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
                    TextButton(
                      onPressed: () {
                        provider.resetAllConfigsToDefault();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已恢复默认规则")));
                      },
                      child: const Text("确认"),
                    ),
                  ],
                )
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.grey[200],
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text("层级", style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text("连续性", style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text("失败重置", style: TextStyle(fontWeight: FontWeight.bold)))),
              ],
            ),
          ),

          Expanded(
            child: ListView.separated(
              itemCount: maxLevel,
              separatorBuilder: (ctx, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                int level = index + 1;
                final config = configs[level];
                if (config == null) return const SizedBox();

                String levelSymbol = _getHashString(level, maxLevel);
                
                // 给用户修改过的行加一点视觉提示（比如背景微微变色），可选
                // Color? bgColor = config.isUserModified ? Colors.blue.withValues(alpha: 0.05) : null;

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  constraints: const BoxConstraints(minHeight: 56),
                  // color: bgColor,
                  child: Row(
                    children: [
                      // 1. 层级
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Text(
                              levelSymbol, 
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                            ),
                            if (config.isUserModified) // 小圆点提示已修改
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
                              )
                          ],
                        ),
                      ),

                      // 2. 连续性
                      Expanded(
                        flex: 3,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: config.scopeLevel,
                            isDense: true,
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem(value: 0, child: Text("全局")),
                              for (int i = 1; i < level; i++)
                                DropdownMenuItem(
                                  value: i, 
                                  child: Text(_getHashString(i, maxLevel))
                                ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                provider.updateNumberingConfig(level, scopeLevel: val);
                              }
                            },
                          ),
                        ),
                      ),

                      // 3. 失败重置
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: config.failureReset,
                              onChanged: (val) {
                                provider.updateNumberingConfig(level, failureReset: val);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}