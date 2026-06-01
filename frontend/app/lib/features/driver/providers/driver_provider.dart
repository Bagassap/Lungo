import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;
import '../../../core/network/api_client.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/here_service.dart';
import '../../../core/storage/secure_storage.dart';

enum DriverRidePhase { idle, request, navigating, atPickup, onTrip, completed }

class DriverRideRequest {
  final String rideId;
  final double originLat, originLng;
  final double destinationLat, destinationLng;
  final String? originAddress, destinationAddress;
  final double distanceKm, estimatedFare;
  final String? passengerName;
  final double passengerRating;

  const DriverRideRequest({
    required this.rideId,
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
    this.originAddress,
    this.destinationAddress,
    required this.distanceKm,
    required this.estimatedFare,
    this.passengerName,
    this.passengerRating = 5.0,
  });
}

class DriverArgo {
  final double distanceKm, durationMinutes, fare;
  const DriverArgo({
    required this.distanceKm,
    required this.durationMinutes,
    required this.fare,
  });
}

class DriverTrip {
  final String rideId;
  final double originLat, originLng;
  final double destinationLat, destinationLng;
  final String? originAddress, destinationAddress;
  final String? passengerName;

  const DriverTrip({
    required this.rideId,
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
    this.originAddress,
    this.destinationAddress,
    this.passengerName,
  });

  bool get hasDestination =>
      destinationLat != 0.0 || destinationLng != 0.0;

  String get displayPassengerName =>
      (passengerName?.isNotEmpty == true) ? passengerName! : 'Penumpang';

  String get displayDestinationAddress =>
      (destinationAddress?.isNotEmpty == true) ? destinationAddress! : 'Tujuan tidak diset';
}

class HotZone {
  final String id, name, demand;
  final double lat, lng;
  final int requestCount;

  const HotZone({
    required this.id,
    required this.name,
    required this.demand,
    required this.lat,
    required this.lng,
    required this.requestCount,
  });

  factory HotZone.fromJson(Map<String, dynamic> j) => HotZone(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    demand: j['demand'] as String? ?? 'low',
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    requestCount: (j['requestCount'] as num?)?.toInt() ?? 0,
  );
}

class DriverState {
  final bool isOnline;
  final bool isLoading;
  final DriverRidePhase phase;
  final LatLng? position;
  final DriverRideRequest? pendingRequest;
  final DriverTrip? activeTrip;
  final DriverArgo? argo;
  final int todayTrips;
  final double todayEarnings;
  final double todayKm;
  final double todayTarget;
  final double rating;
  final String? completedRideId;
  final List<HotZone> hotZones;
  final bool bonusActive;
  final int bonusAmount;
  final List<LatLng> routePoints;
  final bool cancelRequested;
  final String? cancelRequestRideId;
  final LatLng? passengerPosition;

  const DriverState({
    this.isOnline = false,
    this.isLoading = false,
    this.phase = DriverRidePhase.idle,
    this.position,
    this.pendingRequest,
    this.activeTrip,
    this.argo,
    this.todayTrips = 0,
    this.todayEarnings = 0.0,
    this.todayKm = 0.0,
    this.todayTarget = 200000.0,
    this.rating = 5.0,
    this.completedRideId,
    this.hotZones = const [],
    this.bonusActive = false,
    this.bonusAmount = 0,
    this.routePoints = const [],
    this.cancelRequested = false,
    this.cancelRequestRideId,
    this.passengerPosition,
  });

