import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

class LocationService {
  io.Socket? _socket;
  Timer? _timer;
  bool _running = false;

  bool get isRunning => _running;

  Future<bool> _checkPermission() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  Future<void> start(String driverId) async {
    if (_running) return;

    final granted = await _checkPermission();
    if (!granted) {
      return;
    }

    final token = await SecureStorage.getAccessToken();
    _socket = io.io(
      '${ApiConstants.wsUrl}${ApiConstants.trackingNamespace}',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );
    _socket?.connect();
    _running = true;

    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _socket?.emit('updateLocation', {
          'driverId': driverId,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
        });
        debugPrint(
            '[LocationService] ${pos.latitude}, ${pos.longitude}');
      } catch (_) {}
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _socket?.disconnect();
    _socket = null;
    _running = false;
  }
}
