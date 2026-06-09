import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/here_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../passenger/providers/chat_provider.dart';
import '../../passenger/screens/passenger_chat_screen.dart';
import '../providers/booking_provider.dart';

enum _TripPhase { accepted, pickup, ongoing }

class TripArgs {
  final String rideId;
  final String driverName;
  final String driverPlate;
  final String driverPhone;
  final double driverLat;
  final double driverLng;
  final double destLat;
  final double destLng;
  final String? initialStatus;

  const TripArgs({
    required this.rideId,
    required this.driverName,
    required this.driverPlate,
    this.driverPhone = '',
    required this.driverLat,
    required this.driverLng,
    required this.destLat,
    required this.destLng,
    this.initialStatus,
  });
}

class TripScreen extends ConsumerStatefulWidget {
  const TripScreen({super.key});

  @override
  ConsumerState<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends ConsumerState<TripScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _fareController;
  late Animation<double> _fareAnim;

  io.Socket? _socket;
  Timer? _localTimer;
  Timer? _offlineCheckTimer;
  Timer? _locationTimer;
  bool _tripCompleted = false;
  String _passengerId = '';
  bool _initialized = false;
  bool _timerStarted = false;
  bool _userInteracted = false;
  bool _driverOffline = false;
  bool _isRerouting = false;
  DateTime? _lastDriverUpdate;
  LatLng? _lastRouteFetchPos;

  _TripPhase _phase = _TripPhase.accepted;
  int _elapsedSeconds = 0;
  double _currentFare = 14000;
  double _distanceKm = 0;

  String _rideId      = '';
  String _driverName  = 'Driver';
  String _driverPlate = '-';
  String _driverPhone = '';
  LatLng _driverPos   = const LatLng(-6.9175, 107.6191);
  LatLng _destination = const LatLng(-6.8857, 107.6108);

  List<LatLng> _routePoints = [];