  DriverState copyWith({
    bool? isOnline,
    bool? isLoading,
    DriverRidePhase? phase,
    LatLng? position,
    DriverRideRequest? pendingRequest,
    DriverTrip? activeTrip,
    DriverArgo? argo,
    int? todayTrips,
    double? todayEarnings,
    double? todayKm,
    double? todayTarget,
    double? rating,
    String? completedRideId,
    List<HotZone>? hotZones,
    bool? bonusActive,
    int? bonusAmount,
    List<LatLng>? routePoints,
    bool clearRequest = false,
    bool clearTrip = false,
    bool clearArgo = false,
    bool clearCompleted = false,
    bool clearRoute = false,
    bool? cancelRequested,
    String? cancelRequestRideId,
    bool clearCancelRequest = false,
    LatLng? passengerPosition,
    bool clearPassengerPosition = false,
  }) {
    return DriverState(
      isOnline: isOnline ?? this.isOnline,
      isLoading: isLoading ?? this.isLoading,
      phase: phase ?? this.phase,
      position: position ?? this.position,
      pendingRequest: clearRequest
          ? null
          : (pendingRequest ?? this.pendingRequest),
      activeTrip: clearTrip ? null : (activeTrip ?? this.activeTrip),
      argo: clearArgo ? null : (argo ?? this.argo),
      todayTrips: todayTrips ?? this.todayTrips,
      todayEarnings: todayEarnings ?? this.todayEarnings,
      todayKm: todayKm ?? this.todayKm,
      todayTarget: todayTarget ?? this.todayTarget,
      rating: rating ?? this.rating,
      completedRideId: clearCompleted
          ? null
          : (completedRideId ?? this.completedRideId),
      hotZones: hotZones ?? this.hotZones,
      bonusActive: bonusActive ?? this.bonusActive,
      bonusAmount: bonusAmount ?? this.bonusAmount,
      routePoints: clearRoute ? const [] : (routePoints ?? this.routePoints),
      cancelRequested: clearCancelRequest ? false : (cancelRequested ?? this.cancelRequested),
      cancelRequestRideId: clearCancelRequest ? null : (cancelRequestRideId ?? this.cancelRequestRideId),
      passengerPosition: clearPassengerPosition ? null : (passengerPosition ?? this.passengerPosition),
    );
  }
}

class DriverNotifier extends StateNotifier<DriverState> {
  DriverNotifier() : super(const DriverState()) {
    _loadInitialData();
  }

  sio.Socket? _socket;
  Timer? _gpsTimer;
  Timer? _demoMoveTimer;
  String? _driverUserId;
  bool _isRerouting = false;
  DateTime? _requestReceivedAt;
  final _dio = ApiClient.create();

  Future<void> _loadInitialData() async {
    await Future.wait([_loadHotZones(), _loadStats()]);
    await _restoreActiveTrip();
  }

  Future<void> _restoreActiveTrip() async {
    final rideId = await SecureStorage.getDriverRideId();
    if (rideId == null || rideId.isEmpty) return;
    try {
      _driverUserId ??= await SecureStorage.getUserId();
      final resp = await _dio.get('/booking/rides/$rideId');
      if (!mounted) return;
      final data = resp.data as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';
      if (status == 'ACCEPTED' || status == 'PICKUP' || status == 'ONGOING') {
        final passenger = data['passenger'] as Map<String, dynamic>?;
        final passengerName = passenger?['name'] as String? ?? 'Penumpang';
        final phase = status == 'ONGOING'
            ? DriverRidePhase.onTrip
            : status == 'PICKUP'
                ? DriverRidePhase.atPickup
                : DriverRidePhase.navigating;
        setState(state.copyWith(
          phase: phase,
          activeTrip: DriverTrip(
            rideId: rideId,
            originLat: (data['originLat'] as num).toDouble(),
            originLng: (data['originLng'] as num).toDouble(),
            destinationLat: (data['destinationLat'] as num).toDouble(),
            destinationLng: (data['destinationLng'] as num).toDouble(),
            originAddress: data['originAddress'] as String?,
            destinationAddress: data['destinationAddress'] as String?,
            passengerName: passengerName,
          ),
        ));
        debugPrint('[Driver] _restoreActiveTrip: phase=$phase rideId=$rideId dipulihkan');
        if (state.phase == DriverRidePhase.navigating ||
            state.phase == DriverRidePhase.atPickup ||
            state.phase == DriverRidePhase.onTrip) {
          debugPrint('[Driver] Trip aktif dipulihkan, reconnect socket...');
          if (_socket == null || !_socket!.connected) {
            unawaited(goOnline());
          }
        }
      } else {
        await SecureStorage.clearDriverRideId();
      }
    } catch (e) {
      debugPrint('[Driver] _restoreActiveTrip error: $e');
    }
  }

