import 'package:dio/dio.dart';
import 'auth_service.dart';

class ApiService {
  // Backend runs on port 3000, no /api prefix
  // For Android emulator use 10.0.2.2, for real device use your machine IP
  // static const String baseUrl = 'https://api.mysterymentor.in';
  static const String baseUrl = 'http://192.168.137.1:3000';


  late final Dio _dio;
  final AuthService _auth = AuthService();

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120), // 2 min for large audio uploads
      sendTimeout: const Duration(seconds: 120),    // 2 min for large audio uploads
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _auth.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  // ─── Auth ───

  /// POST /auth/login
  /// Response: { success, message, data: { user, token, allowedModules, companyUsers? } }
  Future<Response> login(String email, String password) async {
    return _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
  }

  /// POST /auth/register
  Future<Response> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
  }) async {
    return _dio.post('/auth/register', data: {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'password': password,
      if (phone != null) 'phone': phone,
    });
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
    return _dio.patch('/auth/profile', data: {
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
    });
  }

  /// PATCH /auth/change-password
  Future<Response> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return _dio.patch('/auth/change-password', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
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
      if (salesStageId != null && salesStageId.isNotEmpty) 'salesStageId': salesStageId,
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

  // ─── Categories ───

  /// GET /categories
  Future<Response> getCategories() async {
    return _dio.get('/categories');
  }

  // ─── Sales Stages ───

  /// GET /sales-stages
  Future<Response> getSalesStages() async {
    return _dio.get('/sales-stages');
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

  /// GET /users
  Future<Response> getUsers() async {
    return _dio.get('/users');
  }

  /// GET /users/:id
  Future<Response> getUser(String id) async {
    return _dio.get('/users/$id');
  }

  /// GET /users/me/sop — returns { sopId, categoryId, salesStageId }
  Future<Response> getMySop() async {
    return _dio.get('/users/me/sop');
  }

  // ─── Companies ───

  /// GET /companies/my-company/details
  Future<Response> getMyCompany() async {
    return _dio.get('/companies/my-company/details');
  }
}
