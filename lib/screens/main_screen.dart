import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/renormind_provider.dart';
import '../task_model.dart';
import 'ctdp_view.dart';
import 'sacred_seat_page.dart'; 
import 'settings_screen.dart'; // 引入设置页面

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  final List<Widget> _pages = const [
    CtdpView(),           // Index 0
    SacredSeatPage(),     // Index 1
    Center(               // Index 2 (统计)
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text("统计 (开发中)", style: TextStyle(fontSize: 24, color: Colors.grey)),
        ],
      )
    ),
    SettingsScreen(),     // Index 3 (替换了原来的占位符)
  ];

  // --- Actions ---

  void _onFabCTDP(BuildContext context, RenormindProvider provider) {
      final selectedTask = provider.selectedTask;
      String titleText = selectedTask != null 
          ? "添加子任务 (归属于: ${selectedTask.displayId})" 
          : "添加根目录任务";
      showDialog(context: context, builder: (ctx) => TaskDialog(title: titleText));
  }

  void _onEditCTDP(BuildContext context, RenormindProvider provider) {
    if (provider.selectedTask != null) {
      showDialog(context: context, builder: (ctx) => TaskDialog(title: "编辑任务", taskToEdit: provider.selectedTask));
    }
  }

  void _onDeleteCTDP(BuildContext context, RenormindProvider provider) {
     if (provider.selectedTask != null) {
       showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text("确认删除"), 
        content: Text("删除任务 ${provider.selectedTask!.displaySymbol}?"),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("取消")), 
          TextButton(onPressed: (){
            provider.deleteTask(provider.selectedTask!.id);
            Navigator.pop(ctx);
          }, child: const Text("删除", style: TextStyle(color: Colors.red)))
        ]
       ));
     }
  }

  @override
  Widget build(BuildContext context) {
    // 监听 Provider 中的 tabIndex
    final provider = context.watch<RenormindProvider>();
    final currentIndex = provider.currentTabIndex;
    final isSelected = provider.selectedTaskId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Renormind'),
        actions: [
          if (currentIndex == 0 && isSelected) ...[
             IconButton(
               icon: const Icon(Icons.delete_outline, color: Colors.red), 
               tooltip: "删除",
               onPressed: () => _onDeleteCTDP(context, provider)
             ),
             IconButton(
               icon: const Icon(Icons.edit), 
               tooltip: "编辑",
               onPressed: () => _onEditCTDP(context, provider)
             ),
             const SizedBox(width: 8),
          ]
        ],
      ),
      body: GestureDetector(
        onTap: () {
          if (currentIndex == 0) provider.clearSelection();
        },
        child: IndexedStack( 
          index: currentIndex,
          children: _pages,
        ),
      ),
      floatingActionButton: (currentIndex == 0) 
        ? FloatingActionButton(
            onPressed: () => _onFabCTDP(context, provider),
            child: Icon(isSelected ? Icons.subdirectory_arrow_right : Icons.add),
          ) 
        : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          // 调用 Provider 的方法来切换页面
          provider.setTabIndex(index);
          if (index != 0) provider.clearSelection();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'CTDP'),
          NavigationDestination(icon: Icon(Icons.event_seat), label: '神圣座位'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: '统计'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}

// ... TaskDialog 保持不变 ...
class TaskDialog extends StatefulWidget { 
  final String title; 
  final CtdpTask? taskToEdit; 
  const TaskDialog({super.key, required this.title, this.taskToEdit}); 
  @override State<TaskDialog> createState() => _TaskDialogState(); 
}

class _TaskDialogState extends State<TaskDialog> { 
  final _formKey = GlobalKey<FormState>(); 
  late final TextEditingController _nameController; 
  late final TextEditingController _durationController; 
  late final TextEditingController _descController; 
  
  @override void initState() { 
    super.initState(); 
    final t = widget.taskToEdit; 
    _nameController = TextEditingController(text: t?.name ?? ''); 
    String durationText = '';
    if (t != null && t.plannedMinutes > 0) {
      durationText = t.plannedMinutes.toString();
    }
    _durationController = TextEditingController(text: durationText); 
    _descController = TextEditingController(text: t?.description ?? ''); 
  } 
  
  @override void dispose() { 
    _nameController.dispose(); 
    _durationController.dispose(); 
    _descController.dispose(); 
    super.dispose(); 
  } 
  
  @override Widget build(BuildContext context) { 
    return AlertDialog(
      title: Text(widget.title), 
      scrollable: true, 
      content: Form(
        key: _formKey, 
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            TextFormField(
              controller: _nameController, 
              decoration: const InputDecoration(labelText: "任务名称"), 
              validator: (v) => v!.isEmpty ? "必填" : null
            ), 
            const SizedBox(height: 10), 
            TextFormField(
              controller: _durationController, 
              decoration: const InputDecoration(
                labelText: "计划时长 (可选)",
                hintText: "不填则为普通任务",
                suffixText: "min",
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v != null && v.isNotEmpty && int.tryParse(v) == null) {
                  return "请输入有效数字";
                }
                return null;
              },
            ), 
            const SizedBox(height: 10), 
            TextFormField(
              controller: _descController, 
              decoration: const InputDecoration(labelText: "任务描述"), 
              maxLines: 2
            )
          ]
        )
      ), 
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")), 
        FilledButton(onPressed: () { 
          if (_formKey.currentState!.validate()) { 
            final provider = Provider.of<RenormindProvider>(context, listen: false); 
            int mins = 0;
            if (_durationController.text.isNotEmpty) {
              mins = int.parse(_durationController.text);
            }
            if (widget.taskToEdit != null) { 
              provider.updateTask(
                widget.taskToEdit!.id, 
                name: _nameController.text, 
                plannedMinutes: mins, 
                description: _descController.text
              ); 
            } else { 
              provider.addTask(
                name: _nameController.text, 
                plannedMinutes: mins, 
                description: _descController.text
              ); 
            } 
            Navigator.pop(context); 
          } 
        }, child: Text(widget.taskToEdit != null ? "保存" : "添加"))
      ], 
    ); 
  } 
}