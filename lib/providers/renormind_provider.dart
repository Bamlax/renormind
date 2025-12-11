import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../task_model.dart'; 

class RenormindProvider extends ChangeNotifier {
  List<CtdpTask> _rawTasks = [];
  List<CtdpTask> _displayTasks = [];
  String? _selectedTaskId;

  // --- 页面导航控制 ---
  int _currentTabIndex = 0; 

  // --- 神圣座位 & 任务联动数据 ---
  String _seatContent = "";
  String _reserveContent = "";
  int _reserveDurationMinutes = 0;
  
  // 核心状态控制
  String? _sacredTaskId; 
  DateTime? _sessionStartTime; 
  bool _isSessionRunning = false; 
  
  bool _isDataLoaded = false;

  RenormindProvider() {
    _loadFromStorage();
  }

  // Getters
  List<CtdpTask> get tasks => _displayTasks;
  String? get selectedTaskId => _selectedTaskId;
  int get currentTabIndex => _currentTabIndex; 
  
  String get seatContent => _seatContent;
  String get reserveContent => _reserveContent;
  int get reserveDurationMinutes => _reserveDurationMinutes;
  
  bool get isSessionRunning => _isSessionRunning;
  DateTime? get sessionStartTime => _sessionStartTime;
  String? get sacredTaskId => _sacredTaskId;
  bool get isDataLoaded => _isDataLoaded;

  CtdpTask? get selectedTask {
    if (_selectedTaskId == null) return null;
    try {
      return _rawTasks.firstWhere((t) => t.id == _selectedTaskId);
    } catch (e) {
      return null;
    }
  }

  CtdpTask? get currentSacredTask {
    if (_sacredTaskId == null) return null;
    try {
      return _rawTasks.firstWhere((t) => t.id == _sacredTaskId);
    } catch (e) {
      return null;
    }
  }

  // --- 页面导航逻辑 ---
  
  void setTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  void jumpToSacredSeat(CtdpTask task) {
    if (_isSessionRunning) {
      _currentTabIndex = 1; 
      notifyListeners();
      return;
    }
    _sacredTaskId = task.id;
    _reserveDurationMinutes = 5; 
    
    _currentTabIndex = 1; 
    _saveSeatData();
    notifyListeners();
  }

  void startDirectTaskSession(CtdpTask task) {
    if (_isSessionRunning) {
      _currentTabIndex = 1;
      notifyListeners();
      return;
    }

    _sacredTaskId = task.id;
    _reserveDurationMinutes = 0;
    _sessionStartTime = DateTime.now();
    _isSessionRunning = true;
    _currentTabIndex = 1;

    _saveSeatData();
    notifyListeners();
  }

  // --- 神圣座位逻辑 ---

  void updateSeatData(String seat, String reserve, int duration) {
    _seatContent = seat;
    _reserveContent = reserve;
    _reserveDurationMinutes = duration;
    _saveSeatData(); 
  }

  void setSacredTask(String? taskId) {
    if (_isSessionRunning) return; 
    _sacredTaskId = taskId;
    _saveSeatData();
    notifyListeners();
  }

  void startSacredSession() {
    if (_sacredTaskId == null) return;
    _sessionStartTime = DateTime.now();
    _isSessionRunning = true;
    _saveSeatData();
    notifyListeners();
  }

  // 新增：跳过预约，直接开始任务
  void skipReservation() {
    if (!_isSessionRunning) return;
    
    // 原理：将预约时长设为0，并将开始时间重置为现在
    // 这样 UI 逻辑会判断 now >= start + 0，从而进入任务阶段
    _reserveDurationMinutes = 0;
    _sessionStartTime = DateTime.now();
    
    _saveSeatData();
    notifyListeners();
  }

  void finishSacredSession() {
    if (_sessionStartTime != null && _sacredTaskId != null) {
      DateTime taskStartTime = _sessionStartTime!.add(Duration(minutes: _reserveDurationMinutes));
      DateTime now = DateTime.now();

      int taskDurationSeconds = 0;
      if (now.isAfter(taskStartTime)) {
        taskDurationSeconds = now.difference(taskStartTime).inSeconds;
      }
      
      completeTaskWithTime(_sacredTaskId!, taskDurationSeconds);
    }

    _sessionStartTime = null;
    _isSessionRunning = false;
    _saveSeatData();
    notifyListeners();
  }

  // 停止（取消），不保存时间
  void stopSacredSession() {
    _sessionStartTime = null;
    _isSessionRunning = false;
    _saveSeatData();
    notifyListeners();
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

  void completeTaskWithTime(String id, int newSeconds) {
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
        actualSeconds: old.actualSeconds + newSeconds, 
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
    
    if (_sacredTaskId != null && idsToDelete.contains(_sacredTaskId)) {
      _sacredTaskId = null;
      if (_isSessionRunning) stopSacredSession();
    }

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

  // --- 持久化 ---

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    
    final String? tasksJson = prefs.getString('ctdp_tasks');
    if (tasksJson != null) {
      final List<dynamic> decodedList = jsonDecode(tasksJson);
      _rawTasks = decodedList.map((item) => CtdpTask.fromJson(item)).toList();
      _recalculateCtdpTree(); 
    }

    _seatContent = prefs.getString('seat_content') ?? "";
    _reserveContent = prefs.getString('reserve_content') ?? "";
    _reserveDurationMinutes = prefs.getInt('reserve_duration') ?? 0;
    _sacredTaskId = prefs.getString('sacred_task_id');
    
    String? sessionStartIso = prefs.getString('session_start_time');
    if (sessionStartIso != null && sessionStartIso.isNotEmpty) {
      _sessionStartTime = DateTime.parse(sessionStartIso);
      _isSessionRunning = true;
    }

    _isDataLoaded = true;
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
    
    if (_sacredTaskId != null) {
      await prefs.setString('sacred_task_id', _sacredTaskId!);
    } else {
      await prefs.remove('sacred_task_id');
    }
    
    if (_sessionStartTime != null && _isSessionRunning) {
      await prefs.setString('session_start_time', _sessionStartTime!.toIso8601String());
    } else {
      await prefs.remove('session_start_time');
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
    
    int counter = 0;
    for (int i = 0; i < roots.length; i++) {
      counter++;
      String indexStr = "$counter";
      _processCtdpNode(roots[i], indexStr, maxLevel, result);
      if (roots[i].isFailed) {
        counter = 0;
      }
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
    
    int childCounter = 0;
    for (int i = 0; i < children.length; i++) {
      childCounter++;
      String childIndexStr = "$childCounter"; 
      _processCtdpNode(children[i], childIndexStr, globalMaxLevel, result);
      if (children[i].isFailed) {
        childCounter = 0;
      }
    }
  }
}