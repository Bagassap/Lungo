import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;
  final String? pendingPhone;
  final String? pendingOtp;
  final bool multipleRoles;
  final List<String> availableRoles;
  final String? tempToken;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.pendingPhone,
    this.pendingOtp,
    this.multipleRoles = false,
    this.availableRoles = const [],
    this.tempToken,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
    String? pendingPhone,
    String? pendingOtp,
    bool? multipleRoles,
    List<String>? availableRoles,
    String? tempToken,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        errorMessage: errorMessage,
        pendingPhone: pendingPhone ?? this.pendingPhone,
        pendingOtp: pendingOtp ?? this.pendingOtp,
        multipleRoles: multipleRoles ?? this.multipleRoles,
        availableRoles: availableRoles ?? this.availableRoles,
        tempToken: tempToken ?? this.tempToken,
      );

  bool get isLoggedIn =>
      status == AuthStatus.authenticated &&
      user != null &&
      user!.name.isNotEmpty &&
      user!.role.isNotEmpty;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _service;

  AuthNotifier(this._service) : super(const AuthState());

  Future<void> refreshProfile() async {
    try {
      final user = await _service.getProfile();
      state = state.copyWith(user: user);
    } catch (_) {}
  }

  Future<void> checkSession() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final loggedIn = await SecureStorage.isLoggedIn();
      if (!loggedIn) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }

      try {
        await _service.refreshToken();
      } catch (_) {}

      final user = await _service.getProfile();
      if (user.name.isEmpty || user.role.isEmpty) {
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
        return;
      }
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      FcmService.registerTokenAfterLogin();
    } catch (e) {

      bool isAuthError = false;
      if (e is DioException) {
        final code = e.response?.statusCode ?? 0;
        isAuthError = (code == 401 || code == 403);
      }
      if (isAuthError) {
        final hasActiveRide =
            (await SecureStorage.getPassengerRideId()) != null ||
            (await SecureStorage.getDriverRideId()) != null;
        if (!hasActiveRide) {
          await SecureStorage.clear();
        }
      }
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<({bool success, bool isNewUser})> quickLogin(String phone) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final result = await _service.quickLogin(phone);
      state = state.copyWith(status: AuthStatus.authenticated, user: result.user);
      FcmService.registerTokenAfterLogin();
      return (success: true, isNewUser: false);
    } catch (_) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return (success: false, isNewUser: false);
    }
  }

  Future<({bool success, bool isNewUser})> requestOtp(String phone) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final result = await _service.sendOtp(phone);
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        pendingPhone: phone,
        pendingOtp: result.otp,
      );
      return (success: true, isNewUser: result.isNewUser);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _parseError(e),
      );
      return (success: false, isNewUser: false);
    }
  }

  Future<({bool success, bool isNewUser, bool multipleRoles})> verifyOtp(String otp) async {
    state = state.copyWith(status: AuthStatus.loading);
    final phone = state.pendingPhone ?? '';
    try {
      final result = await _service.verifyOtp(phone: phone, otp: otp);
      if (result.multipleRoles) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          multipleRoles: true,
          availableRoles: result.availableRoles,
          tempToken: result.tempToken,
        );
        return (success: true, isNewUser: false, multipleRoles: true);
      }
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: result.user,
        multipleRoles: false,
      );
      FcmService.registerTokenAfterLogin();
      return (success: true, isNewUser: result.isNewUser, multipleRoles: false);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _parseError(e),
      );
      return (success: false, isNewUser: false, multipleRoles: false);
    }
  }

  Future<bool> selectRole(String role) async {
    state = state.copyWith(status: AuthStatus.loading);
    final phone     = state.pendingPhone ?? '';
    final tempToken = state.tempToken    ?? '';
    try {
      final result = await _service.selectRole(
        phone: phone, role: role, tempToken: tempToken);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: result.user,
        multipleRoles: false,
      );
      FcmService.registerTokenAfterLogin();
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _parseError(e),
      );
      return false;
    }
  }

  Future<bool> completeRegistration({
    required String name,
    required String role,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _service.completeRegistration(name: name, role: role);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      FcmService.registerTokenAfterLogin();
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _parseError(e),
      );
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String role,
    String? vehicleType,
    String? vehiclePlate,
  }) async {
    final phone = state.user?.phone ?? state.pendingPhone ?? '';
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _service.register(
        phone: phone,
        name: name,
        role: role,
        vehicleType: vehicleType,
        vehiclePlate: vehiclePlate,
      );
      final user = await _service.getProfile();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _parseError(e),
      );
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _service.logout();
    } catch (_) {
    } finally {
      await SecureStorage.clearAll();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  String _parseError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['message'];
        if (msg is String && msg.isNotEmpty) return msg;
        if (msg is List && msg.isNotEmpty) return msg.first.toString();
      }
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Koneksi timeout, periksa jaringan internet';
        case DioExceptionType.connectionError:
          return 'Tidak dapat terhubung ke server, periksa jaringan';
        default:
          return e.message ?? 'Terjadi kesalahan, coba lagi';
      }
    }
    if (e is Exception) return e.toString().replaceAll('Exception: ', '');
    return 'Terjadi kesalahan, coba lagi';
  }
}

final authServiceProvider = Provider<AuthService>((_) => AuthService());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(authServiceProvider)),
);
