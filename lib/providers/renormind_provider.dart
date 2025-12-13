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
  String? _sacredTaskId; 
  DateTime? _sessionStartTime; 
  bool _isSessionRunning = false; 
  bool _isDataLoaded = false;

  // --- 编号配置 ---
  Map<int, NumberingConfig> _numberingConfigs = {};
  int _currentMaxLevel = 1; 

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
  
  Map<int, NumberingConfig> get numberingConfigs => _numberingConfigs;
  int get currentMaxLevel => _currentMaxLevel;

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

  // --- 编号配置逻辑 ---

  // 用户手动修改配置
  void updateNumberingConfig(int level, {bool? failureReset, int? scopeLevel}) {
    NumberingConfig oldConfig;
    if (_numberingConfigs.containsKey(level)) {
      oldConfig = _numberingConfigs[level]!;
    } else {
      // 防御性代码，理论上 recalculate 已经生成了
      oldConfig = NumberingConfig(targetLevel: level, failureReset: false, scopeLevel: level - 1);
    }

    _numberingConfigs[level] = NumberingConfig(
      targetLevel: level,
      failureReset: failureReset ?? oldConfig.failureReset,
      scopeLevel: scopeLevel ?? oldConfig.scopeLevel,
      isUserModified: true, // 关键：标记为用户已修改，以后自动逻辑将不再覆盖它
    );

    _saveNumberingConfigs();
    _recalculateCtdpTree(); 
    notifyListeners();
  }

  // 一键恢复默认 (清空用户修改标记)
  void resetAllConfigsToDefault() {
    _numberingConfigs.updateAll((key, val) {
      return NumberingConfig(
        targetLevel: val.targetLevel,
        failureReset: val.failureReset, // 值稍后会被 recalculate 覆盖
        scopeLevel: val.scopeLevel,
        isUserModified: false, // 关键：重置标记
      );
    });
    
    // 立即重新计算以应用默认规则
    _recalculateCtdpTree();
    _saveNumberingConfigs();
    notifyListeners();
  }

  // 智能应用默认规则
  // 此方法在 _recalculateCtdpTree 中被调用，基于当前的 maxLevel
  void _applyDynamicDefaults(int maxLevel) {
    bool changed = false;

    for (int i = 1; i <= maxLevel; i++) {
      // 获取现有配置，如果没有则创建
      NumberingConfig config = _numberingConfigs[i] ?? NumberingConfig(
        targetLevel: i, 
        failureReset: false, 
        scopeLevel: 0,
        isUserModified: false 
      );

      // 如果用户没有手动修改过，强制应用默认规则
      if (!config.isUserModified) {
        // 规则1: 只有底层 (#) 开启重置
        bool isLeaf = (i == maxLevel);
        
        // 规则2: 根层级 Scope 为全局(0)，其他层级 Scope 为父级(i-1)
        int defaultScope = (i == 1) ? 0 : i - 1;

        // 检查是否有变化，有变化才更新
        if (config.failureReset != isLeaf || config.scopeLevel != defaultScope) {
          _numberingConfigs[i] = NumberingConfig(
            targetLevel: i,
            failureReset: isLeaf,
            scopeLevel: defaultScope,
            isUserModified: false, // 保持未修改状态
          );
          changed = true;
        } else if (!_numberingConfigs.containsKey(i)) {
          // 如果是新创建的层级
          _numberingConfigs[i] = config;
          changed = true;
        }
      } 
      // 如果 isUserModified == true，我们完全不碰它
    }

    if (changed) {
      _saveNumberingConfigs();
    }
  }

  // --- 导航 & 业务逻辑 ---
  void setTabIndex(int index) { _currentTabIndex = index; notifyListeners(); }
  
  void jumpToSacredSeat(CtdpTask task) {
    if (_isSessionRunning) { _currentTabIndex = 1; notifyListeners(); return; }
    _sacredTaskId = task.id;
    _reserveDurationMinutes = 5; 
    _currentTabIndex = 1; 
    _saveSeatData();
    notifyListeners();
  }

  void startDirectTaskSession(CtdpTask task) {
    if (_isSessionRunning) { _currentTabIndex = 1; notifyListeners(); return; }
    _sacredTaskId = task.id;
    _reserveDurationMinutes = 0;
    _sessionStartTime = DateTime.now();
    _isSessionRunning = true;
    _currentTabIndex = 1;
    _saveSeatData();
    notifyListeners();
  }

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

  void skipReservation() {
    if (!_isSessionRunning) return;
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

  void stopSacredSession() {
    _sessionStartTime = null;
    _isSessionRunning = false;
    _saveSeatData();
    notifyListeners();
  }

  // --- CRUD ---
  void selectTask(String id) { _selectedTaskId = (_selectedTaskId == id) ? null : id; notifyListeners(); }
  void clearSelection() { _selectedTaskId = null; notifyListeners(); }

  void addTask({required String name, required int plannedMinutes, String description = ''}) {
    final parent = selectedTask;
    final int newLevel = (parent != null) ? parent.level + 1 : 1;
    final String? pId = parent?.id;
    final newTask = CtdpTask(
      id: DateTime.now().toIso8601String(),
      parentId: pId, name: name, level: newLevel, plannedMinutes: plannedMinutes,
      actualSeconds: 0, description: description, createdAt: DateTime.now(),
    );
    _rawTasks.add(newTask);
    _recalculateCtdpTree();
    _saveToStorage();
    notifyListeners();
  }

  void addSuperRoot({required String name, required int plannedMinutes, String description = ''}) {
    final newRootId = DateTime.now().toIso8601String();
    
    // 配置迁移：因为层级物理移动了，配置也要跟着移动
    // 这里依然需要迁移，因为这是结构性变化，用户的修改意图是针对"那层任务"的
    Map<int, NumberingConfig> newConfigs = {};
    _numberingConfigs.forEach((level, config) {
      int newLevel = level + 1;
      int newScope = (config.scopeLevel == 0) ? 1 : config.scopeLevel + 1;
      newConfigs[newLevel] = NumberingConfig(
        targetLevel: newLevel,
        failureReset: config.failureReset,
        scopeLevel: newScope,
        isUserModified: config.isUserModified, // 保留用户的修改标记
      );
    });
    // 新的 Level 1 是全新的，肯定是默认状态
    newConfigs[1] = NumberingConfig(targetLevel: 1, failureReset: false, scopeLevel: 0, isUserModified: false);

    _numberingConfigs = newConfigs;
    _saveNumberingConfigs();

    final newRoot = CtdpTask(id: newRootId, parentId: null, name: name, level: 1, plannedMinutes: plannedMinutes, actualSeconds: 0, description: description, createdAt: DateTime.now());

    for (int i = 0; i < _rawTasks.length; i++) {
      final task = _rawTasks[i];
      String? newParentId = task.parentId;
      if (task.parentId == null) newParentId = newRootId;
      _rawTasks[i] = CtdpTask(id: task.id, parentId: newParentId, name: task.name, level: task.level + 1, plannedMinutes: task.plannedMinutes, actualSeconds: task.actualSeconds, description: task.description, createdAt: task.createdAt, isDone: task.isDone, isFailed: task.isFailed);
    }
    _rawTasks.add(newRoot);

    _recalculateCtdpTree();
    _saveToStorage();
    notifyListeners();
  }

  void updateTask(String id, {required String name, required int plannedMinutes, required String description}) {
    final index = _rawTasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final old = _rawTasks[index];
      _rawTasks[index] = CtdpTask(id: old.id, parentId: old.parentId, level: old.level, createdAt: old.createdAt, isDone: old.isDone, isFailed: old.isFailed, name: name, plannedMinutes: plannedMinutes, actualSeconds: old.actualSeconds, description: description);
      _recalculateCtdpTree(); _saveToStorage(); notifyListeners();
    }
  }

  void completeTaskWithTime(String id, int newSeconds) {
    final index = _rawTasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final old = _rawTasks[index];
      _rawTasks[index] = CtdpTask(id: old.id, parentId: old.parentId, level: old.level, createdAt: old.createdAt, name: old.name, description: old.description, plannedMinutes: old.plannedMinutes, isDone: true, isFailed: false, actualSeconds: old.actualSeconds + newSeconds);
      _recalculateCtdpTree(); _saveToStorage(); notifyListeners();
    }
  }

  void deleteTask(String id) {
    Set<String> idsToDelete = {}; idsToDelete.add(id);
    void findChildren(String parentId) {
      final children = _rawTasks.where((t) => t.parentId == parentId);
      for (var child in children) { idsToDelete.add(child.id); findChildren(child.id); }
    }
    findChildren(id);
    _rawTasks.removeWhere((t) => idsToDelete.contains(t.id));
    if (_sacredTaskId != null && idsToDelete.contains(_sacredTaskId)) { _sacredTaskId = null; if (_isSessionRunning) stopSacredSession(); }
    if (_selectedTaskId != null && idsToDelete.contains(_selectedTaskId)) { _selectedTaskId = null; }
    
    _recalculateCtdpTree(); 
    _saveToStorage(); 
    notifyListeners();
  }

  void toggleDone(String id) {
    final index = _rawTasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final old = _rawTasks[index];
      bool newDoneState = old.isFailed ? false : !old.isDone;
      _rawTasks[index] = CtdpTask(id: old.id, parentId: old.parentId, level: old.level, createdAt: old.createdAt, name: old.name, description: old.description, plannedMinutes: old.plannedMinutes, actualSeconds: old.actualSeconds, isDone: newDoneState, isFailed: false);
      _recalculateCtdpTree(); _saveToStorage(); notifyListeners();
    }
  }

  void toggleFailed(String id) {
    final index = _rawTasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final old = _rawTasks[index];
      bool newFailedState = !old.isFailed;
      _rawTasks[index] = CtdpTask(id: old.id, parentId: old.parentId, level: old.level, createdAt: old.createdAt, name: old.name, description: old.description, plannedMinutes: old.plannedMinutes, actualSeconds: old.actualSeconds, isDone: false, isFailed: newFailedState);
      _recalculateCtdpTree(); _saveToStorage(); notifyListeners();
    }
  }

  // --- 持久化底层 ---

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    
    final String? configsJson = prefs.getString('numbering_configs');
    if (configsJson != null) {
      Map<String, dynamic> decoded = jsonDecode(configsJson);
      _numberingConfigs = decoded.map((key, value) => MapEntry(int.parse(key), NumberingConfig.fromJson(value)));
    }

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
    if (_sacredTaskId != null) { await prefs.setString('sacred_task_id', _sacredTaskId!); } else { await prefs.remove('sacred_task_id'); }
    if (_sessionStartTime != null && _isSessionRunning) { await prefs.setString('session_start_time', _sessionStartTime!.toIso8601String()); } else { await prefs.remove('session_start_time'); }
  }

  Future<void> _saveNumberingConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _numberingConfigs.map((key, value) => MapEntry(key.toString(), value.toJson()));
    await prefs.setString('numbering_configs', jsonEncode(encoded));
  }

  // --- 核心：高级树形计算与计数器逻辑 ---

  void _recalculateCtdpTree() {
    List<CtdpTask> result = [];
    if (_rawTasks.isEmpty) {
      _displayTasks = [];
      return;
    }
    
    // 1. 计算最大层级
    int maxLevel = _rawTasks.fold(0, (prev, curr) => curr.level > prev ? curr.level : prev);
    _currentMaxLevel = maxLevel;
    
    // 2. 关键：应用智能默认规则 (在计算树之前应用配置更新)
    _applyDynamicDefaults(maxLevel);

    var roots = _rawTasks.where((t) => t.parentId == null).toList();
    roots.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    Map<String, Map<String, dynamic>> contextCounters = {};

    for (var root in roots) {
      Map<int, String> ancestorIds = {0: "root"}; 
      _processAdvancedNode(root, maxLevel, ancestorIds, contextCounters, result);
    }
    
    _displayTasks = result;
  }

  void _processAdvancedNode(
    CtdpTask node, 
    int globalMaxLevel, 
    Map<int, String> ancestorIds, 
    Map<String, Map<String, dynamic>> contextCounters,
    List<CtdpTask> result
  ) {
    Map<int, String> currentIds = Map.from(ancestorIds);
    currentIds[node.level] = node.id; 

    // 防御性获取，理论上 _applyDynamicDefaults 已经保证了所有 level 都有配置
    final config = _numberingConfigs[node.level] ?? NumberingConfig(targetLevel: node.level, failureReset: false, scopeLevel: 0);
    
    String scopeId = "root";
    if (config.scopeLevel > 0) {
      scopeId = currentIds[config.scopeLevel] ?? "root"; 
    } else {
      scopeId = "root"; 
    }

    String counterKey = "${node.level}_$scopeId";

    if (!contextCounters.containsKey(counterKey)) {
      contextCounters[counterKey] = {'count': 0, 'lastFailed': false};
    }
    
    var counterData = contextCounters[counterKey]!;
    
    if (counterData['lastFailed'] == true && config.failureReset) {
      counterData['count'] = 1;
    } else {
      counterData['count'] = (counterData['count'] as int) + 1;
    }
    
    counterData['lastFailed'] = node.isFailed;

    node.displayId = counterData['count'].toString();
    int hashCount = globalMaxLevel - node.level + 1;
    if (hashCount < 1) hashCount = 1;
    node.displaySymbol = '#' * hashCount;
    result.add(node);

    var children = _rawTasks.where((t) => t.parentId == node.id).toList();
    children.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    for (var child in children) {
      _processAdvancedNode(child, globalMaxLevel, currentIds, contextCounters, result);
    }
  }
}