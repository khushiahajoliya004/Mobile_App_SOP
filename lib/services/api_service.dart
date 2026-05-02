import 'package:dio/dio.dart';
import 'auth_service.dart';

class ApiService {
  // Backend runs on port 3000, no /api prefix
  // For Android emulator use 10.0.2.2, for real device use your machine IP
  // static const String baseUrl = 'https://api.mysterymentor.in';
  static const String baseUrl = 'http://192.168.1.24:3000';

  late final Dio _dio;
  final AuthService _auth = AuthService();

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(
          seconds: 120,
        ), // 2 min for large audio uploads
        sendTimeout: const Duration(
          seconds: 120,
        ), // 2 min for large audio uploads
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _auth.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  // ─── Auth ───

  /// POST /auth/login
  /// Response: { success, message, data: { user, token, allowedModules, companyUsers? } }
  Future<Response> login(String email, String password) async {
    return _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
  }

  /// POST /auth/register
  Future<Response> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
  }) async {
    return _dio.post(
      '/auth/register',
      data: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
        if (phone != null) 'phone': phone,
      },
    );
  }

  /// GET /auth/user-permissions/:userId
  /// Response: { success, data: { userId, userType, roles, modules, permissions } }
  Future<Response> getUserPermissions(String userId) async {
    return _dio.get('/auth/user-permissions/$userId');
  }

  /// PATCH /auth/profile
  Future<Response> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
  }) async {
    return _dio.patch(
      '/auth/profile',
      data: {
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
      },
    );
  }

  /// PATCH /auth/change-password
  Future<Response> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return _dio.patch(
      '/auth/change-password',
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  // ─── Calls ───

  /// POST /calls  (multipart with audio file)
  /// Required: customerName, companyId, userId
  /// Optional: categoryId, salesStageId, notes, audio file
  Future<Response> createCall({
    required String customerName,
    required String companyId,
    required String userId,
    String? categoryId,
    String? salesStageId,
    String? notes,
    String? audioFilePath,
    String? audioFileName,
  }) async {
    final map = <String, dynamic>{
      'customerName': customerName,
      'companyId': companyId,
      'userId': userId,
      if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
      if (salesStageId != null && salesStageId.isNotEmpty)
        'salesStageId': salesStageId,
      if (notes != null) 'notes': notes,
    };

    if (audioFilePath != null) {
      map['audio'] = await MultipartFile.fromFile(
        audioFilePath,
        filename: audioFileName ?? 'recording.m4a',
      );
    }

    return _dio.post('/calls', data: FormData.fromMap(map));
  }

  /// GET /calls
  /// Response: { success, data: [ Call, ... ] }
  Future<Response> getCalls() async {
    return _dio.get('/calls');
  }

  /// GET /calls/:id
  Future<Response> getCall(String id) async {
    return _dio.get('/calls/$id');
  }

  /// PATCH /calls/:id
  Future<Response> updateCall(String id, Map<String, dynamic> data) async {
    return _dio.patch('/calls/$id', data: data);
  }

  /// DELETE /calls/:id
  Future<Response> deleteCall(String id) async {
    return _dio.delete('/calls/$id');
  }

  // ─── Call Approvals ───

  /// GET /calls/approvals (paginated with filters)
  Future<Response> getCallApprovals({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    return _dio.get(
      '/calls/approvals',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
  }

  /// PATCH /calls/:id/approve
  Future<Response> approveCall(String id) async {
    return _dio.patch('/calls/$id/approve');
  }

  /// PATCH /calls/:id/reject
  Future<Response> rejectCall(String id) async {
    return _dio.patch('/calls/$id/reject');
  }

  // ─── Categories ───

  Future<Response> getCategories() async => _dio.get('/categories');

  Future<Response> createCategory({
    required String name,
    String? description,
    required String companyId,
  }) async {
    return _dio.post(
      '/categories',
      data: {
        'name': name,
        'companyId': companyId,
        if (description != null) 'description': description,
      },
    );
  }

  Future<Response> updateCategory(
    String id, {
    String? name,
    String? description,
  }) async {
    return _dio.patch(
      '/categories/$id',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
      },
    );
  }

  Future<Response> updateCategoryStatus(String id, String status) async {
    return _dio.patch('/categories/$id/status/$status');
  }

  Future<Response> deleteCategory(String id) async =>
      _dio.delete('/categories/$id');

  // ─── Sales Stages ───

  Future<Response> getSalesStages() async => _dio.get('/sales-stages');

  Future<Response> createSalesStage({
    required String name,
    String? description,
    required String companyId,
    int? sortOrder,
  }) async {
    return _dio.post(
      '/sales-stages',
      data: {
        'name': name,
        'companyId': companyId,
        if (description != null) 'description': description,
        if (sortOrder != null) 'sortOrder': sortOrder,
      },
    );
  }

  Future<Response> updateSalesStage(
    String id, {
    String? name,
    String? description,
    int? sortOrder,
  }) async {
    return _dio.patch(
      '/sales-stages/$id',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (sortOrder != null) 'sortOrder': sortOrder,
      },
    );
  }

  Future<Response> updateSalesStageStatus(String id, String status) async {
    return _dio.patch('/sales-stages/$id/status/$status');
  }

  Future<Response> deleteSalesStage(String id) async =>
      _dio.delete('/sales-stages/$id');

  // ─── Industries ───

  Future<Response> getIndustries() async => _dio.get('/industries');

  Future<Response> createIndustry({
    required String name,
    String? description,
    String? companyId,
  }) async {
    return _dio.post(
      '/industries',
      data: {
        'name': name,
        if (description != null) 'description': description,
        if (companyId != null) 'companyId': companyId,
      },
    );
  }

  Future<Response> updateIndustry(
    String id, {
    String? name,
    String? description,
  }) async {
    return _dio.patch(
      '/industries/$id',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
      },
    );
  }

  Future<Response> updateIndustryStatus(String id, String status) async {
    return _dio.patch('/industries/$id/status/$status');
  }

  Future<Response> deleteIndustry(String id) async =>
      _dio.delete('/industries/$id');

  // ─── Users ───

  Future<Response> createUser({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String userType = 'USER',
    String? phone,
    String? companyId,
    List<String>? roleIds,
    bool? aiEnabled,
  }) async {
    return _dio.post(
      '/users',
      data: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
        'userType': userType,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (companyId != null) 'companyId': companyId,
        if (roleIds != null && roleIds.isNotEmpty) 'roleIds': roleIds,
        if (aiEnabled != null) 'aiEnabled': aiEnabled,
      },
    );
  }

  Future<Response> updateUser(
    String id, {
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    List<String>? roleIds,
    bool? aiEnabled,
  }) async {
    return _dio.patch(
      '/users/$id',
      data: {
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (roleIds != null) 'roleIds': roleIds,
        if (aiEnabled != null) 'aiEnabled': aiEnabled,
      },
    );
  }

  Future<Response> updateUserStatus(String id, String status) async =>
      _dio.patch('/users/$id/status/$status');

  Future<Response> deleteUser(String id) async => _dio.delete('/users/$id');

  Future<Response> assignSopToUser(String userId, String? sopId) async {
    return _dio.patch('/users/$userId/assign-sop', data: {'sopId': sopId});
  }

  // ─── Roles ───

  Future<Response> getRoles() async => _dio.get('/roles');

  Future<Response> getRole(String id) async => _dio.get('/roles/$id');

  Future<Response> createRole({
    required String name,
    String? description,
    String? companyId,
    List<String>? permissionIds,
  }) async {
    return _dio.post(
      '/roles',
      data: {
        'name': name,
        if (description != null) 'description': description,
        if (companyId != null) 'companyId': companyId,
        if (permissionIds != null) 'permissionIds': permissionIds,
      },
    );
  }

  Future<Response> updateRole(
    String id, {
    String? name,
    String? description,
    List<String>? permissionIds,
  }) async {
    return _dio.patch(
      '/roles/$id',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (permissionIds != null) 'permissionIds': permissionIds,
      },
    );
  }

  Future<Response> deleteRole(String id) async => _dio.delete('/roles/$id');

  // ─── Permissions (for role builder) ───

  Future<Response> getPermissions() async => _dio.get('/permissions');

  // ─── SOPs ───

  Future<Response> getSops() async => _dio.get('/sops');

  Future<Response> getSop(String id) async => _dio.get('/sops/$id');

  Future<Response> createSop(Map<String, dynamic> data) async =>
      _dio.post('/sops', data: data);

  Future<Response> updateSop(String id, Map<String, dynamic> data) async =>
      _dio.patch('/sops/$id', data: data);

  Future<Response> deleteSop(String id) async => _dio.delete('/sops/$id');

  // ─── Credits ───

  Future<Response> getCredits() async => _dio.get('/credits');

  Future<Response> getCreditBalance(String companyId) async =>
      _dio.get('/credits/balance/$companyId');

  Future<Response> purchaseCredits({
    required String companyId,
    required String planId,
  }) async {
    return _dio.post(
      '/credits/purchase',
      data: {'companyId': companyId, 'planId': planId},
    );
  }

  // ─── Plans (for credit purchase) ───

  Future<Response> getPlans() async => _dio.get('/plans');

  // ─── Branches ───

  Future<Response> createBranch({
    required String name,
    String? code,
    String? city,
    String? address,
    String? state,
    String? phone,
    String? companyId,
  }) async {
    return _dio.post(
      '/branches',
      data: {
        'name': name,
        if (code != null && code.isNotEmpty) 'code': code,
        if (city != null && city.isNotEmpty) 'city': city,
        if (address != null && address.isNotEmpty) 'address': address,
        if (state != null && state.isNotEmpty) 'state': state,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (companyId != null) 'companyId': companyId,
      },
    );
  }

  Future<Response> updateBranch(String id, Map<String, dynamic> data) async =>
      _dio.patch('/branches/$id', data: data);

  Future<Response> deleteBranch(String id) async =>
      _dio.delete('/branches/$id');

  // ─── Lead Pipelines ───

  Future<Response> createPipeline({
    required String name,
    String? description,
    String? companyId,
    List<String>? stageNames,
  }) async {
    final stages = stageNames
        ?.asMap()
        .entries
        .map((e) => {'name': e.value, 'sortOrder': e.key})
        .toList();
    return _dio.post(
      '/lead-pipelines',
      data: {
        'name': name,
        if (description != null) 'description': description,
        if (companyId != null) 'companyId': companyId,
        if (stages != null) 'stages': stages,
      },
    );
  }

  // ─── Visits ───

  Future<Response> createVisit({
    required String leadId,
    required DateTime scheduledAt,
    String? notes,
  }) async {
    return _dio.post(
      '/visits',
      data: {
        'leadId': leadId,
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
  }

  // ─── Analytics ───

  Future<Response> getAnalyticsOverview({String period = '30d'}) async {
    return _dio.get('/analytics/overview', queryParameters: {'period': period});
  }

  Future<Response> getAnalyticsUserPerformance({String period = '30d'}) async {
    return _dio.get(
      '/analytics/user-performance',
      queryParameters: {'period': period},
    );
  }

  Future<Response> getAnalyticsTrend({String period = '30d'}) async {
    return _dio.get('/analytics/trend', queryParameters: {'period': period});
  }

  // ─── AI Insights (additional) ───

  Future<Response> evaluateTranscript({
    required String sopId,
    required String transcript,
  }) async {
    return _dio.post(
      '/ai-insights/evaluate-transcript',
      data: {'sopId': sopId, 'transcript': transcript},
    );
  }

  // ─── File Upload ───

  /// POST /files/upload (multipart, field name: 'file')
  Future<Response> uploadFile(String filePath, String fileName) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    return _dio.post('/files/upload', data: formData);
  }

  // ─── Dashboard ───

  /// GET /dashboard/company
  Future<Response> getCompanyDashboard() async {
    return _dio.get('/dashboard/company');
  }

  // ─── Users ───

  Future<Response> getUsers() async => _dio.get('/users');

  Future<Response> getUser(String id) async => _dio.get('/users/$id');

  Future<Response> getMySop() async => _dio.get('/users/me/sop');

  // ─── AI Insights ───

  Future<Response> getAiInsights({int page = 1, int limit = 20}) async {
    return _dio.get(
      '/ai-insights',
      queryParameters: {'page': page, 'limit': limit},
    );
  }

  Future<Response> getAiInsightDetail(String callId) async {
    return _dio.get('/ai-insights/$callId');
  }

  // ─── Companies ───

  /// GET /companies/my-company/details
  Future<Response> getMyCompany() async {
    return _dio.get('/companies/my-company/details');
  }

  // ─── CRM ───

  Future<Response> getCrmDashboard() async =>
      _dio.get('/crm-dashboard/summary');

  Future<Response> getAssignableUsers() async =>
      _dio.get('/crm-dashboard/assignable-users');

  Future<Response> getBranches() async => _dio.get('/branches');

  Future<Response> getLeadPipelines() async => _dio.get('/lead-pipelines');

  Future<Response> getLeads({String? status, String? search}) async {
    return _dio.get(
      '/leads',
      queryParameters: {
        if (status != null) 'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
  }

  Future<Response> getAssignedLeads() async =>
      _dio.get('/leads', queryParameters: {'status': 'OPEN'});

  Future<Response> createLead({
    required String customerName,
    String? phone,
    String? source,
    String? branchId,
    String? pipelineId,
    String? leadStageId,
  }) async {
    return _dio.post(
      '/leads',
      data: {
        'customerName': customerName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (source != null && source.isNotEmpty) 'source': source,
        if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
        if (pipelineId != null && pipelineId.isNotEmpty)
          'pipelineId': pipelineId,
        if (leadStageId != null && leadStageId.isNotEmpty)
          'leadStageId': leadStageId,
      },
    );
  }

  Future<Response> updateLeadStatus(
    String leadId,
    Map<String, dynamic> data,
  ) async {
    return _dio.patch('/leads/$leadId/status', data: data);
  }

  Future<Response> assignLead(String leadId, String assignedToUserId) async {
    return _dio.patch(
      '/leads/$leadId/assign',
      data: {'assignedToUserId': assignedToUserId},
    );
  }

  Future<Response> createLeadActivity({
    required String leadId,
    String type = 'NOTE',
    String? callId,
    String? notes,
    String? outcome,
  }) async {
    return _dio.post(
      '/leads/$leadId/activities',
      data: {
        'leadId': leadId,
        'type': type,
        if (callId != null && callId.isNotEmpty) 'callId': callId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (outcome != null && outcome.isNotEmpty) 'outcome': outcome,
      },
    );
  }

  Future<Response> createFollowUp({
    required String leadId,
    required DateTime scheduledAt,
    String type = 'CALL',
    String? notes,
  }) async {
    return _dio.post(
      '/follow-ups',
      data: {
        'leadId': leadId,
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        'type': type,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
  }

  Future<Response> getFollowUps() async {
    return _dio.get('/follow-ups');
  }

  Future<Response> getVisits() async {
    return _dio.get('/visits');
  }

  // ─── Generic CRUD ───

  Future<Response> genericGet(
    String endpoint, {
    Map<String, dynamic>? queryParams,
  }) async {
    return _dio.get(endpoint, queryParameters: queryParams);
  }

  Future<Response> genericPost(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    return _dio.post(endpoint, data: data);
  }

  Future<Response> genericPatch(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    return _dio.patch(endpoint, data: data);
  }

  Future<Response> genericDelete(String endpoint) async {
    return _dio.delete(endpoint);
  }
}
