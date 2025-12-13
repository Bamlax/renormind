class CtdpTask {
  final String id;
  final String? parentId;
  final String name; 
  final int level;   
  final String description; 
  
  final int plannedMinutes; 
  final int actualSeconds;  

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
    this.description = '',
    this.plannedMinutes = 0, 
    this.actualSeconds = 0,  
    required this.createdAt,
    this.displayId = '',
    this.displaySymbol = '',
    this.isDone = false,
    this.isFailed = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'parentId': parentId,
    'name': name,
    'level': level,
    'description': description,
    'plannedMinutes': plannedMinutes,
    'actualSeconds': actualSeconds,
    'createdAt': createdAt.toIso8601String(),
    'isDone': isDone,
    'isFailed': isFailed,
  };

  factory CtdpTask.fromJson(Map<String, dynamic> json) {
    return CtdpTask(
      id: json['id'],
      parentId: json['parentId'],
      name: json['name'],
      level: json['level'],
      description: json['description'] ?? '',
      plannedMinutes: json['plannedMinutes'] ?? 0,
      actualSeconds: json['actualSeconds'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      isDone: json['isDone'] ?? false,
      isFailed: json['isFailed'] ?? false,
    );
  }
}

// --- 编号配置模型 (修改版) ---
class NumberingConfig {
  final int targetLevel; 
  bool failureReset;     
  int scopeLevel;        
  bool isUserModified; // 新增：标记用户是否手动修改过

  NumberingConfig({
    required this.targetLevel,
    required this.failureReset,
    required this.scopeLevel,
    this.isUserModified = false, // 默认为 false
  });

  Map<String, dynamic> toJson() => {
    'targetLevel': targetLevel,
    'failureReset': failureReset,
    'scopeLevel': scopeLevel,
    'isUserModified': isUserModified,
  };

  factory NumberingConfig.fromJson(Map<String, dynamic> json) {
    return NumberingConfig(
      targetLevel: json['targetLevel'],
      failureReset: json['failureReset'],
      scopeLevel: json['scopeLevel'],
      isUserModified: json['isUserModified'] ?? false,
    );
  }
}