  Future<void> goOnline() async {
    debugPrint('[DRIVER] goOnline() dipanggil');
    setState(state.copyWith(isLoading: true));
    try {
      _driverUserId = await SecureStorage.getUserId();
      debugPrint('[DRIVER] driverUserId: $_driverUserId');

      final perm = await Geolocator.checkPermission();
      debugPrint('[DRIVER] GPS permission: $perm');
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final token = await SecureStorage.getAccessToken();
      final socketUrl = '${ApiClient.wsBaseUrl}/tracking';
      debugPrint('[DRIVER] Socket URL: $socketUrl');
      debugPrint('[DRIVER] Token ada: ${token != null && token.isNotEmpty}');

      _socket = sio.io(
        socketUrl,
        sio.OptionBuilder().setTransports(['websocket']).setExtraHeaders({
          'Authorization': 'Bearer $token',
        }).build(),
      );
      debugPrint('[DRIVER] sio.io() selesai, memanggil connect()...');
      _socket!.connect();
      debugPrint('[DRIVER] connect() dipanggil, menunggu onConnect...');

      _socket!.onConnect((_) async {
        debugPrint('[DRIVER] onConnect! Socket ID: ${_socket?.id}');
        final pos = await _currentPos();
        debugPrint('[DRIVER] GPS pos: lat=${pos.latitude} lng=${pos.longitude}');
        debugPrint('[DRIVER] Emitting driverOnline driverId=$_driverUserId...');
        _socket!.emit('driverOnline', {
          'driverId': _driverUserId,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
        });
        debugPrint('[DRIVER] driverOnline emitted!');
        // Re-join ride room if on active trip (handles socket reconnection)
        final currentTrip = state.activeTrip;
        if (currentTrip != null) {
          debugPrint('[DRIVER] Re-joining ride room: ${currentTrip.rideId}');
          _socket!.emit('joinRide', {'rideId': currentTrip.rideId});
        }
      });

      _socket!.onConnectError((err) {
        debugPrint('[DRIVER] onConnectError: $err');
      });

      _socket!.onDisconnect((_) {
        debugPrint('[DRIVER] onDisconnect — socket terputus');
      });

      _socket!.on('error', (err) {
        debugPrint('[DRIVER] onError: $err');
      });

      _socket!.on('newRideRequest', _onNewRideRequest);
      _socket!.on('rideAccepted', _onRideAccepted);
      _socket!.on('argoUpdate', _onArgoUpdate);
      _socket!.on('rideEnded', _onRideEnded);
      _socket!.on('rideCancelled', _onRideCancelled);
      _socket!.on('cancelRequest', _onCancelRequest);
      _socket!.on('passengerLocationUpdated', (data) {
        if (!mounted) return;
        final m = Map<String, dynamic>.from(data as Map);
        final lat = num.tryParse(m['latitude']?.toString() ?? '')?.toDouble();
        final lng = num.tryParse(m['longitude']?.toString() ?? '')?.toDouble();
        if (lat != null && lng != null) {
          setState(state.copyWith(passengerPosition: LatLng(lat, lng)));
        }
      });

      _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        if (!mounted) return;
        final pos = await _currentPos();
        final s = state;
        final newLatLng = LatLng(pos.latitude, pos.longitude);
        setState(s.copyWith(position: newLatLng));
        _socket?.emit('updateLocation', {
          'driverId': _driverUserId,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          if (s.activeTrip != null) 'rideId': s.activeTrip!.rideId,
        });

        // Auto-reroute when driver deviates >50 m from the planned route
        if (!_isRerouting &&
            s.routePoints.isNotEmpty &&
            s.activeTrip != null &&
            (s.phase == DriverRidePhase.onTrip ||
                s.phase == DriverRidePhase.navigating)) {
          double minDist = double.infinity;
          for (final pt in s.routePoints) {
            final d = Geolocator.distanceBetween(
                pos.latitude, pos.longitude, pt.latitude, pt.longitude);
            if (d < minDist) minDist = d;
          }
          if (minDist > 50) {
            _isRerouting = true;
            final trip = s.activeTrip!;
            final dest = s.phase == DriverRidePhase.navigating
                ? LatLng(trip.originLat, trip.originLng)
                : LatLng(trip.destinationLat, trip.destinationLng);
            await _fetchAndSetRoute(newLatLng, dest);
            _isRerouting = false;
          }
        }
      });

