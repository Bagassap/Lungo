import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: false,
    ),
  );

  static const _keyAccessToken          = 'access_token';
  static const _keyRefreshToken         = 'refresh_token';
  static const _keyUserId               = 'user_id';
  static const _keyUserPhone            = 'user_phone';
  static const _keyUserName             = 'user_name';
  static const _keyUserRole             = 'user_role';
  static const _keySubscriptionPaidUntil = 'subscription_paid_until';

  static const _keyDriverRideId    = 'driver_active_ride_id';

  static const _keyPassengerRideId = 'passenger_active_ride_id';

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    await Future.wait([
      _storage.write(key: _keyAccessToken,  value: accessToken),
      _storage.write(key: _keyRefreshToken, value: refreshToken),
      _storage.write(key: _keyUserId,       value: userId),
    ]);
  }

  static Future<void> saveAccessToken(String token) =>
      _storage.write(key: _keyAccessToken, value: token);

  static Future<String?> getAccessToken()  => _storage.read(key: _keyAccessToken);
  static Future<String?> getRefreshToken() => _storage.read(key: _keyRefreshToken);
  static Future<String?> getUserId()       => _storage.read(key: _keyUserId);

  static Future<void> saveUserProfile({required String phone, required String name}) async {
    await Future.wait([
      _storage.write(key: _keyUserPhone, value: phone),
      _storage.write(key: _keyUserName,  value: name),
    ]);
  }

  static Future<String?> getUserPhone() => _storage.read(key: _keyUserPhone);
  static Future<String?> getUserName()  => _storage.read(key: _keyUserName);

  static Future<void> saveRole(String role) =>
      _storage.write(key: _keyUserRole, value: role);
  static Future<String?> getRole() => _storage.read(key: _keyUserRole);

  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> saveSubscriptionPaidUntil(DateTime date) =>
      _storage.write(key: _keySubscriptionPaidUntil, value: date.toIso8601String());

  static Future<DateTime?> getSubscriptionPaidUntil() async {
    final val = await _storage.read(key: _keySubscriptionPaidUntil);
    if (val == null) return null;
    return DateTime.tryParse(val);
  }

  static Future<bool> isSubscriptionActive() async {
    final until = await getSubscriptionPaidUntil();
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  static Future<void> saveDriverRideId(String rideId) =>
      _storage.write(key: _keyDriverRideId, value: rideId);

  static Future<String?> getDriverRideId() =>
      _storage.read(key: _keyDriverRideId);

  static Future<void> clearDriverRideId() =>
      _storage.delete(key: _keyDriverRideId);

  static Future<void> savePassengerRideId(String rideId) =>
      _storage.write(key: _keyPassengerRideId, value: rideId);

  static Future<String?> getPassengerRideId() =>
      _storage.read(key: _keyPassengerRideId);

  static Future<void> clearPassengerRideId() =>
      _storage.delete(key: _keyPassengerRideId);

  static Future<void> clearAll() => _storage.deleteAll();

  static Future<void> clear() => _storage.deleteAll();
}
