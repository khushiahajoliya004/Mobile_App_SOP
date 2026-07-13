class TimesheetEntry {
  final String id;
  final String date;
  final String projectId;
  final String projectTaskId;
  final String projectSubtaskId;
  final String userId;
  final String companyId;
  final double hours;
  final String narration;
  final String? projectName;
  final String? taskName;
  final String? subtaskName;
  final String? userName;
  final String? techRoleName;

  TimesheetEntry({
    required this.id,
    required this.date,
    required this.projectId,
    required this.projectTaskId,
    required this.projectSubtaskId,
    required this.userId,
    required this.companyId,
    required this.hours,
    required this.narration,
    this.projectName,
    this.taskName,
    this.subtaskName,
    this.userName,
    this.techRoleName,
  });

  factory TimesheetEntry.fromJson(Map<String, dynamic> j) => TimesheetEntry(
    id: j['id'] ?? '',
    date: j['date'] ?? '',
    projectId: j['projectId'] ?? '',
    projectTaskId: j['projectTaskId'] ?? '',
    projectSubtaskId: j['projectSubtaskId'] ?? '',
    userId: j['userId'] ?? '',
    companyId: j['companyId'] ?? '',
    hours: double.tryParse(j['hours']?.toString() ?? '0') ?? 0.0,
    narration: j['narration'] ?? '',
    projectName: j['projectName'] ?? j['project']?['name'],
    taskName: j['taskName'] ?? j['projectTask']?['name'],
    subtaskName: j['subtaskName'] ?? j['projectSubtask']?['name'],
    userName:
        j['userName'] ??
        (j['user']?['firstName'] != null
            ? '${j['user']['firstName']} ${j['user']['lastName'] ?? ''}'.trim()
            : null),
    techRoleName: j['techRoleName'],
  );
}

class HourRange {
  final double minHours;
  final double maxHours;

  HourRange({required this.minHours, required this.maxHours});

  factory HourRange.fromJson(Map<String, dynamic> j) => HourRange(
    minHours: double.tryParse(j['minHours']?.toString() ?? '0.25') ?? 0.25,
    maxHours: double.tryParse(j['maxHours']?.toString() ?? '1.5') ?? 1.5,
  );
}

class AvailableSubtask {
  final String subtaskId;
  final String subtaskName;
  final String category;
  final String taskId;
  final String taskName;
  final double minHours;
  final double maxHours;

  AvailableSubtask({
    required this.subtaskId,
    required this.subtaskName,
    required this.category,
    required this.taskId,
    required this.taskName,
    required this.minHours,
    required this.maxHours,
  });

  factory AvailableSubtask.fromJson(Map<String, dynamic> j) {
    final subtask = j['subtask'] as Map<String, dynamic>?;
    final task = subtask?['projectTask'] as Map<String, dynamic>?;
    return AvailableSubtask(
      subtaskId: subtask?['id'] ?? j['subtaskId'] ?? '',
      subtaskName: subtask?['name'] ?? j['subtaskName'] ?? '',
      category: subtask?['category'] ?? j['category'] ?? '',
      taskId: task?['id'] ?? subtask?['projectTaskId'] ?? j['taskId'] ?? '',
      taskName: task?['name'] ?? j['taskName'] ?? '',
      minHours: double.tryParse(j['minHours']?.toString() ?? '0.25') ?? 0.25,
      maxHours: double.tryParse(j['maxHours']?.toString() ?? '1.5') ?? 1.5,
    );
  }
}

class TimesheetDashboardStats {
  final double totalHoursLogged;
  final int activeMembers;
  final int activeProjects;
  final double budgetUsedPercent;
  final List<TimesheetEntry> recentEntries;
  final List<HoursByRole> hoursByRole;
  final List<HoursByProject> hoursByProject;

  TimesheetDashboardStats({
    required this.totalHoursLogged,
    required this.activeMembers,
    required this.activeProjects,
    required this.budgetUsedPercent,
    required this.recentEntries,
    required this.hoursByRole,
    required this.hoursByProject,
  });

  factory TimesheetDashboardStats.fromJson(Map<String, dynamic> j) =>
      TimesheetDashboardStats(
        totalHoursLogged: double.tryParse(j['totalHoursLogged']?.toString() ?? '0') ?? 0.0,
        activeMembers: j['activeMembers'] ?? 0,
        activeProjects: j['activeProjects'] ?? 0,
        budgetUsedPercent: double.tryParse(j['budgetUsedPercent']?.toString() ?? '0') ?? 0.0,
        recentEntries:
            (j['recentEntries'] as List?)
                ?.map((e) => TimesheetEntry.fromJson(e))
                .toList() ??
            [],
        hoursByRole:
            (j['hoursByRole'] as List?)
                ?.map((e) => HoursByRole.fromJson(e))
                .toList() ??
            [],
        hoursByProject:
            (j['hoursByProject'] as List?)
                ?.map((e) => HoursByProject.fromJson(e))
                .toList() ??
            [],
      );
}

class HoursByRole {
  final String roleName;
  final double hours;

  HoursByRole({required this.roleName, required this.hours});

  factory HoursByRole.fromJson(Map<String, dynamic> j) => HoursByRole(
    roleName: j['roleName'] ?? '',
    hours: double.tryParse(j['hours']?.toString() ?? '0') ?? 0.0,
  );
}

class HoursByProject {
  final String projectName;
  final double hours;
  final double estimatedHours;

  HoursByProject({
    required this.projectName,
    required this.hours,
    required this.estimatedHours,
  });

  factory HoursByProject.fromJson(Map<String, dynamic> j) => HoursByProject(
    projectName: j['projectName'] ?? '',
    hours: double.tryParse(j['hours']?.toString() ?? '0') ?? 0.0,
    estimatedHours: double.tryParse(j['estimatedHours']?.toString() ?? '0') ?? 0.0,
  );
}

class MyTimesheetStats {
  final double myHoursThisWeek;
  final int myActiveProjects;
  final double myTotalHoursAllTime;
  final List<TimesheetEntry> recentEntries;

  MyTimesheetStats({
    required this.myHoursThisWeek,
    required this.myActiveProjects,
    required this.myTotalHoursAllTime,
    required this.recentEntries,
  });

  factory MyTimesheetStats.fromJson(Map<String, dynamic> j) => MyTimesheetStats(
    myHoursThisWeek: double.tryParse(j['myHoursThisWeek']?.toString() ?? '0') ?? 0.0,
    myActiveProjects: j['myActiveProjects'] ?? 0,
    myTotalHoursAllTime: double.tryParse(j['myTotalHoursAllTime']?.toString() ?? '0') ?? 0.0,
    recentEntries:
        (j['recentEntries'] as List?)
            ?.map((e) => TimesheetEntry.fromJson(e))
            .toList() ??
        [],
  );
}