      await Future.wait([_loadStats(), _loadHotZones()]);
      debugPrint('[DRIVER] goOnline() try block selesai tanpa error');
    } catch (e, st) {
      debugPrint('[DRIVER] goOnline() EXCEPTION: $e');
      debugPrint('[DRIVER] StackTrace: $st');
    }
    setState(
      state.copyWith(
        isOnline: true,
        isLoading: false,
        // Do NOT reset phase here — newRideRequest may have already set it to
        // 'request' while _loadStats/_loadHotZones were awaiting.
      ),
    );
  }

  Future<void> goOffline() async {
    _requestReceivedAt = null;
    FcmService.setHasActivePendingRequest(false);
    _gpsTimer?.cancel();
    _demoMoveTimer?.cancel();
    _socket?.emit('driverOffline', {'driverId': _driverUserId});
    _socket?.disconnect();
    _socket = null;
    setState(
      state.copyWith(
        isOnline: false,
        phase: DriverRidePhase.idle,
        clearRequest: true,
        clearTrip: true,
        clearArgo: true,
        clearRoute: true,
      ),
    );
  }

  // Returns distance in km between two lat/lng points
  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  void _onNewRideRequest(dynamic data) {
    debugPrint('[DRIVER] newRideRequest diterima: $data');
    debugPrint('[DRIVER] phase saat ini: ${state.phase}');
    if (!mounted || state.phase != DriverRidePhase.idle) {
      debugPrint('[DRIVER] newRideRequest SKIP — mounted=$mounted phase=${state.phase}');
      return;
    }
    final d = Map<String, dynamic>.from(data as Map);

    // Client-side distance guard: ignore requests from >5 km away
    final pos = state.position;
    if (pos != null) {
      final originLat = (d['originLat'] as num).toDouble();
      final originLng = (d['originLng'] as num).toDouble();
      final distKm = _haversineKm(pos.latitude, pos.longitude, originLat, originLng);
      debugPrint('[DRIVER] newRideRequest jarak ke origin: ${distKm.toStringAsFixed(2)} km');
      if (distKm > 5.0) {
        debugPrint('[DRIVER] newRideRequest SKIP — jarak ${distKm.toStringAsFixed(2)} km > 5 km');
        return;
      }
    } else {
      debugPrint('[DRIVER] newRideRequest — pos null, skip distance guard');
    }

    final req = DriverRideRequest(
      rideId: d['rideId'] as String,
      originLat: (d['originLat'] as num).toDouble(),
      originLng: (d['originLng'] as num).toDouble(),
      destinationLat: (d['destinationLat'] as num).toDouble(),
      destinationLng: (d['destinationLng'] as num).toDouble(),
      originAddress: d['originAddress'] as String?,
      destinationAddress: d['destinationAddress'] as String?,
      distanceKm: (d['distanceKm'] as num).toDouble(),
      estimatedFare: (d['estimatedFare'] as num).toDouble(),
      passengerName: d['passengerName'] as String?,
      passengerRating: (d['passengerRating'] as num?)?.toDouble() ?? 5.0,
    );
    _requestReceivedAt = DateTime.now();
    setState(
      state.copyWith(phase: DriverRidePhase.request, pendingRequest: req),
    );
    FcmService.setHasActivePendingRequest(true);
  }

  void _onRideAccepted(dynamic data) {}

  void _onArgoUpdate(dynamic data) {
    if (!mounted || state.phase != DriverRidePhase.onTrip) return;
    final d = Map<String, dynamic>.from(data as Map);
    final myRideId = state.activeTrip?.rideId;
    if (d['rideId'] != myRideId) return;
    setState(
      state.copyWith(
        argo: DriverArgo(
          distanceKm: (d['distanceKm'] as num).toDouble(),
          durationMinutes: (d['durationMinutes'] as num).toDouble(),
          fare: (d['fare'] as num).toDouble(),
        ),
      ),
    );
  }

  void _onRideEnded(dynamic data) {
    if (!mounted || state.phase == DriverRidePhase.completed) return;
    unawaited(SecureStorage.clearDriverRideId());
    final d = Map<String, dynamic>.from(data as Map);
    setState(
      state.copyWith(
        phase: DriverRidePhase.completed,
        completedRideId: d['rideId'] as String?,
        argo: DriverArgo(
          distanceKm: (d['distanceKm'] as num).toDouble(),
          durationMinutes: (d['durationMinutes'] as num).toDouble(),
          fare: (d['finalFare'] as num).toDouble(),
        ),
      ),
    );
  }

  void _onRideCancelled(dynamic data) {
    if (!mounted) return;
    _requestReceivedAt = null;
    FcmService.setHasActivePendingRequest(false);
    final d = Map<String, dynamic>.from(data as Map);
    final cancelledRideId = d['rideId'] as String?;
    final myRideId = state.activeTrip?.rideId ?? state.pendingRequest?.rideId;
    if (cancelledRideId != null && myRideId != null && cancelledRideId != myRideId) return;
    unawaited(SecureStorage.clearDriverRideId());
    setState(
      state.copyWith(
        phase: DriverRidePhase.idle,
        clearRequest: true,
        clearTrip: true,
        clearArgo: true,
        clearRoute: true,
        clearCancelRequest: true,
      ),
    );
  }

  void _onCancelRequest(dynamic data) {
    if (!mounted) return;
    final d = Map<String, dynamic>.from(data as Map);
    final rideId = d['rideId'] as String?;
    final myRideId = state.activeTrip?.rideId;
    if (rideId != null && myRideId != null && rideId != myRideId) return;
    setState(state.copyWith(cancelRequested: true, cancelRequestRideId: rideId));
  }

  Future<void> approveCancel() async {
    _requestReceivedAt = null;
    FcmService.setHasActivePendingRequest(false);
    final rideId = state.cancelRequestRideId ?? state.activeTrip?.rideId;
    if (rideId == null) return;
    _socket?.emit('driverCancelApproved', {'rideId': rideId});
    _stopDemoMovement();
    unawaited(SecureStorage.clearDriverRideId());
    setState(state.copyWith(
      phase: DriverRidePhase.idle,
      clearRequest: true,
      clearTrip: true,
      clearArgo: true,
      clearRoute: true,
      clearCancelRequest: true,
    ));
  }

  void rejectCancel() {
    final rideId = state.cancelRequestRideId ?? state.activeTrip?.rideId;
    if (rideId != null) {
      _socket?.emit('driverCancelRejected', {'rideId': rideId});
    }
    setState(state.copyWith(clearCancelRequest: true));
  }

  Future<void> acceptRide() async {
    _requestReceivedAt = null;
    FcmService.setHasActivePendingRequest(false);
    final req = state.pendingRequest;
    if (req == null) return;
    final isDemo = req.rideId.startsWith('demo-');
    if (!isDemo) {
      try {
        await _dio.post(
          '/booking/rides/${req.rideId}/accept',
          data: {'driverId': _driverUserId},
        );
      } catch (_) {
        return;
      }
    }
    // Join ride room so driver receives scoped WebSocket events
    _socket?.emit('joinRide', {'rideId': req.rideId});

    final from = state.position ?? const LatLng(-6.9175, 107.6191);
    setState(
      state.copyWith(
        phase: DriverRidePhase.navigating,
        activeTrip: DriverTrip(
          rideId: req.rideId,
          originLat: req.originLat,
          originLng: req.originLng,
          destinationLat: req.destinationLat,
          destinationLng: req.destinationLng,
          originAddress: req.originAddress,
          destinationAddress: req.destinationAddress,
          passengerName: req.passengerName,
        ),
        clearRequest: true,
      ),
    );
    if (!isDemo) {
      unawaited(SecureStorage.saveDriverRideId(req.rideId));
    }
    if (isDemo) {
      unawaited(
        _startDemoMovement(
          from: from,
          to: LatLng(req.originLat, req.originLng),
        ),
      );
    } else {
      unawaited(_fetchAndSetRoute(from, LatLng(req.originLat, req.originLng)));
    }
  }

  void rejectRide() {
    _requestReceivedAt = null;
    FcmService.setHasActivePendingRequest(false);
    setState(
      state.copyWith(
        phase: DriverRidePhase.idle,
        clearRequest: true,
        clearRoute: true,
      ),
    );
  }

  Future<void> cancelRide() async {
    final trip = state.activeTrip;
    if (trip == null) return;
    try {
      await _dio.post('/booking/rides/${trip.rideId}/cancel');
    } catch (_) {}
    _stopDemoMovement();
    unawaited(SecureStorage.clearDriverRideId());
    setState(
      state.copyWith(
        phase: DriverRidePhase.idle,
        clearTrip: true,
        clearArgo: true,
        clearRoute: true,
      ),
    );
  }

  Future<void> arrivedAtPickup() async {
    final trip = state.activeTrip;
    if (trip == null) return;
    if (trip.rideId.startsWith('demo-')) {
      _stopDemoMovement();
      setState(
        state.copyWith(
          phase: DriverRidePhase.atPickup,
          position: LatLng(trip.originLat, trip.originLng),
          clearRoute: true,
        ),
      );
      return;
    }
    try {
      await _dio.patch(
        '/booking/rides/${trip.rideId}/status',
        data: {'status': 'PICKUP'},
      );
      setState(state.copyWith(phase: DriverRidePhase.atPickup));
    } catch (_) {
      setState(state.copyWith(phase: DriverRidePhase.atPickup));
    }
  }

  Future<void> startTrip() async {
    final trip = state.activeTrip;
    if (trip == null) return;
    if (trip.rideId.startsWith('demo-')) {
      _socket?.emit('startRide', {
        'rideId': trip.rideId,
        'driverId': _driverUserId ?? 'demo-driver',
        'latitude': trip.originLat,
        'longitude': trip.originLng,
      });
      setState(state.copyWith(phase: DriverRidePhase.onTrip));
      unawaited(
        _startDemoMovement(
          from: LatLng(trip.originLat, trip.originLng),
          to: LatLng(trip.destinationLat, trip.destinationLng),
          rideId: trip.rideId,
        ),
      );
      return;
    }
    final pos = state.position;
    try {
      await _dio.patch(
        '/booking/rides/${trip.rideId}/status',
        data: {'status': 'ONGOING'},
      );
      _socket?.emit('startRide', {
        'rideId': trip.rideId,
        'driverId': _driverUserId,
        'latitude': pos?.latitude ?? 0,
        'longitude': pos?.longitude ?? 0,
      });
      setState(state.copyWith(phase: DriverRidePhase.onTrip));
      if (trip.hasDestination) {
        unawaited(_fetchAndSetRoute(
          pos ?? LatLng(trip.originLat, trip.originLng),
          LatLng(trip.destinationLat, trip.destinationLng),
        ));
      }
    } catch (_) {
      setState(state.copyWith(phase: DriverRidePhase.onTrip));
    }
  }

  Future<void> endTrip() async {
    final trip = state.activeTrip;
    if (trip == null) return;
    if (trip.rideId.startsWith('demo-')) {
      _stopDemoMovement();
      _socket?.emit('endRide', {'rideId': trip.rideId});
      setState(
        state.copyWith(
          phase: DriverRidePhase.completed,
          completedRideId: trip.rideId,
          position: LatLng(trip.destinationLat, trip.destinationLng),
          argo: const DriverArgo(
            distanceKm: 3.2,
            durationMinutes: 12,
            fare: 14000,
          ),
          clearRoute: true,
        ),
      );
      return;
    }
    _stopDemoMovement();
    unawaited(SecureStorage.clearDriverRideId());
    try {
      _socket?.emit('endRide', {'rideId': trip.rideId});
      final resp = await _dio.post('/booking/rides/${trip.rideId}/complete');
      final data = resp.data as Map<String, dynamic>;
      final fare = (data['fare'] as num?)?.toDouble() ?? (state.argo?.fare ?? 14000);
      setState(state.copyWith(
        phase: DriverRidePhase.completed,
        completedRideId: trip.rideId,
        argo: DriverArgo(
          distanceKm: state.argo?.distanceKm ?? 0,
          durationMinutes: state.argo?.durationMinutes ?? 0,
          fare: fare,
        ),
        clearRoute: true,
      ));
    } catch (_) {
      setState(state.copyWith(
        phase: DriverRidePhase.completed,
        completedRideId: trip.rideId,
        clearRoute: true,
      ));
    }
  }

  Future<void> _startDemoMovement({
    required LatLng from,
    required LatLng to,
    String? rideId,
  }) async {
    _demoMoveTimer?.cancel();

    final rawRoute = await HereService.getRoute(from, to);
    final route = _sampleRoute(rawRoute, 28);

    if (mounted) setState(state.copyWith(routePoints: route));

    int index = 0;
    _demoMoveTimer = Timer.periodic(const Duration(milliseconds: 1500), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      index++;
      if (index >= route.length) {
        t.cancel();
        return;
      }
      final pos = route[index];
      setState(state.copyWith(position: pos));
      _socket?.emit('updateLocation', {
        'driverId': _driverUserId ?? 'demo-driver',
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'rideId': rideId,
      });
    });
  }

  void _stopDemoMovement() {
    _demoMoveTimer?.cancel();
    _demoMoveTimer = null;
  }

  Future<void> _fetchAndSetRoute(LatLng from, LatLng to) async {
    final route = await HereService.getRoute(from, to);
    if (mounted) setState(state.copyWith(routePoints: route));
  }

  static List<LatLng> _sampleRoute(List<LatLng> pts, int target) {
    if (pts.length <= target) return pts;
    return List.generate(target, (i) {
      final idx = ((i / (target - 1)) * (pts.length - 1)).round().clamp(
        0,
        pts.length - 1,
      );
      return pts[idx];
    });
  }

  Future<void> acceptRideFromNotification(Map<String, dynamic> data) async {
    _requestReceivedAt = null;
    FcmService.setHasActivePendingRequest(false);
    debugPrint('[Driver] acceptRideFromNotification start: $data');
    _driverUserId ??= await SecureStorage.getUserId();
    final rideId = data['rideId'] as String? ?? '';
    if (rideId.isEmpty) {
      debugPrint('[Driver] acceptRideFromNotification: rideId kosong, abort');
      return;
    }

    double toD(dynamic v, [double fb = 0.0]) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? fb;
      return fb;
    }

    try {
      debugPrint('[Driver] acceptRideFromNotification: call API accept rideId=$rideId driverId=$_driverUserId');
      await _dio.post(
        '/booking/rides/$rideId/accept',
        data: {'driverId': _driverUserId},
      );
      debugPrint('[Driver] acceptRideFromNotification: API accept berhasil');
    } catch (e) {
      debugPrint('[Driver] acceptRideFromNotification: API accept GAGAL: $e');
      return;
    }

    unawaited(SecureStorage.saveDriverRideId(rideId));

    final from = state.position ?? const LatLng(-6.9175, 107.6191);
    setState(
      state.copyWith(
        phase: DriverRidePhase.navigating,
        activeTrip: DriverTrip(
          rideId: rideId,
          originLat: toD(data['originLat']),
          originLng: toD(data['originLng']),
          destinationLat: toD(data['destinationLat']),
          destinationLng: toD(data['destinationLng']),
          originAddress: data['originAddress'] as String?,
          destinationAddress: data['destinationAddress'] as String?,
          passengerName: data['passengerName'] as String?,
        ),
        clearRequest: true,
      ),
    );

    unawaited(_fetchAndSetRoute(from, LatLng(toD(data['originLat']), toD(data['originLng']))));

    if (_socket == null || !_socket!.connected) {
      debugPrint('[Driver] acceptRideFromNotification: socket tidak aktif, goOnline()');
      unawaited(goOnline());
    } else {
      debugPrint('[Driver] acceptRideFromNotification: emit joinRide rideId=$rideId');
      _socket!.emit('joinRide', {'rideId': rideId});
    }
    debugPrint('[Driver] acceptRideFromNotification selesai');
  }

  void checkStaleState() {
    // Only reset if socket is gone AND the driver was supposedly online.
    // Do NOT reset a freshly-restored trip (isOnline=false, phase!=idle).
    if (_socket == null && state.isOnline) {
      // Jangan reset jika ada pendingRequest yang masih dalam window 30 detik
      if (state.pendingRequest != null && _requestReceivedAt != null) {
        final elapsed = DateTime.now().difference(_requestReceivedAt!);
        if (elapsed < const Duration(seconds: 30)) {
          debugPrint('[Driver] checkStaleState: pendingRequest masih valid (${elapsed.inSeconds}s), skip reset');
          return;
        }
      }
      debugPrint('[Driver] checkStaleState: socket null + isOnline, reset state');
      _requestReceivedAt = null;
      FcmService.setHasActivePendingRequest(false);
      state = const DriverState();
    }
  }

  void clearCompleted() {
    setState(
      state.copyWith(
        phase: DriverRidePhase.idle,
        clearTrip: true,
        clearArgo: true,
        clearCompleted: true,
        clearRoute: true,
        todayTrips: state.todayTrips + 1,
        todayEarnings: state.todayEarnings + (state.argo?.fare ?? 0),
      ),
    );
  }

  Future<void> _loadStats() async {
    try {
      final resp = await _dio.get('/drivers/today-stats');
      final d = resp.data as Map<String, dynamic>;
      setState(
        state.copyWith(
          todayTrips: (d['todayTrips'] as num?)?.toInt() ?? 0,
          todayEarnings: (d['todayEarnings'] as num?)?.toDouble() ?? 0.0,
          todayKm: (d['todayKm'] as num?)?.toDouble() ?? 0.0,
          todayTarget: (d['todayTarget'] as num?)?.toDouble() ?? 200000.0,
          rating: (d['rating'] as num?)?.toDouble() ?? 5.0,
          bonusActive: d['bonusActive'] as bool? ?? false,
          bonusAmount: (d['bonusAmount'] as num?)?.toInt() ?? 0,
        ),
      );
    } catch (_) {}
  }

  Future<void> _loadHotZones() async {
    try {
      final resp = await _dio.get('/drivers/hot-zones');
      final list = resp.data as List<dynamic>;
      final zones = list
          .map((e) => HotZone.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      setState(state.copyWith(hotZones: zones));
    } catch (_) {
      setState(state.copyWith(hotZones: _demoZones));
    }
  }

  Future<void> refreshStats() => _loadStats();
  Future<void> refreshZones() => _loadHotZones();

  Future<Position> _currentPos() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return Position(
        latitude: -6.9175,
        longitude: 107.6191,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }
  }

  void setState(DriverState s) => state = s;

  @override
  void dispose() {
    _gpsTimer?.cancel();
    _demoMoveTimer?.cancel();
    _socket?.disconnect();
    super.dispose();
  }
}

const _demoZones = <HotZone>[
  HotZone(
    id: '1',
    name: 'Braga',
    demand: 'high',
    lat: -6.9175,
    lng: 107.6102,
    requestCount: 8,
  ),
  HotZone(
    id: '2',
    name: 'Dago',
    demand: 'medium',
    lat: -6.8857,
    lng: 107.6108,
    requestCount: 4,
  ),
  HotZone(
    id: '3',
    name: 'BIP',
    demand: 'high',
    lat: -6.9210,
    lng: 107.6072,
    requestCount: 7,
  ),
  HotZone(
    id: '4',
    name: 'Buah Batu',
    demand: 'medium',
    lat: -6.9447,
    lng: 107.6425,
    requestCount: 3,
  ),
];

final driverProvider = StateNotifierProvider<DriverNotifier, DriverState>(
  (ref) => DriverNotifier(),
);
