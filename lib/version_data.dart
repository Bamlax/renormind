class VersionItem {
  final String version;
  final String date;
  final List<String> changes;

  const VersionItem({
    required this.version,
    required this.date,
    required this.changes,
  });
}

// 在这里维护版本记录
const List<VersionItem> appVersionHistory = [
  VersionItem(
    version: "v0.2.0",
    date: "2025-12-11",
    changes: [
      "新增预约可以提前开始，计时可以取消的功能",
      "新增app图标",
      "修改了版本号说明",
      "修改CTDP界面任务编号",
      "修正CTDP未完成任务后的继续逻辑",
      "修复神圣座位和预约内容无法保存的问题",
      "优化联系开发者的界面ui",
    ],
  ),
  VersionItem(
    version: "v0.1.0",
    date: "2025-12-11",
    changes: [
      "Renormind 初始版本发布。",
      "核心功能：CTDP 任务管理 (支持无限层级、增删改查)。",
      "专注系统：神圣座位 (Sacred Seat) 面板，支持预约与任务绑定。",
      "智能计时：预约倒计时结束后，自动无缝切换至任务正计时。",
      "后台保活：基于时间戳计算，杀掉后台后倒计时依然准确。",
      "数据持久化：所有任务、计时状态、设置均本地保存。",
      "其他：新增设置界面与开发者联系方式。",
    ],
  ),
];