  final _fmt = NumberFormat.currency(
      locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _fareController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fareAnim = CurvedAnimation(parent: _fareController, curve: Curves.easeOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is TripArgs) {
      _rideId      = args.rideId;
      _driverName  = args.driverName;
      _driverPlate = args.driverPlate;
      _driverPhone = args.driverPhone;
      _driverPos   = LatLng(args.driverLat, args.driverLng);
      _destination = LatLng(args.destLat, args.destLng);

      if (args.initialStatus == 'ONGOING') {
        _phase = _TripPhase.ongoing;
        _timerStarted = true;
        _startLocalTimer();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _redirectToGoogleMaps();
        });
      }
    }

    _passengerId = ref.read(authProvider).user?.id ?? '';

    _connectSocket();
    if (_phase != _TripPhase.ongoing) _fetchRoute();
    _startOfflineCheck();
    _startPassengerLocationUpdates();

    if (_rideId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(chatProvider.notifier).connect(_rideId);
      });
    }
  }

  void _startPassengerLocationUpdates() {
    if (_rideId.isEmpty || _passengerId.isEmpty) return;
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _socket?.emit('updatePassengerLocation', {
          'passengerId': _passengerId,
          'rideId': _rideId,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
        });
      } catch (_) {}
    });
  }

  Future<void> _connectSocket() async {
    final token = await SecureStorage.getAccessToken();
    _socket = io.io(
      '${ApiConstants.wsUrl}${ApiConstants.trackingNamespace}',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionAttempts(99999)
          .build(),
    );
    _socket?.connect();
    _socket?.onConnect((_) {
      if (_rideId.isNotEmpty) {
        _socket?.emit('joinRide', {'rideId': _rideId});
      }
    });

    _socket?.on('rideStatusChanged', (data) {
      if (!mounted) return;
      final map = Map<String, dynamic>.from(data as Map);
      final status = map['status'] as String? ?? '';
      if (status == 'PICKUP' && _phase == _TripPhase.accepted) {
        setState(() => _phase = _TripPhase.pickup);
      } else if (status == 'ONGOING' && _phase != _TripPhase.ongoing) {
        setState(() {
          _phase = _TripPhase.ongoing;
          _currentFare = 14000;
          _distanceKm = 0;
        });
        if (!_timerStarted) {
          _timerStarted = true;
          _startLocalTimer();
        }
        _redirectToGoogleMaps();
      }
    });

    _socket?.on('meter_update', (data) {
      if (!mounted || _phase != _TripPhase.ongoing) return;
      final m = Map<String, dynamic>.from(data as Map);
      setState(() {
        _distanceKm  = num.tryParse(m['distance_km']?.toString() ?? '')?.toDouble() ?? _distanceKm;
        _currentFare = num.tryParse(m['fare']?.toString() ?? '')?.toDouble() ?? _currentFare;
      });
      _fareController.forward(from: 0);
    });

    _socket?.on('argoUpdate', (data) {
      if (!mounted || _phase != _TripPhase.ongoing) return;
      final m = Map<String, dynamic>.from(data as Map);
      setState(() {
        _distanceKm  = num.tryParse(m['distanceKm']?.toString() ?? '')?.toDouble() ?? _distanceKm;
        _currentFare = num.tryParse(m['fare']?.toString() ?? '')?.toDouble() ?? _currentFare;
      });
      _fareController.forward(from: 0);
    });

    _socket?.on('driverLocationUpdated', (data) {
      if (!mounted) return;
      final m = Map<String, dynamic>.from(data as Map);
      final lat = num.tryParse(m['latitude']?.toString() ?? '')?.toDouble();
      final lng = num.tryParse(m['longitude']?.toString() ?? '')?.toDouble();
      if (lat == null || lng == null) return;
      final newPos = LatLng(lat, lng);
      setState(() {
        _driverPos = newPos;
        _lastDriverUpdate = DateTime.now();
        if (_driverOffline) _driverOffline = false;
      });
      if (!_userInteracted) {
        try { _mapController.move(newPos, 15); } catch (_) {}
      }

      if (_phase == _TripPhase.ongoing && !_isRerouting) {
        final lastPos = _lastRouteFetchPos;
        if (lastPos == null || _distM(lastPos, newPos) > 200) {
          _lastRouteFetchPos = newPos;
          _isRerouting = true;
          HereService.getRoute(newPos, _destination).then((route) {
            if (!mounted) return;
            setState(() { _routePoints = route; _isRerouting = false; });
          }).catchError((_) { _isRerouting = false; });
        }
      }
    });

    _socket?.on('driverStatusChanged', (data) {
      if (!mounted) return;
      final m = Map<String, dynamic>.from(data as Map);
      if (m['status'] == 'offline') {
        setState(() => _driverOffline = true);
      } else if (m['status'] == 'online') {
        setState(() => _driverOffline = false);
      }
    });

    _socket?.on('rideEnded', (data) {
      if (!mounted) return;
      final m = Map<String, dynamic>.from(data as Map);
      setState(() {
        _distanceKm  = num.tryParse(m['distanceKm']?.toString() ?? '')?.toDouble() ?? _distanceKm;
        _currentFare = num.tryParse(m['finalFare']?.toString() ?? '')?.toDouble() ?? _currentFare;
      });
      _showTripCompleteSheet();
    });
  }

  Future<void> _fetchRoute() async {
    _lastRouteFetchPos = _driverPos;
    final route = await HereService.getRoute(_driverPos, _destination);
    if (!mounted) return;
    setState(() => _routePoints = route);
  }

  double _distM(LatLng a, LatLng b) {
    const R = 6371000.0;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return R * 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
  }

  List<LatLng> _trimRoute(List<LatLng> route, LatLng pos) {
    if (route.length < 2) return route;
    double minDist = double.infinity;
    int closestIdx = 0;
    for (int i = 0; i < route.length; i++) {
      final d = _distM(route[i], pos);
      if (d < minDist) {
        minDist = d;
        closestIdx = i;
      }
    }
    return [pos, ...route.sublist(closestIdx)];
  }

  void _startOfflineCheck() {
    _offlineCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || _driverOffline) return;
      final last = _lastDriverUpdate;
      if (last != null && DateTime.now().difference(last).inSeconds > 60) {
        setState(() => _driverOffline = true);
      }
    });
  }

  Future<void> _makeCall(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _redirectToGoogleMaps() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Perjalanan dimulai! Membuka Google Maps...'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF059669),
      ),
    );
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    await _openGoogleMaps();
  }

  Future<void> _openGoogleMaps() async {
    final lat = _destination.latitude;
    final lng = _destination.longitude;
    final navUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$lat,$lng&travelmode=driving&dir_action=navigate',
    );
    if (await canLaunchUrl(navUri)) {
      await launchUrl(navUri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PassengerChatDetail()),
    );
  }

  void _startLocalTimer() {
    _localTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _fareController.dispose();
    _localTimer?.cancel();
    _offlineCheckTimer?.cancel();
    _locationTimer?.cancel();
    if (_rideId.isNotEmpty) {
      _socket?.emit('leaveRide', {'rideId': _rideId});
    }
    _socket?.disconnect();
    super.dispose();
  }

  String get _elapsedTime {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _showTripCompleteSheet() async {
    if (_tripCompleted) return;
    _tripCompleted = true;
    _localTimer?.cancel();
    if (_rideId.isNotEmpty) {
      _socket?.emit('leaveRide', {'rideId': _rideId});
    }
    _socket?.disconnect();

    if (!mounted) return;
    ref.read(bookingProvider.notifier).reset();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TripCompleteSheet(
        rideId: _rideId,
        driverName: _driverName,
        distanceKm: _distanceKm,
        elapsedTime: _elapsedTime,
        fare: _currentFare,
        fmt: _fmt,
        onDone: () {
          Navigator.of(ctx).pop();
          Navigator.pushNamedAndRemoveUntil(context, '/main', (_) => false);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = _driverName.isNotEmpty ? _driverName[0].toUpperCase() : 'D';
    final isOngoing = _phase == _TripPhase.ongoing;
    final remainingRoute = _trimRoute(_routePoints, _driverPos);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.pushNamedAndRemoveUntil(context, '/main', (r) => false);
        }
      },
      child: Scaffold(
      body: Stack(
        children: [
          if (!isOngoing)
          RepaintBoundary(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _driverPos,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onMapEvent: (event) {
                  if (event.source == MapEventSource.dragStart ||
                      event.source == MapEventSource.multiFingerGestureStart ||
                      event.source == MapEventSource.scrollWheel) {
                    if (!_userInteracted) setState(() => _userInteracted = true);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: ApiConstants.hereTileUrl,
                  userAgentPackageName: 'com.lungo.app',
                ),
                PolylineLayer(polylines: [

                  if (_routePoints.length >= 2)
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4,
                      color: AppColors.primaryColor.withValues(alpha: 0.25),
                    ),

                  if (remainingRoute.length >= 2)
                    Polyline(
                      points: remainingRoute,
                      strokeWidth: 5,
                      color: AppColors.primaryColor.withValues(alpha: 0.85),
                    )
                  else
                    Polyline(
                      points: [_driverPos, _destination],
                      strokeWidth: 5,
                      color: AppColors.primaryColor,
                    ),
                ]),
                MarkerLayer(markers: [
                  Marker(
                    point: _driverPos,
                    width: 48, height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0540F2), Color(0xFF056CF2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryColor.withValues(alpha: 0.45),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.electric_moped_rounded,
                          color: Colors.white, size: 24),
                    ),
                  ),
                  Marker(
                    point: _destination,
                    width: 48, height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.primaryColor, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentColor.withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.flag_rounded,
                          color: AppColors.primaryDark, size: 22),
                    ),
                  ),
                ]),
              ],
            ),
          )
          else
            Container(
              color: const Color(0xFFF0F4FF),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0540F2).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.navigation_rounded,
                        size: 52, color: Color(0xFF0540F2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Perjalanan Berlangsung',
                      style: TextStyle(
                        fontFamily: 'Satoshi', fontWeight: FontWeight.w700,
                        fontSize: 20, color: Color(0xFF0B0940),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Driver sedang mengantar Anda ke tujuan',
                      style: TextStyle(
                        fontFamily: 'Satoshi', fontSize: 14, color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_driverOffline)
            Positioned(
              top: 0, left: 0, right: 0,
              child: Material(
                color: Colors.transparent,
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Koneksi driver terputus. Menunggu reconect...',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: isOngoing
                  ? _buildLiveMeter()
                  : _buildPhaseBanner(),
            ),
          ),

          if (_userInteracted)
            Positioned(
              bottom: 230, right: 16,
              child: GestureDetector(
                onTap: () {
                  setState(() => _userInteracted = false);
                  try { _mapController.move(_driverPos, 15); } catch (_) {}
                },
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 10, offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.my_location_rounded,
                      color: AppColors.primaryColor, size: 22),
                ),
              ),
            ),

          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _buildBottomCard(initial),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildLiveMeter() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF04198C), Color(0xFF0540F2)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryColor.withValues(alpha: 0.4),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _meterItem(Icons.timer_rounded, _elapsedTime, 'Waktu'),
        Container(width: 1, height: 36, color: Colors.white24),
        _meterItem(Icons.route_rounded,
            '${_distanceKm.toStringAsFixed(1)} km', 'Jarak'),
        Container(width: 1, height: 36, color: Colors.white24),
        AnimatedBuilder(
          animation: _fareAnim,
          builder: (_, _) => _meterItem(
            Icons.payments_rounded,
            _fmt.format(_currentFare),
            'Tarif',
            highlight: true,
          ),
        ),
      ],
    ),
  );

  Widget _buildPhaseBanner() {
    final isPickup = _phase == _TripPhase.pickup;
    final color   = isPickup ? AppColors.online : AppColors.primaryColor;
    final icon    = isPickup
        ? Icons.person_pin_circle_rounded
        : Icons.electric_moped_rounded;
    final title   = isPickup ? 'Driver Sudah Tiba' : 'Driver Menuju Lokasimu';
    final sub     = isPickup
        ? 'Silakan naik ke kendaraan'
        : 'Mohon tunggu di titik penjemputan';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPickup
              ? [const Color(0xFF16A34A), const Color(0xFF22C55E)]
              : [const Color(0xFF04198C), const Color(0xFF0540F2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700, fontSize: 13,
                  color: Colors.white)),
              Text(sub, style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, color: Colors.white70)),
            ],
          ),
        ),
        SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withValues(alpha: 0.55)),
          ),
        ),
      ]),
    );
  }

  Widget _buildBottomCard(String initial) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      boxShadow: [
        BoxShadow(
            color: Color(0x330540F2),
            blurRadius: 32,
            offset: Offset(0, -8)),
      ],
    ),
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        if (_phase != _TripPhase.ongoing) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: (_phase == _TripPhase.pickup
                      ? AppColors.online
                      : AppColors.primaryColor)
                  .withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (_phase == _TripPhase.pickup
                        ? AppColors.online
                        : AppColors.primaryColor)
                    .withValues(alpha: 0.2),
              ),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: (_phase == _TripPhase.pickup
                          ? AppColors.online
                          : AppColors.primaryColor)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _phase == _TripPhase.pickup
                      ? Icons.person_pin_circle_rounded
                      : Icons.navigation_rounded,
                  color: _phase == _TripPhase.pickup
                      ? AppColors.online
                      : AppColors.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _phase == _TripPhase.pickup
                          ? 'Driver Sudah Tiba'
                          : 'Driver Dalam Perjalanan',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700, fontSize: 13,
                        color: _phase == _TripPhase.pickup
                            ? AppColors.online
                            : AppColors.primaryColor,
                      ),
                    ),
                    Text(
                      _phase == _TripPhase.pickup
                          ? 'Silakan naik ke kendaraan'
                          : 'Menuju titik penjemputan Anda',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    (_phase == _TripPhase.pickup
                            ? AppColors.online
                            : AppColors.primaryColor)
                        .withValues(alpha: 0.5),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
        ],

        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0540F2), Color(0xFF056CF2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(initial, style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.white)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_driverName, style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800, fontSize: 14,
                    color: AppColors.primaryDark)),
                Text(_driverPlate, style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [

              GestureDetector(
                onTap: _openChat,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.chat_bubble_rounded,
                      color: AppColors.primaryColor, size: 17),
                ),
              ),
              if (_driverPhone.isNotEmpty) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _makeCall(_driverPhone),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.phone_rounded,
                        color: Color(0xFF22C55E), size: 17),
                  ),
                ),
              ],

              if (_phase == _TripPhase.ongoing) ...[
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: _fareAnim,
                  builder: (_, _) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.online.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _fmt.format(_currentFare),
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700, fontSize: 13,
                          color: AppColors.online),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ]),

        if (_phase == _TripPhase.ongoing) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF04198C), Color(0xFF0540F2)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _meterItem(Icons.timer_rounded, _elapsedTime, 'Waktu'),
                Container(width: 1, height: 28, color: Colors.white24),
                _meterItem(Icons.route_rounded,
                    '${_distanceKm.toStringAsFixed(1)} km', 'Jarak'),
                Container(width: 1, height: 28, color: Colors.white24),
                AnimatedBuilder(
                  animation: _fareAnim,
                  builder: (_, _) => _meterItem(
                    Icons.payments_rounded,
                    _fmt.format(_currentFare),
                    'Argo',
                    highlight: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openGoogleMaps,
              icon: const Icon(Icons.navigation_rounded, size: 16),
              label: const Text(
                'Buka Google Maps',
                style: TextStyle(fontFamily: 'Satoshi', fontWeight: FontWeight.w700, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0540F2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _meterItem(IconData icon, String value, String label,
      {bool highlight = false}) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: highlight ? const Color(0xFF22C55E) : Colors.white70,
              size: 16),
          const SizedBox(height: 3),
          highlight
              ? Text(value,
                  style: GoogleFonts.robotoMono(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: const Color(0xFF22C55E),
                      letterSpacing: 0.5))
              : Text(value,
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white)),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 9, color: Colors.white54)),
        ],
      );
}

