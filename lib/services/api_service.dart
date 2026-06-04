import 'package:dio/dio.dart';
import 'auth_service.dart';

class ApiService {
  // Backend runs on port 3000, no /api prefix
  // For Android emulator use 10.0.2.2, for real device use your machine IP
  static const String baseUrl = 'https://apimysterymentorqa.mysterymentor.in';

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
    String? leadId,
    String? phoneNumber,
  }) async {
    final map = <String, dynamic>{
      'customerName': customerName,
      'companyId': companyId,
      'userId': userId,
      if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
      if (salesStageId != null && salesStageId.isNotEmpty)
        'salesStageId': salesStageId,
      if (notes != null) 'notes': notes,
      if (leadId != null && leadId.isNotEmpty) 'leadId': leadId,
      if (phoneNumber != null && phoneNumber.isNotEmpty) 'phoneNumber': phoneNumber,
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

  // ─── Plans ───

  Future<Response> getPlans() async => _dio.get('/plans');

  Future<Response> getActivePlans() async => _dio.get('/plans/active');

  Future<Response> createPlan({
    required String name,
    String? description,
    required double price,
    required int credits,
  }) async {
    return _dio.post('/plans', data: {
      'name': name,
      if (description != null && description.isNotEmpty)
        'description': description,
      'price': price,
      'credits': credits,
    });
  }

  Future<Response> updatePlan(String id, Map<String, dynamic> data) async =>
      _dio.patch('/plans/$id', data: data);

  Future<Response> updatePlanStatus(String id, String status) async =>
      _dio.patch('/plans/$id/status/$status');

  Future<Response> deletePlan(String id) async => _dio.delete('/plans/$id');

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

  Future<Response> getBranchTeam(String branchId) async =>
      _dio.get('/branches/$branchId/team');

  Future<Response> assignUserToBranch(
    String branchId, {
    required String userId,
    required String branchRole,
    String? reportingToUserId,
    bool isPrimary = false,
  }) async =>
      _dio.post('/branches/$branchId/users', data: {
        'userId': userId,
        'branchRole': branchRole,
        if (reportingToUserId != null && reportingToUserId.isNotEmpty)
          'reportingToUserId': reportingToUserId,
        'isPrimary': isPrimary,
      });

  Future<Response> removeUserFromBranch(String branchId, String userId) async =>
      _dio.delete('/branches/$branchId/users/$userId');

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
  Future<Response> getCompanyDashboard({String period = '30d'}) async {
    return _dio.get('/dashboard/company', queryParameters: {'period': period});
  }

  /// GET /dashboard/my — personal dashboard for logged-in user
  Future<Response> getMyDashboard({String period = '30d'}) async {
    return _dio.get('/dashboard/my', queryParameters: {'period': period});
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

  /// GET /companies
  Future<Response> getCompanies() async => _dio.get('/companies');

  /// GET /companies/:id
  Future<Response> getCompany(String id) async => _dio.get('/companies/$id');

  /// POST /companies
  Future<Response> createCompany({
    required String name,
    required String email,
    required String distributorId,
    String? phone,
    String? address,
    String? contactPerson,
    String? gstNumber,
    String? website,
    String? password,
    String? industryId,
    String? businessType,
    String? state,
    String? language,
    String? evaluationFocus,
  }) async {
    return _dio.post(
      '/companies',
      data: {
        'name': name,
        'email': email,
        'distributorId': distributorId,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (address != null && address.isNotEmpty) 'address': address,
        if (contactPerson != null && contactPerson.isNotEmpty)
          'contactPerson': contactPerson,
        if (gstNumber != null && gstNumber.isNotEmpty) 'gstNumber': gstNumber,
        if (website != null && website.isNotEmpty) 'website': website,
        if (password != null && password.isNotEmpty) 'password': password,
        if (industryId != null && industryId.isNotEmpty)
          'industryId': industryId,
        if (businessType != null && businessType.isNotEmpty)
          'businessType': businessType,
        if (state != null && state.isNotEmpty) 'state': state,
        if (language != null && language.isNotEmpty) 'language': language,
        if (evaluationFocus != null && evaluationFocus.isNotEmpty)
          'evaluationFocus': evaluationFocus,
      },
    );
  }

  /// PATCH /companies/:id
  Future<Response> updateCompany(
    String id,
    Map<String, dynamic> data,
  ) async => _dio.patch('/companies/$id', data: data);

  /// PATCH /companies/:id/status/:status
  Future<Response> updateCompanyStatus(String id, String status) async =>
      _dio.patch('/companies/$id/status/$status');

  /// DELETE /companies/:id
  Future<Response> deleteCompany(String id) async =>
      _dio.delete('/companies/$id');

  // ─── Distributors ───

  /// GET /distributors
  Future<Response> getDistributors() async => _dio.get('/distributors');

  /// GET /distributors/:id
  Future<Response> getDistributor(String id) async =>
      _dio.get('/distributors/$id');

  /// POST /distributors
  Future<Response> createDistributor({
    required String name,
    required String email,
    String? phone,
    String? address,
    String? contactPerson,
    String? gstNumber,
  }) async {
    return _dio.post(
      '/distributors',
      data: {
        'name': name,
        'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (address != null && address.isNotEmpty) 'address': address,
        if (contactPerson != null && contactPerson.isNotEmpty)
          'contactPerson': contactPerson,
        if (gstNumber != null && gstNumber.isNotEmpty) 'gstNumber': gstNumber,
      },
    );
  }

  /// PATCH /distributors/:id
  Future<Response> updateDistributor(
    String id,
    Map<String, dynamic> data,
  ) async => _dio.patch('/distributors/$id', data: data);

  /// PATCH /distributors/:id/status/:status
  Future<Response> updateDistributorStatus(String id, String status) async =>
      _dio.patch('/distributors/$id/status/$status');

  /// DELETE /distributors/:id
  Future<Response> deleteDistributor(String id) async =>
      _dio.delete('/distributors/$id');

  // ─── CRM ───

  Future<Response> getCrmDashboard() async =>
      _dio.get('/crm/deals/analytics/dashboard');

  Future<Response> getAssignableUsers() async =>
      _dio.get('/crm-dashboard/assignable-users');

  Future<Response> getMyCrmPermissions() async =>
      _dio.get('/crm/my-permissions');

  Future<Response> getCrmUsersByBranch(String branchId) async =>
      _dio.get('/crm/users/by-branch/$branchId');

  Future<Response> getCrmUsersByRole(String roleName) async =>
      _dio.get('/crm/users/by-role/$roleName');

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

  Future<Response> getCrmDeals({String? search, String? status, String? pipelineId, String? branchId, String? ownerUserId}) async {
    return _dio.get(
      '/crm/deals',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null) 'status': status,
        if (pipelineId != null) 'pipelineId': pipelineId,
        if (branchId != null) 'branchId': branchId,
        if (ownerUserId != null) 'ownerUserId': ownerUserId,
      },
    );
  }

  Future<Response> getCrmDeal(String id) async => _dio.get('/crm/deals/$id');

  Future<Response> updateCrmDeal(String id, Map<String, dynamic> data) async =>
      _dio.patch('/crm/deals/$id', data: data);

  Future<Response> getCrmContacts({String? search}) async {
    return _dio.get('/crm/contacts', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
    });
  }

  Future<Response> getAssignedLeads() async =>
      _dio.get('/leads', queryParameters: {'status': 'OPEN'});

  Future<Response> createCrmQuickLead({
    required String name,
    String? phone,
    String? email,
    String? source,
    String? pipelineId,
    String? ownerUserId,
    String? branchId,
    String? notes,
  }) async {
    return _dio.post(
      '/crm/contacts/quick-lead',
      data: {
        'name': name,
        'createDeal': true,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
        if (source != null && source.isNotEmpty) 'source': source,
        if (pipelineId != null && pipelineId.isNotEmpty) 'pipelineId': pipelineId,
        if (ownerUserId != null && ownerUserId.isNotEmpty) 'ownerUserId': ownerUserId,
        if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
  }

  Future<Response> createLead({
    required String customerName,
    String? phone,
    String? source,
    String? branchId,
    String? pipelineId,
    String? leadStageId,
    String? interestedModel,
    String? buyerType,
    String? priority,
    String? assignedToUserId,
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
        if (interestedModel != null && interestedModel.isNotEmpty)
          'interestedModel': interestedModel,
        if (buyerType != null && buyerType.isNotEmpty) 'buyerType': buyerType,
        if (priority != null && priority.isNotEmpty) 'priority': priority,
        if (assignedToUserId != null && assignedToUserId.isNotEmpty)
          'assignedToUserId': assignedToUserId,
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

  Future<Response> createEnquiry(Map<String, dynamic> data) async {
    return _dio.post('/leads/enquiry', data: data);
  }

  Future<Response> checkDuplicateLead(String phone) async {
    return _dio.post('/leads/check-duplicate', data: {'phone': phone});
  }

  Future<Response> getLeadBoard({
    String? search,
    String? branchId,
    String? dseId,
    String? status,
    String? priority,
    int? page,
    int? limit,
  }) async {
    return _dio.get(
      '/leads/board',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (branchId != null) 'branchId': branchId,
        if (dseId != null) 'dseId': dseId,
        if (status != null) 'status': status,
        if (priority != null) 'priority': priority,
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
      },
    );
  }

  Future<Response> getLeadDetails(String leadId) async =>
      _dio.get('/leads/$leadId/details');

  Future<Response> getLeadTimeline(String leadId) async =>
      _dio.get('/leads/$leadId/timeline');

  Future<Response> getLeadRequirement(String leadId) async =>
      _dio.get('/leads/$leadId/requirement');

  Future<Response> saveLeadRequirement(
    String leadId,
    Map<String, dynamic> data,
  ) async => _dio.post('/leads/$leadId/requirement', data: data);

  Future<Response> updateLeadRequirement(
    String leadId,
    Map<String, dynamic> data,
  ) async => _dio.patch('/leads/$leadId/requirement', data: data);

  Future<Response> markLeadLost(String leadId, {String? reason}) async =>
      _dio.post(
        '/leads/$leadId/mark-lost',
        data: {if (reason != null) 'lostReason': reason},
      );

  Future<Response> reopenLead(String leadId) async =>
      _dio.patch('/leads/$leadId/reopen');

  Future<Response> reassignDse(
    String leadId,
    String newDseId, {
    String? reason,
  }) async {
    return _dio.post(
      '/leads/$leadId/reassign-dse',
      data: {
        'assignedToUserId': newDseId,
        if (reason != null) 'reason': reason,
      },
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

  Future<Response> getFollowUps({
    String? status,
    String? branchId,
    bool? overdue,
  }) async {
    return _dio.get(
      '/follow-ups',
      queryParameters: {
        if (status != null) 'status': status,
        if (branchId != null) 'branchId': branchId,
        if (overdue == true) 'overdue': 'true',
      },
    );
  }

  Future<Response> completeFollowUpWithWorkflow(
    String id, {
    required String outcome,
    String? notes,
    String? nextFollowUpDateTime,
    String? nextAction,
  }) async {
    return _dio.post(
      '/follow-ups/$id/complete',
      data: {
        'outcome': outcome,
        if (notes != null) 'notes': notes,
        if (nextFollowUpDateTime != null)
          'nextFollowUpDateTime': nextFollowUpDateTime,
        if (nextAction != null) 'nextAction': nextAction,
      },
    );
  }

  // ─── CRM v2 Follow-ups (for deals) ───

  Future<Response> getCrmFollowUps({String? status, bool? overdue}) async {
    return _dio.get('/crm/follow-ups', queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
      if (overdue == true) 'overdue': 'true',
    });
  }

  Future<Response> getCrmFollowUpsByDeal(String dealId) async {
    return _dio.get('/crm/follow-ups', queryParameters: {'dealId': dealId});
  }

  Future<Response> createCrmFollowUp({
    String? dealId,
    required DateTime scheduledAt,
    String type = 'CALL',
    String? notes,
    String? contactId,
    String? assignedToUserId,
  }) async {
    return _dio.post('/crm/follow-ups', data: {
      if (dealId != null && dealId.isNotEmpty) 'dealId': dealId,
      'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      'type': type,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (contactId != null) 'contactId': contactId,
      if (assignedToUserId != null) 'assignedToUserId': assignedToUserId,
    });
  }

  Future<Response> completeCrmFollowUp(
    String id, {
    required String outcome,
    String? notes,
    String? nextFollowUpDate,
    String? nextFollowUpType,
  }) async {
    return _dio.post('/crm/follow-ups/$id/complete', data: {
      'outcome': outcome,
      if (notes != null) 'notes': notes,
      if (nextFollowUpDate != null) 'nextFollowUpDate': nextFollowUpDate,
      if (nextFollowUpType != null) 'nextFollowUpType': nextFollowUpType,
    });
  }

  Future<Response> rescheduleFollowUp(String id, String scheduledAt) async {
    return _dio.post(
      '/follow-ups/$id/reschedule',
      data: {'scheduledAt': scheduledAt},
    );
  }

  Future<Response> getVisits({String? status, String? branchId}) async {
    return _dio.get(
      '/visits',
      queryParameters: {
        if (status != null) 'status': status,
        if (branchId != null) 'branchId': branchId,
      },
    );
  }

  Future<Response> getVisitsByLead(String leadId) async {
    return _dio.get('/visits', queryParameters: {'leadId': leadId});
  }

  Future<Response> completeVisit(
    String id, {
    String? customerFeedback,
    String? nextStep,
    String? notes,
  }) async {
    return _dio.post(
      '/visits/$id/complete',
      data: {
        if (customerFeedback != null) 'customerFeedback': customerFeedback,
        if (nextStep != null) 'nextStep': nextStep,
        if (notes != null) 'notes': notes,
      },
    );
  }

  // ─── CRM Extension (Car Showroom) ───

  Future<Response> getTestDrives({String? leadId}) async {
    return _dio.get(
      '/test-drives',
      queryParameters: {if (leadId != null) 'leadId': leadId},
    );
  }

  Future<Response> createTestDrive({
    required String leadId,
    required DateTime scheduledAt,
    String? vehicleModel,
    String? variant,
  }) async {
    return _dio.post(
      '/test-drives',
      data: {
        'leadId': leadId,
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        if (vehicleModel != null) 'vehicleModel': vehicleModel,
        if (variant != null) 'variant': variant,
      },
    );
  }

  Future<Response> completeTestDrive(
    String id, {
    String? feedback,
    int? rating,
    String? nextAction,
  }) async {
    return _dio.post(
      '/test-drives/$id/complete',
      data: {
        if (feedback != null) 'customerFeedback': feedback,
        if (rating != null) 'rating': rating,
        if (nextAction != null) 'nextAction': nextAction,
      },
    );
  }

  Future<Response> rescheduleTestDrive(
    String id,
    String scheduledAt, {
    String? reason,
  }) async {
    return _dio.post(
      '/test-drives/$id/reschedule',
      data: {'scheduledAt': scheduledAt, if (reason != null) 'reason': reason},
    );
  }

  Future<Response> cancelTestDrive(String id, {String? reason}) async {
    return _dio.post(
      '/test-drives/$id/cancel',
      data: {if (reason != null) 'reason': reason},
    );
  }

  Future<Response> getQuotations({String? leadId}) async {
    return _dio.get(
      '/quotations',
      queryParameters: {if (leadId != null) 'leadId': leadId},
    );
  }

  Future<Response> createQuotation(Map<String, dynamic> data) async =>
      _dio.post('/quotations', data: data);

  Future<Response> updateQuotationStatus(String id, String status) async =>
      _dio.patch('/quotations/$id/status/$status');

  Future<Response> sendQuotation(String id) async =>
      _dio.post('/quotations/$id/send');

  Future<Response> quotationCustomerResponse(
    String id,
    String response, {
    String? remarks,
  }) async => _dio.post(
    '/quotations/$id/customer-response',
    data: {'response': response, if (remarks != null) 'remarks': remarks},
  );

  // ─── Negotiations ───

  Future<Response> getNegotiations() async => _dio.get('/crm-negotiations');

  Future<Response> getNegotiationsByLead(String leadId) async =>
      _dio.get('/crm-negotiations/lead/$leadId');

  Future<Response> createNegotiation(Map<String, dynamic> data) async =>
      _dio.post('/crm-negotiations', data: data);

  Future<Response> approveNegotiation(
    String id, {
    double? approvedDiscount,
    String? remarks,
  }) async => _dio.post(
    '/crm-negotiations/$id/approve',
    data: {
      if (approvedDiscount != null) 'approvedDiscount': approvedDiscount,
      if (remarks != null) 'remarks': remarks,
    },
  );

  Future<Response> rejectNegotiation(String id, {String? reason}) async =>
      _dio.post(
        '/crm-negotiations/$id/reject',
        data: {if (reason != null) 'reason': reason},
      );

  Future<Response> getBookings({String? leadId}) async {
    return _dio.get(
      '/bookings',
      queryParameters: {if (leadId != null) 'leadId': leadId},
    );
  }

  Future<Response> createBooking(Map<String, dynamic> data) async =>
      _dio.post('/bookings', data: data);

  Future<Response> confirmBooking(String id) async =>
      _dio.patch('/bookings/$id/confirm');

  Future<Response> confirmBookingWithWorkflow(
    String id, {
    bool? financeRequired,
    bool? exchangeRequired,
  }) async => _dio.post(
    '/bookings/$id/confirm',
    data: {
      if (financeRequired != null) 'financeRequired': financeRequired,
      if (exchangeRequired != null) 'exchangeRequired': exchangeRequired,
    },
  );

  Future<Response> cancelBooking(String id, String reason) async =>
      _dio.post('/bookings/$id/cancel', data: {'reason': reason});

  Future<Response> getBookingsByLead(String leadId) async =>
      _dio.get('/bookings/by-lead/$leadId');

  Future<Response> getFinance(String leadId) async =>
      _dio.get('/crm-finance/lead/$leadId');

  Future<Response> getAllFinance() async => _dio.get('/crm-finance');

  Future<Response> getFinanceByBooking(String bookingId) async =>
      _dio.get('/crm-finance/by-booking/$bookingId');

  Future<Response> saveFinance(Map<String, dynamic> data) async =>
      _dio.post('/crm-finance', data: data);

  Future<Response> updateFinanceById(
    String id,
    Map<String, dynamic> data,
  ) async => _dio.patch('/crm-finance/$id', data: data);

  Future<Response> updateFinanceStatusWithWorkflow(
    String id,
    String status, {
    String? remarks,
  }) async => _dio.post(
    '/crm-finance/$id/status',
    data: {'status': status, if (remarks != null) 'remarks': remarks},
  );

  Future<Response> getDocuments(String leadId) async =>
      _dio.get('/crm-documents/lead/$leadId');

  Future<Response> getDocumentsByBooking(String bookingId) async =>
      _dio.get('/crm-documents/by-booking/$bookingId');

  Future<Response> createDocument({
    required String leadId,
    required String documentType,
    bool? isRequired,
    String? fileUrl,
  }) async {
    return _dio.post(
      '/crm-documents',
      data: {
        'leadId': leadId,
        'documentType': documentType,
        if (isRequired != null) 'isRequired': isRequired,
        if (fileUrl != null) 'fileUrl': fileUrl,
      },
    );
  }

  Future<Response> verifyDocument(String id) async =>
      _dio.post('/crm-documents/$id/verify');

  Future<Response> rejectDocument(String id, {String? reason}) async =>
      _dio.post(
        '/crm-documents/$id/reject',
        data: {if (reason != null) 'reason': reason},
      );

  // ─── Exchange Vehicle ───

  Future<Response> getExchangeByBooking(String bookingId) async =>
      _dio.get('/exchange-vehicles/by-booking/$bookingId');

  Future<Response> approveExchange(
    String id, {
    double? finalApprovedValue,
    String? remarks,
  }) async => _dio.post(
    '/exchange-vehicles/$id/approve',
    data: {
      if (finalApprovedValue != null) 'finalApprovedValue': finalApprovedValue,
      if (remarks != null) 'remarks': remarks,
    },
  );

  Future<Response> rejectExchange(String id, {String? reason}) async =>
      _dio.post(
        '/exchange-vehicles/$id/reject',
        data: {if (reason != null) 'reason': reason},
      );

  Future<Response> getDeliveries() async => _dio.get('/deliveries');

  Future<Response> createDelivery({
    required String bookingId,
    String? chassisNumber,
    String? engineNumber,
  }) async {
    return _dio.post(
      '/deliveries',
      data: {
        'bookingId': bookingId,
        if (chassisNumber != null) 'chassisNumber': chassisNumber,
        if (engineNumber != null) 'engineNumber': engineNumber,
      },
    );
  }

  Future<Response> markDeliveryReady(String id) async =>
      _dio.post('/deliveries/$id/mark-ready');

  Future<Response> markDelivered(
    String id, {
    String? deliveryNotes,
    String? deliveryPhotoUrl,
    String? customerSignatureUrl,
  }) async => _dio.post(
    '/deliveries/$id/mark-delivered',
    data: {
      if (deliveryNotes != null) 'deliveryNotes': deliveryNotes,
      if (deliveryPhotoUrl != null) 'deliveryPhotoUrl': deliveryPhotoUrl,
      if (customerSignatureUrl != null)
        'customerSignatureUrl': customerSignatureUrl,
    },
  );

  Future<Response> checkDeliveryReadiness(
    String leadId,
    String bookingId,
  ) async => _dio.post(
    '/deliveries/check-readiness',
    data: {'leadId': leadId, 'bookingId': bookingId},
  );

  Future<Response> scheduleDelivery({
    required String bookingId,
    required String deliveryDateTime,
    String? notes,
  }) async => _dio.post(
    '/deliveries/schedule',
    data: {
      'bookingId': bookingId,
      'deliveryDateTime': deliveryDateTime,
      if (notes != null) 'deliveryNotes': notes,
    },
  );

  // ─── Feedback ───

  Future<Response> submitFeedback(Map<String, dynamic> data) async =>
      _dio.post('/crm-feedback', data: data);

  Future<Response> getFeedbackByDelivery(String deliveryId) async =>
      _dio.get('/crm-feedback/by-delivery/$deliveryId');

  // ─── Vehicle Inventory ───

  Future<Response> getVehicleInventory({String? status}) async {
    return _dio.get(
      '/vehicle-inventory',
      queryParameters: {if (status != null) 'status': status},
    );
  }

  Future<Response> createVehicleInventory(Map<String, dynamic> data) async =>
      _dio.post('/vehicle-inventory', data: data);

  Future<Response> getAvailableVehicles({
    String? branchId,
    String? model,
  }) async => _dio.get(
    '/vehicle-inventory/available',
    queryParameters: {
      if (branchId != null) 'branchId': branchId,
      if (model != null) 'model': model,
    },
  );

  // ─── Vehicle Allocation ───

  Future<Response> allocateVehicle({
    required String bookingId,
    required String vehicleInventoryId,
    bool? hasAccessories,
    String? remarks,
  }) async {
    return _dio.post(
      '/vehicle-allocations',
      data: {
        'bookingId': bookingId,
        'vehicleInventoryId': vehicleInventoryId,
        if (hasAccessories != null) 'hasAccessories': hasAccessories,
        if (remarks != null) 'remarks': remarks,
      },
    );
  }

  Future<Response> getVehicleAllocations() async =>
      _dio.get('/vehicle-allocations');

  Future<Response> getAllocationByBooking(String bookingId) async =>
      _dio.get('/vehicle-allocations/booking/$bookingId');

  Future<Response> getAllocationHistory(String bookingId) async =>
      _dio.get('/vehicle-allocations/history/$bookingId');

  Future<Response> releaseVehicle(String id) async =>
      _dio.post('/vehicle-allocations/$id/release');

  // ─── Exchange Vehicle ───

  Future<Response> getExchangeVehicle(String leadId) async =>
      _dio.get('/exchange-vehicles/lead/$leadId');

  Future<Response> saveExchangeVehicle(Map<String, dynamic> data) async =>
      _dio.post('/exchange-vehicles', data: data);

  // ─── Insurance ───

  Future<Response> getInsurance(String leadId) async =>
      _dio.get('/crm-insurance/lead/$leadId');

  Future<Response> saveInsurance(Map<String, dynamic> data) async =>
      _dio.post('/crm-insurance', data: data);

  // ─── RTO ───

  Future<Response> getRto(String leadId) async =>
      _dio.get('/crm-rto/lead/$leadId');

  Future<Response> saveRto(Map<String, dynamic> data) async =>
      _dio.post('/crm-rto', data: data);

  // ─── Accessories ───

  Future<Response> getAccessories(String leadId) async =>
      _dio.get('/crm-accessories/lead/$leadId');

  Future<Response> addAccessory(Map<String, dynamic> data) async =>
      _dio.post('/crm-accessories', data: data);

  // ─── PDI ───

  Future<Response> getPdi(String leadId) async =>
      _dio.get('/crm-pdi/lead/$leadId');

  Future<Response> savePdi(Map<String, dynamic> data) async =>
      _dio.post('/crm-pdi', data: data);

  // ─── Payments ───

  Future<Response> getPayments(String leadId) async =>
      _dio.get('/crm-payments/lead/$leadId');

  Future<Response> addPayment(Map<String, dynamic> data) async =>
      _dio.post('/crm-payments', data: data);

  // ─── Feedback ───

  Future<Response> getFeedback(String leadId) async =>
      _dio.get('/crm-feedback/lead/$leadId');

  Future<Response> saveFeedback(Map<String, dynamic> data) async =>
      _dio.post('/crm-feedback', data: data);

  // ─── CRM Workflow Engine ───

  Future<Response> processWorkflow({
    required String leadId,
    String? bookingId,
    String? taskId,
    required String actionType,
    String? outcome,
    Map<String, dynamic>? payload,
  }) async {
    return _dio.post(
      '/crm/workflow/process',
      data: {
        'leadId': leadId,
        'actionType': actionType,
        if (bookingId != null) 'bookingId': bookingId,
        if (taskId != null) 'taskId': taskId,
        if (outcome != null) 'outcome': outcome,
        if (payload != null) 'payload': payload,
      },
    );
  }

  // ─── Reports & Escalations ───

  Future<Response> getReport(
    String reportType, {
    Map<String, dynamic>? filters,
  }) async => _dio.get('/crm/reports/$reportType', queryParameters: filters);

  Future<Response> getEscalations({String? branchId}) async => _dio.get(
    '/crm/escalations',
    queryParameters: {if (branchId != null) 'branchId': branchId},
  );

  Future<Response> getMyTasks({String? status, String? taskType}) async {
    return _dio.get(
      '/crm/tasks/my-tasks',
      queryParameters: {
        if (status != null) 'status': status,
        if (taskType != null) 'taskType': taskType,
      },
    );
  }

  Future<Response> getTeamTasks({String? branchId, String? status}) async {
    return _dio.get(
      '/crm/tasks/team-tasks',
      queryParameters: {
        if (branchId != null) 'branchId': branchId,
        if (status != null) 'status': status,
      },
    );
  }

  Future<Response> completeTask(
    String taskId, {
    required String actionType,
    String? outcome,
    Map<String, dynamic>? payload,
  }) async {
    return _dio.post(
      '/crm/tasks/$taskId/complete',
      data: {
        'actionType': actionType,
        if (outcome != null) 'outcome': outcome,
        if (payload != null) 'payload': payload,
      },
    );
  }

  Future<Response> getCrmNotifications() async =>
      _dio.get('/crm/notifications');

  Future<Response> markNotificationRead(String id) async =>
      _dio.post('/crm/notifications/$id/read');

  Future<Response> startTask(String taskId) async =>
      _dio.post('/crm/tasks/$taskId/start');

  Future<Response> rescheduleTask(
    String taskId,
    String dueDateTime, {
    String? reason,
  }) async => _dio.post(
    '/crm/tasks/$taskId/reschedule',
    data: {'dueDateTime': dueDateTime, if (reason != null) 'reason': reason},
  );

  Future<Response> cancelTask(String taskId, {String? reason}) async =>
      _dio.post(
        '/crm/tasks/$taskId/cancel',
        data: {if (reason != null) 'reason': reason},
      );

  Future<Response> getTaskById(String taskId) async =>
      _dio.get('/crm/tasks/$taskId');

  Future<Response> getTimeline(String leadId) async =>
      _dio.get('/crm/timeline/$leadId');

  Future<Response> getOverdueTasks({String? branchId}) async => _dio.get(
    '/crm/tasks/overdue',
    queryParameters: {if (branchId != null) 'branchId': branchId},
  );

  // ─── CRM Master Data ───

  Future<Response> getMasterActiveList(
    String masterType, {
    String? parentId,
  }) async => _dio.get(
    '/crm/masters/$masterType/active',
    queryParameters: {if (parentId != null) 'parentId': parentId},
  );

  Future<Response> getMasters(String masterType, {String? search}) async =>
      _dio.get(
        '/crm/masters/$masterType',
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );

  // ─── Team Mapping ───

  /// GET /users/seniors  — users who have at least one team member
  Future<Response> getSeniors() async => _dio.get('/users/seniors');

  /// GET /users/:id/team  — get all users under a senior
  Future<Response> getTeamUnderSenior(String seniorId) async =>
      _dio.get('/users/$seniorId/team');

  /// GET /ai-insights?userId=:id  — get calls/analysis for a specific user
  Future<Response> getTeamMemberCalls(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    return _dio.get(
      '/ai-insights',
      queryParameters: {'userId': userId, 'page': page, 'limit': limit},
    );
  }

  // ─── Generic CRUD ───

  /// POST /notifications/register-token — register FCM token
  Future<Response> registerFcmToken(String token) async {
    return _dio.post(
      '/notifications/register-token',
      data: {'token': token, 'platform': 'android'},
    );
  }

  /// POST /notifications/unregister-token — unregister FCM token
  Future<Response> unregisterFcmToken(String token) async {
    return _dio.post('/notifications/unregister-token', data: {'token': token});
  }

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

  /// POST /calls/bulk-download — download multiple recordings as zip (or single file)
  Future<Response> bulkDownloadRecordings(List<String> callIds) async {
    return _dio.post(
      '/calls/bulk-download',
      data: {'callIds': callIds},
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// POST /ai-insights/report/merged-pdf — download merged PDF for customer calls
  Future<Response> downloadMergedPdf(
    List<String> callIds, {
    bool includeAnalysis = true,
    bool includeTranscription = false,
  }) async {
    return _dio.post(
      '/ai-insights/report/merged-pdf',
      data: {
        'callIds': callIds,
        'includeAnalysis': includeAnalysis,
        'includeTranscription': includeTranscription,
      },
      options: Options(responseType: ResponseType.bytes),
    );
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

  // ─── Modules ───

  Future<Response> getModules() async => _dio.get('/modules');

  Future<Response> updateModuleStatus(String id, String status) async =>
      _dio.patch('/modules/$id/status/$status');

  // ─── Operations ───

  Future<Response> getOperations() async => _dio.get('/operations');

  Future<Response> updateOperationStatus(String id, String status) async =>
      _dio.patch('/operations/$id/status/$status');

  // ─── Permissions (full CRUD) ───

  Future<Response> createPermission({
    required String name,
    required String moduleId,
    required String operationId,
  }) async {
    return _dio.post('/permissions', data: {
      'name': name,
      'moduleId': moduleId,
      'operationId': operationId,
    });
  }

  Future<Response> updatePermission(
    String id,
    Map<String, dynamic> data,
  ) async => _dio.patch('/permissions/$id', data: data);

  Future<Response> updatePermissionStatus(String id, String status) async =>
      _dio.patch('/permissions/$id/status/$status');

  Future<Response> deletePermission(String id) async =>
      _dio.delete('/permissions/$id');

  Future<Response> getGroupedPermissions() async =>
      _dio.get('/permissions/grouped');

  // ─── LLM Config ───

  Future<Response> getLlmTemplates({
    String? companyId,
    String? stage,
  }) async {
    return _dio.get('/llm-config/templates', queryParameters: {
      if (companyId != null) 'companyId': companyId,
      if (stage != null) 'stage': stage,
    });
  }

  Future<Response> getLlmProviders() async =>
      _dio.get('/llm-config/providers');

  Future<Response> createLlmTemplate(Map<String, dynamic> data) async =>
      _dio.post('/llm-config/templates', data: data);

  Future<Response> updateLlmTemplate(
    String id,
    Map<String, dynamic> data,
  ) async => _dio.put('/llm-config/templates/$id', data: data);

  Future<Response> deleteLlmTemplate(String id) async =>
      _dio.delete('/llm-config/templates/$id');

  Future<Response> getLlmStageConfigs(String companyId) async =>
      _dio.get('/llm-config/stages/$companyId');

  Future<Response> getLlmLogs(String companyId, {String? stage, int limit = 50}) async {
    return _dio.get('/llm-config/logs/$companyId', queryParameters: {
      if (stage != null) 'stage': stage,
      'limit': limit,
    });
  }

  // ─── Call Report ───

  Future<Response> getCallReportDaily({
    String? fromDate,
    String? toDate,
    String? companyId,
  }) async {
    return _dio.get('/ai-insights/report/daily', queryParameters: {
      if (fromDate != null) 'fromDate': fromDate,
      if (toDate != null) 'toDate': toDate,
      if (companyId != null) 'companyId': companyId,
    });
  }

  Future<Response> getCallReportDailyDetail(
    String date, {
    String? userId,
    String? companyId,
  }) async {
    return _dio.get('/ai-insights/report/daily/$date', queryParameters: {
      if (userId != null) 'userId': userId,
      if (companyId != null) 'companyId': companyId,
    });
  }

  Future<Response> getCallReportGrouped({
    String? fromDate,
    String? toDate,
    String? userId,
    String? companyId,
  }) async {
    return _dio.get('/ai-insights/report/grouped', queryParameters: {
      if (fromDate != null) 'fromDate': fromDate,
      if (toDate != null) 'toDate': toDate,
      if (userId != null) 'userId': userId,
      if (companyId != null) 'companyId': companyId,
    });
  }

  // ─── Employee Performance ───

  Future<Response> getEmployeePerformance({
    int page = 1,
    int limit = 20,
    String? search,
    String? fromDate,
    String? toDate,
    String? sortBy,
    String? sortOrder,
  }) async {
    return _dio.get('/employee-performance', queryParameters: {
      'page': page,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
      if (fromDate != null) 'fromDate': fromDate,
      if (toDate != null) 'toDate': toDate,
      if (sortBy != null) 'sortBy': sortBy,
      if (sortOrder != null) 'sortOrder': sortOrder,
    });
  }

  Future<Response> getEmployeePerformanceDetail(
    String userId, {
    String? fromDate,
    String? toDate,
  }) async {
    return _dio.get('/employee-performance/$userId', queryParameters: {
      if (fromDate != null) 'fromDate': fromDate,
      if (toDate != null) 'toDate': toDate,
    });
  }

  // ─── Sales Performance Report ───

  Future<Response> getSalesPerformanceSummary({
    int page = 1,
    int limit = 20,
    String? fromDate,
    String? toDate,
    String? branchId,
    String? search,
  }) async {
    return _dio.get('/sales-performance-report/summary', queryParameters: {
      'page': page,
      'limit': limit,
      if (fromDate != null) 'fromDate': fromDate,
      if (toDate != null) 'toDate': toDate,
      if (branchId != null) 'branchId': branchId,
      if (search != null && search.isNotEmpty) 'search': search,
    });
  }

  Future<Response> getSalesPerformanceFunnel({
    String? fromDate,
    String? toDate,
    String? branchId,
  }) async {
    return _dio.get('/sales-performance-report/lead-conversion-funnel',
        queryParameters: {
      if (fromDate != null) 'fromDate': fromDate,
      if (toDate != null) 'toDate': toDate,
      if (branchId != null) 'branchId': branchId,
    });
  }

  Future<Response> getSalesPerformanceCallMetrics({
    String? fromDate,
    String? toDate,
    String? branchId,
  }) async {
    return _dio.get('/sales-performance-report/call-recording-metrics',
        queryParameters: {
      if (fromDate != null) 'fromDate': fromDate,
      if (toDate != null) 'toDate': toDate,
      if (branchId != null) 'branchId': branchId,
    });
  }

  // ─── Team Report ───

  Future<Response> getTeamReport({
    String? branchId,
    String? fromDate,
    String? toDate,
  }) async {
    return _dio.get('/employee-performance/team-report', queryParameters: {
      if (branchId != null) 'branchId': branchId,
      if (fromDate != null) 'fromDate': fromDate,
      if (toDate != null) 'toDate': toDate,
    });
  }

  // ─── Prompt Settings ───

  Future<Response> getMyPrompt() async => _dio.get('/my-prompt');

  Future<Response> updateMyPrompt(Map<String, dynamic> data) async =>
      _dio.put('/my-prompt', data: data);

  // ─── WA Settings ───

  Future<Response> getWaSettings() async => _dio.get('/settings/wa');

  Future<Response> updateWaSettings({
    String? waAuditNumber,
    bool? waAutoSendEnabled,
  }) async {
    return _dio.patch('/settings/wa', data: {
      if (waAuditNumber != null) 'waAuditNumber': waAuditNumber,
      if (waAutoSendEnabled != null) 'waAutoSendEnabled': waAutoSendEnabled,
    });
  }

  // ─── CRM v2 Contacts ───

  Future<Response> createCrmContact({
    required String name,
    String? phone,
    String? email,
    String? alternatePhone,
    String? companyName,
    String? source,
    String? lifecycleStage,
    String? profession,
    String? address,
    String? city,
    String? state,
  }) async {
    return _dio.post('/crm/contacts', data: {
      'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
      if (alternatePhone != null && alternatePhone.isNotEmpty)
        'alternatePhone': alternatePhone,
      if (companyName != null && companyName.isNotEmpty)
        'companyName': companyName,
      if (source != null && source.isNotEmpty) 'source': source,
      if (lifecycleStage != null && lifecycleStage.isNotEmpty)
        'lifecycleStage': lifecycleStage,
      if (profession != null && profession.isNotEmpty) 'profession': profession,
      if (address != null && address.isNotEmpty) 'address': address,
      if (city != null && city.isNotEmpty) 'city': city,
      if (state != null && state.isNotEmpty) 'state': state,
    });
  }

  Future<Response> updateCrmContact(
    String id,
    Map<String, dynamic> data,
  ) async => _dio.patch('/crm/contacts/$id', data: data);

  Future<Response> deleteCrmContact(String id) async =>
      _dio.delete('/crm/contacts/$id');

  Future<Response> getCrmContact(String id) async =>
      _dio.get('/crm/contacts/$id');

  // ─── CRM v2 Deals ───

  Future<Response> createCrmDeal({
    required String name,
    required String contactId,
    required String pipelineId,
    required String stageId,
    double? expectedValue,
    String? closeDate,
    String? priority,
    String? ownerUserId,
    String? branchId,
  }) async {
    return _dio.post('/crm/deals', data: {
      'name': name,
      'contactId': contactId,
      'pipelineId': pipelineId,
      'stageId': stageId,
      if (expectedValue != null) 'expectedValue': expectedValue,
      if (closeDate != null) 'closeDate': closeDate,
      if (priority != null) 'priority': priority,
      if (ownerUserId != null) 'ownerUserId': ownerUserId,
      if (branchId != null) 'branchId': branchId,
    });
  }

  Future<Response> moveCrmDealStage(String id, String stageId) async =>
      _dio.patch('/crm/deals/$id/stage', data: {'stageId': stageId});

  Future<Response> markDealWon(String id) async =>
      _dio.post('/crm/deals/$id/won');

  Future<Response> markDealLost(String id, {String? lostReason}) async =>
      _dio.post('/crm/deals/$id/lost', data: {
        if (lostReason != null && lostReason.isNotEmpty)
          'lostReason': lostReason,
      });

  Future<Response> deleteCrmDeal(String id) async =>
      _dio.delete('/crm/deals/$id');

  Future<Response> getCrmPipelines() async => _dio.get('/crm/pipelines');

  Future<Response> getCrmPipeline(String id) async =>
      _dio.get('/crm/pipelines/$id');

  // ─── CRM v2 Activities ───

  Future<Response> getCrmActivities({
    int page = 1,
    int limit = 30,
    String? type,
    String? fromDate,
    String? toDate,
    String? dealId,
    String? contactId,
  }) async {
    return _dio.get('/crm/activities', queryParameters: {
      'page': page,
      'limit': limit,
      if (type != null && type.isNotEmpty) 'type': type,
      if (fromDate != null) 'fromDate': fromDate,
      if (toDate != null) 'toDate': toDate,
      if (dealId != null) 'dealId': dealId,
      if (contactId != null) 'contactId': contactId,
    });
  }

  Future<Response> createCrmActivityLog({
    required String type,
    String? contactId,
    String? dealId,
    String? title,
    String? notes,
    String? outcome,
    String? dueDate,
  }) async {
    return _dio.post('/crm/activities', data: {
      'type': type,
      if (contactId != null) 'contactId': contactId,
      if (dealId != null) 'dealId': dealId,
      if (title != null && title.isNotEmpty) 'title': title,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (outcome != null && outcome.isNotEmpty) 'outcome': outcome,
      if (dueDate != null) 'dueDate': dueDate,
    });
  }

  Future<Response> updateCrmActivity(
    String id,
    Map<String, dynamic> data,
  ) async => _dio.patch('/crm/activities/$id', data: data);

  // ─── CRM v2 Custom Properties ───

  Future<Response> getCrmProperties({String? objectType}) async {
    return _dio.get('/crm/properties', queryParameters: {
      if (objectType != null) 'objectType': objectType,
    });
  }

  Future<Response> createCrmProperty({
    required String name,
    required String fieldKey,
    required String fieldType,
    required String objectType,
    String? description,
    List<String>? options,
    String? groupName,
    bool isRequired = false,
  }) async {
    return _dio.post('/crm/properties', data: {
      'name': name,
      'fieldKey': fieldKey,
      'fieldType': fieldType,
      'objectType': objectType,
      if (description != null && description.isNotEmpty) 'description': description,
      if (options != null && options.isNotEmpty) 'options': options,
      if (groupName != null && groupName.isNotEmpty) 'groupName': groupName,
      'isRequired': isRequired,
    });
  }

  Future<Response> updateCrmProperty(
    String id,
    Map<String, dynamic> data,
  ) async => _dio.patch('/crm/properties/$id', data: data);

  Future<Response> deleteCrmProperty(String id) async =>
      _dio.delete('/crm/properties/$id');

  // ─── CRM v2 Pipeline Management ───

  Future<Response> createCrmPipeline({
    required String name,
    bool isDefault = false,
  }) async {
    return _dio.post('/crm/pipelines', data: {
      'name': name,
      'isDefault': isDefault,
    });
  }

  Future<Response> addCrmPipelineStage(
    String pipelineId, {
    required String name,
    String type = 'OPEN',
    int? slaDays,
    double? winProbability,
  }) async {
    return _dio.post('/crm/pipelines/$pipelineId/stages', data: {
      'name': name,
      'type': type,
      if (slaDays != null) 'slaDays': slaDays,
      if (winProbability != null) 'winProbability': winProbability,
    });
  }

  Future<Response> updateCrmPipelineStage(
    String pipelineId,
    String stageId,
    Map<String, dynamic> data,
  ) async => _dio.patch('/crm/pipelines/$pipelineId/stages/$stageId', data: data);

  Future<Response> deleteCrmPipeline(String id) async =>
      _dio.delete('/crm/pipelines/$id');

  // ─── CRM v2 Follow-ups by Contact ───

  Future<Response> getCrmFollowUpsByContact(String contactId) async {
    return _dio.get('/crm/follow-ups', queryParameters: {'contactId': contactId});
  }

  // ─── Analytics Compare (User 360°) ───

  Future<Response> getAnalyticsUser360({
    required List<String> userIds,
    String period = '30d',
    String? categoryId,
  }) async {
    return _dio.get('/analytics/user-360', queryParameters: {
      'userIds': userIds.join(','),
      'period': period,
      if (categoryId != null) 'categoryId': categoryId,
    });
  }
}
