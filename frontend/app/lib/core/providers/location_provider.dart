import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class LocationState {
  final double? lat;
  final double? lng;
  final bool loaded;
  const LocationState({this.lat, this.lng, this.loaded = false});
}

class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier() : super(const LocationState());

  Future<void> init() async {
    try {
      final svc = await Geolocator.isLocationServiceEnabled();
      if (!svc) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      state = LocationState(lat: pos.latitude, lng: pos.longitude, loaded: true);
    } catch (_) {}
  }

  void update(double lat, double lng) {
    state = LocationState(lat: lat, lng: lng, loaded: true);
  }
}

final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>(
  (ref) => LocationNotifier(),
);
