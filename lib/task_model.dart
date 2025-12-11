class CtdpTask {
  final String id;
  final String? parentId;
  final String name; // 任务名称
  final int level;   // 层级
  final String description; // 描述
  
  final int plannedMinutes; // 计划时长 (分钟)
  final int actualSeconds;  // 实际耗时 (秒)

  final DateTime createdAt; // 创建时间
  
  // UI 状态字段
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