class TimesheetProject {
  final String id;
  final String name;
  final String type;
  final String status;
  final String companyId;
  final double totalEstimatedHours;
  final String? clientName;
  final String? startDate;
  final String? endDate;

  TimesheetProject({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.companyId,
    required this.totalEstimatedHours,
    this.clientName,
    this.startDate,
    this.endDate,
  });

  factory TimesheetProject.fromJson(Map<String, dynamic> j) => TimesheetProject(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    type: j['type'] ?? '',
    status: j['status'] ?? 'ACTIVE',
    companyId: j['companyId'] ?? '',
    totalEstimatedHours: double.tryParse(j['totalEstimatedHours']?.toString() ?? '0') ?? 0.0,
    clientName: j['clientName'],
    startDate: j['startDate'],
    endDate: j['endDate'],
  );
}

class ProjectTask {
  final String id;
  final String projectId;
  final String name;
  final int orderIndex;
  final List<ProjectSubtask> subtasks;

  ProjectTask({
    required this.id,
    required this.projectId,
    required this.name,
    required this.orderIndex,
    required this.subtasks,
  });

  factory ProjectTask.fromJson(Map<String, dynamic> j) => ProjectTask(
    id: j['id'] ?? '',
    projectId: j['projectId'] ?? '',
    name: j['name'] ?? '',
    orderIndex: j['orderIndex'] ?? 0,
    subtasks:
        (j['subtasks'] as List?)
            ?.map((s) => ProjectSubtask.fromJson(s))
            .toList() ??
        [],
  );
}

class ProjectSubtask {
  final String id;
  final String projectTaskId;
  final String name;
  final String category;

  ProjectSubtask({
    required this.id,
    required this.projectTaskId,
    required this.name,
    required this.category,
  });

  factory ProjectSubtask.fromJson(Map<String, dynamic> j) => ProjectSubtask(
    id: j['id'] ?? '',
    projectTaskId: j['projectTaskId'] ?? '',
    name: j['name'] ?? '',
    category: j['category'] ?? '',
  );
}

class ProjectTechRole {
  final String id;
  final String projectId;
  final String roleName;
  final String? description;
  final List<ProjectTechRoleUser> users;

  ProjectTechRole({
    required this.id,
    required this.projectId,
    required this.roleName,
    this.description,
    required this.users,
  });

  factory ProjectTechRole.fromJson(Map<String, dynamic> j) => ProjectTechRole(
    id: j['id'] ?? '',
    projectId: j['projectId'] ?? '',
    roleName: j['roleName'] ?? '',
    description: j['description'],
    users:
        ((j['assignedUsers'] ?? j['users']) as List?)
            ?.map((u) => ProjectTechRoleUser.fromJson(u))
            .toList() ??
        [],
  );
}

class ProjectTechRoleUser {
  final String id;
  final String projectTechRoleId;
  final String userId;
  final String? userName;

  ProjectTechRoleUser({
    required this.id,
    required this.projectTechRoleId,
    required this.userId,
    this.userName,
  });

  factory ProjectTechRoleUser.fromJson(Map<String, dynamic> j) =>
      ProjectTechRoleUser(
        id: j['id'] ?? '',
        projectTechRoleId: j['projectTechRoleId'] ?? '',
        userId: j['userId'] ?? '',
        userName: j['user']?['firstName'] != null
            ? '${j['user']['firstName']} ${j['user']['lastName'] ?? ''}'.trim()
            : j['userName'],
      );
}

class SubtaskRoleAssignment {
  final String id;
  final String projectSubtaskId;
  final String projectTechRoleId;
  final double minHours;
  final double maxHours;
  final double estimatedHours;
  final String? roleName;
  final String? subtaskName;

  SubtaskRoleAssignment({
    required this.id,
    required this.projectSubtaskId,
    required this.projectTechRoleId,
    required this.minHours,
    required this.maxHours,
    required this.estimatedHours,
    this.roleName,
    this.subtaskName,
  });

  factory SubtaskRoleAssignment.fromJson(Map<String, dynamic> j) =>
      SubtaskRoleAssignment(
        id: j['id'] ?? '',
        projectSubtaskId: j['projectSubtaskId'] ?? '',
        projectTechRoleId: j['projectTechRoleId'] ?? '',
        minHours: double.tryParse(j['minHours']?.toString() ?? '0.25') ?? 0.25,
        maxHours: double.tryParse(j['maxHours']?.toString() ?? '1.5') ?? 1.5,
        estimatedHours: double.tryParse(j['estimatedHours']?.toString() ?? '0.25') ?? 0.25,
        roleName: j['techRole']?['roleName'] ?? j['roleName'],
        subtaskName: j['subtask']?['name'] ?? j['subtaskName'],
      );
}
