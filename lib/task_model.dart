class CtdpTask {
  final String id;
  final String title; // 任务名称
  final String level; // #, ##, ### (层级)
  final String sacredSeat; // 神圣座位内容
  final String reserveSignal; // 预约信号
  final String reserveDuration; // 预约时长
  final String description; // 描述
  final DateTime timestamp; // 创建时间
  
  bool isCompleted; // 是否打钩
  bool isFailed; // 是否失败（被红色划掉）

  CtdpTask({
    required this.id,
    required this.title,
    required this.level,
    this.sacredSeat = '',
    this.reserveSignal = '',
    this.reserveDuration = '',
    this.description = '',
    required this.timestamp,
    this.isCompleted = false,
    this.isFailed = false,
  });
}