import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../task_model.dart'; 

class RenormindProvider extends ChangeNotifier {
  List<CtdpTask> _rawTasks = [];
  List<CtdpTask> _displayTasks = [];
  String? _selectedTaskId;

  // --- 神圣座位数据 ---
  String _seatContent = "";
  String _reserveContent = "";
  int _reserveDurationMinutes = 0;
  
  // 神圣座位计时状态
  DateTime? _seatStartTime;
  int _seatTotalSeconds = 0;
  bool _isSeatTimerRunning = false;

  // 任务计时状态 (用于恢复 Task Timer)
  String? _runningTaskId;
  DateTime? _taskStartTime;

  RenormindProvider() {
    _loadFromStorage();
  }

  // Getters
  List<CtdpTask> get tasks => _displayTasks;
  String? get selectedTaskId => _selectedTaskId;
  
  String get seatContent => _seatContent;
  String get reserveContent => _reserveContent;
  int get reserveDurationMinutes => _reserveDurationMinutes;
  bool get isSeatTimerRunning => _isSeatTimerRunning;
  DateTime? get seatStartTime => _seatStartTime;
  int get seatTotalSeconds => _seatTotalSeconds;

  // 获取当前正在后台运行的任务ID（如果有）
  String? get runningTaskId => _runningTaskId;
  DateTime? get taskStartTime => _taskStartTime;

  CtdpTask? get selectedTask {
    if (_selectedTaskId == null) return null;
    try {
      return _rawTasks.firstWhere((t) => t.id == _selectedTaskId);
    } catch (e) {
      return null;
    }
  }

  // --- 神圣座位逻辑 ---

  void updateSeatData(String seat, String reserve, int duration) {
    _seatContent = seat;
    _reserveContent = reserve;
    _reserveDurationMinutes = duration;
    _saveSeatData();
    notifyListeners();
  }

  void startSeatTimer() {
    _seatStartTime = DateTime.now();
    _seatTotalSeconds = _reserveDurationMinutes * 60;
    _isSeatTimerRunning = true;
    _saveSeatData();
    notifyListeners();
  }

  void stopSeatTimer() {
    _seatStartTime = null;
    _isSeatTimerRunning = false;
    _saveSeatData();
    notifyListeners();
  }

  // --- 任务计时器持久化逻辑 ---

  void setTaskTimerRunning(String taskId) {
    _runningTaskId = taskId;
    _taskStartTime = DateTime.now(); // 记录开始时间
    _saveTaskTimerState();
  }

  void clearTaskTimerRunning() {
    _runningTaskId = null;
    _taskStartTime = null;
    _saveTaskTimerState();
  }