class _TripCompleteSheet extends StatefulWidget {
  const _TripCompleteSheet({
    required this.rideId,
    required this.driverName,
    required this.distanceKm,
    required this.elapsedTime,
    required this.fare,
    required this.fmt,
    required this.onDone,
  });

  final String rideId;
  final String driverName;
  final double distanceKm;
  final String elapsedTime;
  final double fare;
  final NumberFormat fmt;
  final VoidCallback onDone;

  @override
  State<_TripCompleteSheet> createState() => _TripCompleteSheetState();
}

class _TripCompleteSheetState extends State<_TripCompleteSheet>
    with SingleTickerProviderStateMixin {
  int _selectedRating = 0;
  bool _submitting = false;
  bool _ratingSubmitted = false;
  String _paymentMethod = 'CASH';

  late AnimationController _successAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _successAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = CurvedAnimation(
      parent: _successAnim,
      curve: Curves.elasticOut,
    );
    _successAnim.forward();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _successAnim.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0 || _submitting) return;
    setState(() => _submitting = true);
    HapticFeedback.lightImpact();
    try {
      await ApiClient.create()
          .post('/booking/rides/${widget.rideId}/rate', data: {'rating': _selectedRating});
      setState(() => _ratingSubmitted = true);
    } catch (_) {
      setState(() => _ratingSubmitted = true);
    }
    await Future.delayed(const Duration(milliseconds: 800));
    widget.onDone();
  }

  void _skipRating() => widget.onDone();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF04198C), Color(0xFF0540F2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              children: [

                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4), width: 2),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF4ADE80),
                      size: 52,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Perjalanan Selesai!',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Terima kasih telah menggunakan Lungo',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              children: [

                Row(
                  children: [
                    Expanded(child: _StatCard(
                      icon: Icons.route_rounded,
                      value: '${widget.distanceKm.toStringAsFixed(1)} km',
                      label: 'Jarak',
                      color: AppColors.primaryColor,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _StatCard(
                      icon: Icons.timer_rounded,
                      value: widget.elapsedTime,
                      label: 'Durasi',
                      color: AppColors.primaryColor,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _StatCard(
                      icon: Icons.payments_rounded,
                      value: widget.fmt.format(widget.fare),
                      label: 'Tarif',
                      color: const Color(0xFF16A34A),
                    )),
                  ],
                ),
                const SizedBox(height: 16),

                Text(
                  'Metode Pembayaran',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _PaymentOption(
                        icon: Icons.payments_rounded,
                        label: 'Tunai',
                        color: const Color(0xFF16A34A),
                        selected: _paymentMethod == 'CASH',
                        onTap: () => setState(() => _paymentMethod = 'CASH'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PaymentOption(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'Dana',
                        color: const Color(0xFF118EEA),
                        selected: _paymentMethod == 'DANA',
                        onTap: () => setState(() => _paymentMethod = 'DANA'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_paymentMethod == 'CASH')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2CB05).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF2CB05).withValues(alpha: 0.5)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.payments_rounded, color: Color(0xFF856E00), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Bayar tunai ${widget.fmt.format(widget.fare)} kepada driver',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: const Color(0xFF856E00),
                          ),
                        ),
                      ),
                    ]),
                  )
                else
                  Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF118EEA).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF118EEA).withValues(alpha: 0.4)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFF118EEA), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Transfer ${widget.fmt.format(widget.fare)} ke Dana driver, lalu tekan konfirmasi',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: const Color(0xFF118EEA),
                              ),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse('dana://');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            } else {
                              await launchUrl(
                                Uri.parse('https://link.dana.id/'),
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: Text('Buka Aplikasi Dana',
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF118EEA),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),

                if (!_ratingSubmitted) ...[
                  Text(
                    'Beri Rating untuk ${widget.driverName}',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pengalamanmu sangat berarti bagi driver',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final filled = i < _selectedRating;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedRating = i + 1);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            filled ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: filled
                                ? const Color(0xFFFFB800)
                                : AppColors.primaryLight,
                            size: filled ? 44 : 40,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _selectedRating > 0 && !_submitting
                          ? _submitRating
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentColor,
                        disabledBackgroundColor:
                            AppColors.primaryLight,
                        foregroundColor: AppColors.primaryDark,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.primaryDark))
                          : Text(
                              'Kirim Rating',
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _skipRating,
                    child: Text(
                      'Lewati',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.textSecondary),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF22C55E), size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Rating terkirim! Terima kasih',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: const Color(0xFF22C55E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800, fontSize: 12, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _PaymentOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.1) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : Colors.grey.shade200,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : Colors.grey, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: selected ? color : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
}
