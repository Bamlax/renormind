import 'dart:convert'; // 必须引入，用于数据转换
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 必须引入，用于保存数据

// --- CTDP 数据模型 ---
class CtdpTask {
  final String id;
  final String? parentId;
  final String name;
  final int level; 
  final String sacredSeat;
  final String signal;
  final String duration;
  final String description;
  final DateTime createdAt;
  String displayId; 
  String displaySymbol;
  bool isDone;
  bool isFailed;

  CtdpTask({
    required this.id,
    this.parentId,
    required this.name,
    required this.level,
    this.sacredSeat = '',
    this.signal = '',
    this.duration = '',
    this.description = '',
    required this.createdAt,
    this.displayId = '',
    this.displaySymbol = '',
    this.isDone = false,
    this.isFailed = false,
  });

  // 1. 转为 JSON 保存
  Map<String, dynamic> toJson() => {
    'id': id,
    'parentId': parentId,
    'name': name,
    'level': level,
    'sacredSeat': sacredSeat,
    'signal': signal,
    'duration': duration,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'isDone': isDone,
    'isFailed': isFailed,
  };

  // 2. 从 JSON 恢复
  factory CtdpTask.fromJson(Map<String, dynamic> json) {
    return CtdpTask(
      id: json['id'],
      parentId: json['parentId'],
      name: json['name'],
      level: json['level'],
      sacredSeat: json['sacredSeat'] ?? '',
      signal: json['signal'] ?? '',
      duration: json['duration'] ?? '',
      description: json['description'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      isDone: json['isDone'] ?? false,
      isFailed: json['isFailed'] ?? false,
    );
  }
}

class RenormindProvider extends ChangeNotifier {
  List<CtdpTask> _rawTasks = [];
  List<CtdpTask> _displayTasks = [];
  String? _selectedTaskId;

  // 构造函数：一启动就读取数据
  RenormindProvider() {
    _loadFromStorage();
  }

  List<CtdpTask> get tasks => _displayTasks;
  String? get selectedTaskId => _selectedTaskId;

  CtdpTask? get selectedTask {
    if (_selectedTaskId == null) return null;
    try {
      return _rawTasks.firstWhere((t) => t.id == _selectedTaskId);
    } catch (e) {
      return null;
    }
  }

  // --- 核心：保存与读取 ---

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksJson = prefs.getString('ctdp_tasks');
    
    if (tasksJson != null) {
      // 如果手机里有数据，就恢复出来
      final List<dynamic> decodedList = jsonDecode(tasksJson);
      _rawTasks = decodedList.map((item) => CtdpTask.fromJson(item)).toList();
      _recalculateCtdpTree(); 
      notifyListeners();
    }
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    // 把数据转成字符串存进手机
    final String encodedList = jsonEncode(_rawTasks.map((t) => t.toJson()).toList());
    await prefs.setString('ctdp_tasks', encodedList);
  }

  // --- 业务操作 (每次改动都自动保存) ---

  void selectTask(String id) {
    _selectedTaskId = (_selectedTaskId == id) ? null : id;
    notifyListeners();
  }

  void clearSelection() {
    _selectedTaskId = null;
    notifyListeners();
  }

  void addTask({
    required String name,
    String sacredSeat = '',
    String signal = '',
    String duration = '',
    String description = '',
  }) {
    final parent = selectedTask;
    final int newLevel = (parent != null) ? parent.level + 1 : 1;
    final String? pId = parent?.id;

    final newTask = CtdpTask(
      id: DateTime.now().toIso8601String(),
      parentId: pId,
      name: name,
      level: newLevel,
      sacredSeat: sacredSeat,
      signal: signal,
      duration: duration,
      description: description,
      createdAt: DateTime.now(),
    );
    
    _rawTasks.add(newTask);
    _recalculateCtdpTree();
    _saveToStorage(); // 保存
    notifyListeners();
  }

  void updateTask(String id, {
    required String name,
    required String sacredSeat,
    required String signal,
    required String duration,
    required String description,
  }) {
    final index = _rawTasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final old = _rawTasks[index];
      _rawTasks[index] = CtdpTask(
        id: old.id,
        parentId: old.parentId,
        level: old.level,
        createdAt: old.createdAt,
        isDone: old.isDone,
        isFailed: old.isFailed,
        name: name,
        sacredSeat: sacredSeat,
        signal: signal,
        duration: duration,
        description: description,
      );
      _recalculateCtdpTree();
      _saveToStorage(); // 保存
      notifyListeners();
    }
  }

  void deleteTask(String id) {
    Set<String> idsToDelete = {};
    idsToDelete.add(id);

    void findChildren(String parentId) {
      final children = _rawTasks.where((t) => t.parentId == parentId);
      for (var child in children) {
        idsToDelete.add(child.id);
        findChildren(child.id); 
      }
    }
    findChildren(id);

    _rawTasks.removeWhere((t) => idsToDelete.contains(t.id));

    if (_selectedTaskId != null && idsToDelete.contains(_selectedTaskId)) {
      _selectedTaskId = null;
    }

    _recalculateCtdpTree();
    _saveToStorage(); // 保存
    notifyListeners();
  }

  void toggleDone(String id) {
    final index = _rawTasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final task = _rawTasks[index];
      if (task.isFailed) {
        _rawTasks[index].isFailed = false;
        _rawTasks[index].isDone = false;
      } else {
        _rawTasks[index].isDone = !task.isDone;
      }
      _saveToStorage(); // 保存
      notifyListeners();
    }
  }

  void toggleFailed(String id) {
    final index = _rawTasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      if (_rawTasks[index].isFailed) {
        _rawTasks[index].isFailed = false;
      } else {
        _rawTasks[index].isFailed = true;
        _rawTasks[index].isDone = false;
      }
      _saveToStorage(); // 保存
      notifyListeners();
    }
  }

  // --- 树形计算 (排序逻辑) ---
  void _recalculateCtdpTree() {
    List<CtdpTask> result = [];
    if (_rawTasks.isEmpty) {
      _displayTasks = [];
      return;
    }
    int maxLevel = _rawTasks.fold(0, (prev, curr) => curr.level > prev ? curr.level : prev);
    var roots = _rawTasks.where((t) => t.parentId == null).toList();
    roots.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    for (int i = roots.length - 1; i >= 0; i--) {
      _processCtdpNode(roots[i], "${i + 1}", maxLevel, result);
    }
    _displayTasks = result;
  }

  void _processCtdpNode(CtdpTask node, String localIndex, int globalMaxLevel, List<CtdpTask> result) {
    node.displayId = localIndex;
    int hashCount = globalMaxLevel - node.level + 1;
    if (hashCount < 1) hashCount = 1;
    node.displaySymbol = '#' * hashCount;
    result.add(node);
    var children = _rawTasks.where((t) => t.parentId == node.id).toList();
    children.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (int i = 0; i < children.length; i++) {
      _processCtdpNode(children[i], "${i + 1}", globalMaxLevel, result);
    }
  }
}