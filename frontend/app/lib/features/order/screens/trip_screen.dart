import 'dart:async';
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
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../driver/providers/driver_chat_provider.dart';
import '../../driver/screens/driver_chat_screen.dart';

class DriverTripScreen extends ConsumerStatefulWidget {
  const DriverTripScreen({super.key});
  @override
  ConsumerState<DriverTripScreen> createState() => _DriverTripScreenState();
}

class _DriverTripScreenState extends ConsumerState<DriverTripScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapCtrl = MapController();
  io.Socket? _socket;
  Timer? _gpsTimer;
  Timer? _tripTimer;

  late Map<String, dynamic> _rideData;

  String get _rideId => (_rideData['rideId'] as String?) ?? '';
  String get _passengerName =>
      (_rideData['passengerName'] as String?) ?? 'Penumpang';
  String get _destinationLabel =>
      (_rideData['destinationAddress'] as String?) ?? 'Tujuan';

  late LatLng _pickupPos;
  late LatLng _destinationPos;

  int _elapsedSec = 0;
  double _distanceKm = 0;
  double _fare = 14000;
  bool _isFinishing = false;
  bool _initialized = false;
  bool _nearDestination = false;
  bool _userInteracted = false;

  double _parseDouble(dynamic v, [double fallback = 0.0]) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  late LatLng _currentPos;
  late List<LatLng> _trail;

  final _currencyFmt = NumberFormat.currency(
      locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    _rideData = (args is Map<String, dynamic>) ? args : {};

    final originLat = _parseDouble(_rideData['originLat'], -6.9218);
    final originLng = _parseDouble(_rideData['originLng'], 107.6066);
    final destLat   = _parseDouble(_rideData['destinationLat'], -6.9300);
    final destLng   = _parseDouble(_rideData['destinationLng'], 107.6350);

    _pickupPos = LatLng(originLat, originLng);
    _destinationPos = LatLng(destLat, destLng);
    _currentPos = _pickupPos;
    _trail = [_pickupPos];

    _fare = _parseDouble(_rideData['estimatedFare'], 14000);
    _distanceKm = _parseDouble(_rideData['distanceKm']);

    // Keep chat connected for ongoing trip
    if (_rideId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(driverChatProvider.notifier).connect(
            _rideId,
            passengerName: _passengerName,
            passengerPhone: (_rideData['passengerPhone'] as String?) ?? '',
          );
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _connectSocket();
    _startTrip();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setOngoing());
  }

  Future<void> _setOngoing() async {
    if (_rideId.isEmpty) return;
    try {
      await DioClient.create().patch(
        '/booking/rides/$_rideId/status',
        data: {'status': 'ONGOING'},
      );
    } catch (_) {}
  }

  Future<void> _connectSocket() async {
    final token    = await SecureStorage.getAccessToken();
    final driverId = await SecureStorage.getUserId();

    _socket = io.io(
      '${ApiConstants.wsUrl}${ApiConstants.trackingNamespace}',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .disableAutoConnect()
          .build(),
    );

    _socket?.onConnect((_) async {
      if (_rideId.isEmpty) return;
      // Join ride room so driver receives scoped events (rideCancelled, meter_update)
      _socket?.emit('joinRide', {'rideId': _rideId});
      double lat = _currentPos.latitude;
      double lng = _currentPos.longitude;
      try {
        final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium);
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}
      _socket?.emit('startRide', {
        'rideId':    _rideId,
        'driverId':  driverId,
        'latitude':  lat,
        'longitude': lng,
      });
    });

    // If passenger cancels mid-trip, return driver to home
    _socket?.on('rideCancelled', (data) {
      if (!mounted) return;
      _tripTimer?.cancel();
      _gpsTimer?.cancel();
      _socket?.disconnect();
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    });

    _socket?.on('meter_update', (data) {
      if (!mounted) return;
      final map = Map<String, dynamic>.from(data as Map);
      setState(() {
        _distanceKm = (map['distance_km'] as num).toDouble();
        _fare       = (map['fare']        as num).toDouble();
      });
    });

    _socket?.on('argoUpdate', (data) {
      if (!mounted) return;
      final map = Map<String, dynamic>.from(data as Map);
      setState(() {
        _distanceKm = (map['distanceKm'] as num).toDouble();
        _fare       = (map['fare']        as num).toDouble();
      });
    });

    _socket?.connect();

    _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        if (!mounted) return;
        final newPos = LatLng(pos.latitude, pos.longitude);
        final distToDestM = Geolocator.distanceBetween(
          pos.latitude, pos.longitude,
          _destinationPos.latitude, _destinationPos.longitude,
        );
        setState(() {
          _currentPos = newPos;
          _trail.add(_currentPos);
          _nearDestination = distToDestM <= 300;
        });
        if (!_userInteracted) {
          try { _mapCtrl.move(newPos, 15); } catch (_) {}
        }
        _socket?.emit('updateLocation', {
          'driverId':  driverId,
          'latitude':  pos.latitude,
          'longitude': pos.longitude,
          'rideId':    _rideId,
        });
      } catch (_) {}
    });
  }

  void _startTrip() {
    _tripTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSec += 1);
    });
  }

  @override
  void dispose() {
    _tripTimer?.cancel();
    _gpsTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  String get _elapsed {
    final m = _elapsedSec ~/ 60;
    final s = _elapsedSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DriverChatDetail()),
    );
  }

  Future<void> _callPassenger() async {
    final phone = ref.read(driverChatProvider).passengerPhone ?? '';
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _finishTrip() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    _tripTimer?.cancel();
    _gpsTimer?.cancel();

    if (_rideId.isNotEmpty) {
      _socket?.emit('endRide', {'rideId': _rideId});
      await Future.delayed(const Duration(milliseconds: 600));
    }
    _socket?.disconnect();

    try {
      if (_rideId.isNotEmpty) {
        await DioClient.create().post('/booking/rides/$_rideId/complete');
      }
    } catch (_) {}

    if (!mounted) return;
    _showCompleteSheet();
  }

  void _showCompleteSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DriverTripCompleteSheet(
        passengerName: _passengerName,
        distanceKm: _distanceKm,
        elapsed: _elapsed,
        fare: _fare,
        fmt: _currencyFmt,
        onDone: () {
          Navigator.of(ctx).pop();
          Navigator.pushReplacementNamed(context, '/home');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(driverChatProvider);
    final hasPhone = (chatState.passengerPhone ?? '').isNotEmpty;
    final initial = _passengerName.isNotEmpty
        ? _passengerName[0].toUpperCase()
        : 'P';

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
          // Map
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _currentPos,
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
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [_pickupPos, _destinationPos],
                    strokeWidth: 4,
                    color: AppColors.primaryColor.withValues(alpha: 0.3),
                  ),
                  if (_trail.length > 1)
                    Polyline(
                      points: _trail,
                      strokeWidth: 5,
                      color: AppColors.primaryColor,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentPos,
                    width: 52, height: 52,
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
                            color: AppColors.primaryColor.withValues(alpha: 0.5),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.electric_moped_rounded,
                          color: Colors.white, size: 26),
                    ),
                  ),
                  Marker(
                    point: _destinationPos,
                    width: 48, height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.primaryColor, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentColor.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.flag_rounded,
                          color: AppColors.primaryDark, size: 24),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Top stats bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
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
                    _stat(Icons.timer_rounded, _elapsed, 'Waktu'),
                    Container(width: 1, height: 36, color: Colors.white24),
                    _stat(Icons.route_rounded,
                        '${_distanceKm.toStringAsFixed(1)} km', 'Jarak'),
                    Container(width: 1, height: 36, color: Colors.white24),
                    _stat(Icons.payments_rounded,
                        _currencyFmt.format(_fare), 'Pendapatan',
                        accent: true),
                  ],
                ),
              ),
            ),
          ),

          // Re-center button (shown when user has panned/zoomed away)
          if (_userInteracted)
            Positioned(
              bottom: 270, right: 16,
              child: GestureDetector(
                onTap: () {
                  setState(() => _userInteracted = false);
                  try { _mapCtrl.move(_currentPos, 15); } catch (_) {}
                },
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.my_location_rounded,
                      color: AppColors.primaryColor, size: 22),
                ),
              ),
            ),

          // Bottom card
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                      color: Color(0x220540F2),
                      blurRadius: 32,
                      offset: Offset(0, -8)),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Passenger info row
                  Row(
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF056CF2), Color(0xFF0540F2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _passengerName,
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: AppColors.primaryColor),
                            ),
                            Text(
                              'Menuju $_destinationLabel',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // LIVE badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.online.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.online.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                                width: 6, height: 6,
                                decoration: const BoxDecoration(
                                    color: AppColors.online,
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text('LIVE',
                                style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                    color: AppColors.online)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Chat + Phone action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _ActionBtn(
                          icon: Icons.chat_bubble_rounded,
                          label: 'Chat',
                          color: AppColors.primaryColor,
                          onTap: _openChat,
                        ),
                      ),
                      if (hasPhone) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionBtn(
                            icon: Icons.phone_rounded,
                            label: 'Telepon',
                            color: const Color(0xFF22C55E),
                            onTap: _callPassenger,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),

                  // End trip button — only active when within 300m of destination
                  if (!_nearDestination && !_isFinishing)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'Tombol aktif saat tiba di tujuan (< 300m)',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: (_isFinishing || !_nearDestination) ? null : _finishTrip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentColor,
                        disabledBackgroundColor: AppColors.primaryLight,
                        foregroundColor: AppColors.primaryDark,
                        disabledForegroundColor: AppColors.textSecondary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: _nearDestination ? 4 : 0,
                        shadowColor:
                            AppColors.accentColor.withValues(alpha: 0.5),
                      ),
                      icon: _isFinishing
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.primaryColor))
                          : Icon(Icons.flag_rounded, size: 22,
                              color: _nearDestination ? AppColors.primaryDark : AppColors.textSecondary),
                      label: Text(
                        'Selesai Perjalanan',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _stat(IconData icon, String value, String label,
      {bool accent = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            color: accent ? AppColors.accentColor : Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: accent ? 13 : 14,
              color: accent ? AppColors.accentColor : Colors.white),
        ),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 10, color: Colors.white54),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Driver Trip Complete Sheet
