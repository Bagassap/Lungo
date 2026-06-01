import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/user_model.dart';

class AuthService {
  final Dio _dio = ApiClient.create();

  Future<({bool isNewUser, String otp})> sendOtp(String phone) async {
    final resp = await _dio.post('/auth/send-otp', data: {'phone': phone});
    final data = Map<String, dynamic>.from(resp.data as Map);
    return (
      isNewUser: data['isNewUser'] as bool? ?? false,
      otp: data['otp'] as String? ?? '',
    );
  }

  Future<({UserModel user})> selectRole({
    required String phone,
    required String role,
    required String tempToken,
  }) async {
    final resp = await _dio.post('/auth/select-role', data: {
      'phone': phone,
      'role': role,
      'tempToken': tempToken,
    });
    final data = Map<String, dynamic>.from(resp.data as Map);
    final accessToken  = data['accessToken'].toString();
    final refreshToken = data['refreshToken'].toString();
    final user = UserModel.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    await SecureStorage.saveTokens(
      accessToken: accessToken, refreshToken: refreshToken, userId: user.id);
    await SecureStorage.saveUserProfile(phone: user.phone, name: user.name);
    if (user.role.isNotEmpty) await SecureStorage.saveRole(user.role);
    return (user: user);
  }

  Future<UserModel> completeRegistration({
    required String name,
    required String role,
  }) async {
    final resp = await _dio.post('/auth/complete-registration', data: {
      'name': name,
      'role': role,
    });
    final data = Map<String, dynamic>.from(resp.data as Map);
    final user = UserModel.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    await SecureStorage.saveUserProfile(phone: user.phone, name: user.name);
    if (user.role.isNotEmpty) await SecureStorage.saveRole(user.role);
    return user;
  }

  Future<String> register({
    required String phone,
    required String name,
    required String role,
    String? vehicleType,
    String? vehiclePlate,
  }) async {
    final body = <String, dynamic>{'phone': phone, 'name': name, 'role': role};
    if (vehicleType  != null) body['vehicleType']  = vehicleType;
    if (vehiclePlate != null) body['vehiclePlate'] = vehiclePlate;
    final resp = await _dio.post('/auth/register', data: body);
    return resp.data['otp'] as String? ?? '';
  }

  Future<void> requestOtp(String phone) async {
    await _dio.post('/auth/login', data: {'phone': phone});
  }

  Future<({
    UserModel? user,
    bool isNewUser,
    bool multipleRoles,
    List<String> availableRoles,
    String tempToken,
  })> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final resp = await _dio.post('/auth/verify-otp', data: {'phone': phone, 'otp': otp});
    final data = Map<String, dynamic>.from(resp.data as Map);

    if (data['multipleRoles'] == true) {
      final roles = (data['availableRoles'] as List).cast<String>();
      return (
        user: null,
        isNewUser: false,
        multipleRoles: true,
        availableRoles: roles,
        tempToken: data['tempToken'] as String? ?? '',
      );
    }

    final accessToken  = data['accessToken'].toString();
    final refreshToken = data['refreshToken'].toString();
    final isNewUser    = data['isNewUser'] as bool? ?? false;
    final user = UserModel.fromJson(Map<String, dynamic>.from(data['user'] as Map));

    await SecureStorage.saveTokens(
      accessToken: accessToken, refreshToken: refreshToken, userId: user.id);
    await SecureStorage.saveUserProfile(phone: user.phone, name: user.name);
    if (user.role.isNotEmpty) await SecureStorage.saveRole(user.role);

    return (
      user: user,
      isNewUser: isNewUser,
      multipleRoles: false,
      availableRoles: const <String>[],
      tempToken: '',
    );
  }

  Future<({UserModel user, bool isNewUser})> quickLogin(String phone) async {
    final resp = await _dio.post('/auth/quick-login', data: {'phone': phone});
    final data = Map<String, dynamic>.from(resp.data as Map);
    final accessToken = data['accessToken'].toString();
    final refreshToken = data['refreshToken'].toString();
    final user = UserModel.fromJson(Map<String, dynamic>.from(data['user'] as Map));

    await SecureStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: user.id,
    );
    await SecureStorage.saveUserProfile(phone: user.phone, name: user.name);
    if (user.role.isNotEmpty) await SecureStorage.saveRole(user.role);

    return (user: user, isNewUser: false);
  }

  Future<void> refreshToken() async {
    final userId = await SecureStorage.getUserId();
    final token  = await SecureStorage.getRefreshToken();
    if (userId == null || token == null) throw Exception('no_refresh_token');
    final resp = await Dio(BaseOptions(baseUrl: ApiClient.wsBaseUrl)).post(
      '/auth/refresh',
      data: {'userId': userId, 'refreshToken': token},
    );
    final newAccess = resp.data['accessToken'] as String?;
    if (newAccess == null) throw Exception('refresh_failed');
    await SecureStorage.saveAccessToken(newAccess);
  }

  Future<UserModel> getProfile() async {
    final resp = await _dio.get('/users/profile');
    return UserModel.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } finally {
      await SecureStorage.clear();
    }
  }
}