  // --- 任务 CRUD ---

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
    required int plannedMinutes,
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
      plannedMinutes: plannedMinutes,
      actualSeconds: 0,
      description: description,
      createdAt: DateTime.now(),
    );
    
    _rawTasks.add(newTask);
    _recalculateCtdpTree();
    _saveToStorage();
    notifyListeners();
  }

  void updateTask(String id, {
    required String name,
    required int plannedMinutes,
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
        plannedMinutes: plannedMinutes,
        actualSeconds: old.actualSeconds,
        description: description,
      );
      _recalculateCtdpTree();
      _saveToStorage();
      notifyListeners();
    }
  }

  void completeTaskWithTime(String id, int usedSeconds) {
    final index = _rawTasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final old = _rawTasks[index];
      _rawTasks[index] = CtdpTask(
        id: old.id,
        parentId: old.parentId,
        level: old.level,
        createdAt: old.createdAt,
        name: old.name,
        description: old.description,
        plannedMinutes: old.plannedMinutes,
        isDone: true,
        isFailed: false,
        actualSeconds: usedSeconds,
      );
      
      _recalculateCtdpTree();
      _saveToStorage();
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
    _saveToStorage();
    notifyListeners();
  }

  void toggleDone(String id) {
    final index = _rawTasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final old = _rawTasks[index];
      bool newDoneState = old.isFailed ? false : !old.isDone;
      
      _rawTasks[index] = CtdpTask(
        id: old.id,
        parentId: old.parentId,
        level: old.level,
        createdAt: old.createdAt,
        name: old.name,
        description: old.description,
        plannedMinutes: old.plannedMinutes,
        actualSeconds: old.actualSeconds,
        isDone: newDoneState,
        isFailed: false,
      );

      _recalculateCtdpTree();
      _saveToStorage();
      notifyListeners();
    }
  }

  void toggleFailed(String id) {
    final index = _rawTasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final old = _rawTasks[index];
      bool newFailedState = !old.isFailed;

      _rawTasks[index] = CtdpTask(
        id: old.id,
        parentId: old.parentId,
        level: old.level,
        createdAt: old.createdAt,
        name: old.name,
        description: old.description,
        plannedMinutes: old.plannedMinutes,
        actualSeconds: old.actualSeconds,
        isDone: false,
        isFailed: newFailedState,
      );
      
      _recalculateCtdpTree();
      _saveToStorage();
      notifyListeners();
    }
  }

  // --- 持久化底层 ---

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Load Tasks
    final String? tasksJson = prefs.getString('ctdp_tasks');
    if (tasksJson != null) {
      final List<dynamic> decodedList = jsonDecode(tasksJson);
      _rawTasks = decodedList.map((item) => CtdpTask.fromJson(item)).toList();
      _recalculateCtdpTree(); 
    }

    // 2. Load Seat Data
    _seatContent = prefs.getString('seat_content') ?? "";
    _reserveContent = prefs.getString('reserve_content') ?? "";
    _reserveDurationMinutes = prefs.getInt('reserve_duration') ?? 0;
    
    // 3. Load Seat Timer State
    String? seatStartIso = prefs.getString('seat_start_time');
    if (seatStartIso != null && seatStartIso.isNotEmpty) {
      _seatStartTime = DateTime.parse(seatStartIso);
      _seatTotalSeconds = (prefs.getInt('seat_total_seconds') ?? 0);
      _isSeatTimerRunning = true;
    }

    // 4. Load Task Timer State
    _runningTaskId = prefs.getString('running_task_id');
    String? taskStartIso = prefs.getString('running_task_start_time');
    if (taskStartIso != null) {
      _taskStartTime = DateTime.parse(taskStartIso);
    }

    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedList = jsonEncode(_rawTasks.map((t) => t.toJson()).toList());
    await prefs.setString('ctdp_tasks', encodedList);
  }

  Future<void> _saveSeatData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('seat_content', _seatContent);
    await prefs.setString('reserve_content', _reserveContent);
    await prefs.setInt('reserve_duration', _reserveDurationMinutes);
    
    if (_seatStartTime != null) {
      await prefs.setString('seat_start_time', _seatStartTime!.toIso8601String());
      await prefs.setInt('seat_total_seconds', _seatTotalSeconds);
    } else {
      await prefs.remove('seat_start_time');
      await prefs.remove('seat_total_seconds');
    }
  }

  Future<void> _saveTaskTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    if (_runningTaskId != null && _taskStartTime != null) {
      await prefs.setString('running_task_id', _runningTaskId!);
      await prefs.setString('running_task_start_time', _taskStartTime!.toIso8601String());
    } else {
      await prefs.remove('running_task_id');
      await prefs.remove('running_task_start_time');
    }
  }

  void _recalculateCtdpTree() {
    List<CtdpTask> result = [];
    if (_rawTasks.isEmpty) {
      _displayTasks = [];
      return;
    }
    int maxLevel = _rawTasks.fold(0, (prev, curr) => curr.level > prev ? curr.level : prev);
    var roots = _rawTasks.where((t) => t.parentId == null).toList();
    roots.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    for (int i = 0; i < roots.length; i++) {
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
      String childIndex = "$localIndex.${i + 1}";
      _processCtdpNode(children[i], childIndex, globalMaxLevel, result);
    }
  }
}