// ═══════════════════════════════════════════════════════════════════════════

class _DriverTripCompleteSheet extends StatefulWidget {
  const _DriverTripCompleteSheet({
    required this.passengerName,
    required this.distanceKm,
    required this.elapsed,
    required this.fare,
    required this.fmt,
    required this.onDone,
  });
  final String passengerName;
  final double distanceKm;
  final String elapsed;
  final double fare;
  final NumberFormat fmt;
  final VoidCallback onDone;

  @override
  State<_DriverTripCompleteSheet> createState() =>
      _DriverTripCompleteSheetState();
}

class _DriverTripCompleteSheetState extends State<_DriverTripCompleteSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _scale = CurvedAnimation(parent: _anim, curve: Curves.elasticOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

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
          // Gradient header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
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
                  scale: _scale,
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
                  'Terima kasih, ${widget.passengerName}!',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              children: [
                // Trip stats row
                Row(
                  children: [
                    Expanded(child: _StatTile(
                      icon: Icons.person_rounded,
                      value: widget.passengerName,
                      label: 'Penumpang',
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _StatTile(
                      icon: Icons.route_rounded,
                      value: '${widget.distanceKm.toStringAsFixed(1)} km',
                      label: 'Jarak',
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _StatTile(
                      icon: Icons.timer_rounded,
                      value: widget.elapsed,
                      label: 'Durasi',
                    )),
                  ],
                ),
                const SizedBox(height: 16),

                // Earnings card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF2CB05), Color(0xFFE6B800)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF2CB05).withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Pendapatan Trip Ini',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.fmt.format(widget.fare),
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 32,
                            color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Cash reminder
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.payments_rounded,
                        color: Color(0xFF16A34A), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Terima pembayaran ${widget.fmt.format(widget.fare)} dari penumpang',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: widget.onDone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Kembali ke Home',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Icon(icon, color: AppColors.primaryColor, size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800, fontSize: 12,
              color: AppColors.primaryDark),
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

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: color),
              ),
            ],
          ),
        ),
      );
}
