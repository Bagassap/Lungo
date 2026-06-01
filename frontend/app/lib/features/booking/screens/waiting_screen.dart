import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../passenger/providers/chat_provider.dart';
import '../../passenger/screens/passenger_chat_screen.dart';
import '../providers/booking_provider.dart';
import 'trip_screen.dart';

class WaitingScreen extends ConsumerStatefulWidget {
  const WaitingScreen({super.key});

  @override
  ConsumerState<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends ConsumerState<WaitingScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  late AnimationController _dotController;
  late AnimationController _progressController;
  late AnimationController _cardSlideController;
  late AnimationController _pulseController;
  late Animation<Offset> _cardSlide;
  late Animation<double> _pulse;

  io.Socket? _socket;
  Timer? _dotTimer;
  Timer? _offlineCheckTimer;

  int _dotIndex = 0;
  bool _driverOffline = false;
  DateTime? _lastDriverUpdate;

  // Phase: searching → pickup (accepted is merged into pickup)
  _WaitPhase _phase = _WaitPhase.searching;

  LatLng _passengerPos = const LatLng(-6.9175, 107.6191);
  LatLng? _driverPos;

  String _rideId = '';
  double _destLat = -6.9300;
  double _destLng = 107.6350;
  String _driverName   = '';
  String _driverPlate  = '';
  String _driverPhone  = '';
  double _driverRating = 5.0;
  final String _driverEta = '5 menit';

  bool _initialized = false;
  bool _userInteracted = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();

    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed &&
            _phase == _WaitPhase.searching) {
          _progressController.forward(from: 0);
        }
      });

    _cardSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _cardSlideController, curve: Curves.easeOutBack),
    );

    _pulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _dotTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      setState(() => _dotIndex = (_dotIndex + 1) % 3);
    });

    _progressController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _rideId = (args['rideId'] as String?) ?? '';
      final pLat = (args['passengerLat'] as num?)?.toDouble() ?? -6.9175;
      final pLng = (args['passengerLng'] as num?)?.toDouble() ?? 107.6191;
      _passengerPos = LatLng(pLat, pLng);
      _destLat = (args['destLat'] as num?)?.toDouble() ?? -6.9300;
      _destLng = (args['destLng'] as num?)?.toDouble() ?? 107.6350;
      if (args['restore'] == true) _isRestoring = true;
    }

    _connectWebSocket();
    _fetchAndRestorePhase();
  }

  Future<void> _connectWebSocket() async {
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

    // Driver accepted → skip intermediate state, go straight to "menuju penjemputan"
    _socket?.on('rideAccepted', (data) {
      if (!mounted) return;
      final map = Map<String, dynamic>.from(data as Map);
      if (_rideId.isNotEmpty && map['rideId'] != _rideId) return;
      setState(() {
        _driverName   = (map['driverName']  as String?) ?? 'Driver';
        _driverPlate  = (map['driverPlate'] as String?) ?? '-';
        _driverPhone  = (map['driverPhone'] as String?) ?? '';
        _driverRating = num.tryParse(map['driverRating']?.toString() ?? '')?.toDouble() ?? 5.0;
        _phase = _WaitPhase.pickup; // skip accepted — show "menuju penjemputan" immediately
      });
      ref.read(bookingProvider.notifier).setActive(rideStatus: 'ACCEPTED');
      if (_rideId.isNotEmpty) {
        ref.read(chatProvider.notifier).connect(_rideId);
      }
      if (_driverName.isNotEmpty || _driverPhone.isNotEmpty) {
        ref.read(chatProvider.notifier).setDriverInfo(_driverName, _driverPhone);
      }
      _cardSlideController.forward();
      _progressController.stop();
    });

    _socket?.on('driverLocationUpdated', (data) {
      if (!mounted) return;
      final map = Map<String, dynamic>.from(data as Map);
      final lat = num.tryParse(map['latitude']?.toString() ?? '')?.toDouble();
      final lng = num.tryParse(map['longitude']?.toString() ?? '')?.toDouble();
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

    });

    _socket?.on('driverStatusChanged', (data) {
      if (!mounted) return;
      final map = Map<String, dynamic>.from(data as Map);
      if (map['status'] == 'offline' && _phase != _WaitPhase.searching) {
        setState(() => _driverOffline = true);
      } else if (map['status'] == 'online') {
        setState(() => _driverOffline = false);
      }
    });

    _offlineCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || _driverOffline || _phase == _WaitPhase.searching) return;
      final last = _lastDriverUpdate;
      if (last != null && DateTime.now().difference(last).inSeconds > 60) {
        setState(() => _driverOffline = true);
      }
    });

    _socket?.on('rideCancelled', (data) {
      if (!mounted) return;
      final map = Map<String, dynamic>.from(data as Map);
      final cancelledRideId = map['rideId'] as String?;
      if (cancelledRideId != null && _rideId.isNotEmpty && cancelledRideId != _rideId) return;
      ref.read(bookingProvider.notifier).reset();
      ref.read(chatProvider.notifier).disconnect();
      Navigator.pushNamedAndRemoveUntil(context, '/main', (_) => false);
    });

    _socket?.on('cancelApproved', (_) {});
    _socket?.on('cancelRejected', (_) {});

    // Fallback: if driver ends trip while passenger is still on this screen
    // (ONGOING event was missed), navigate home so passenger isn't frozen
    _socket?.on('rideEnded', (data) {
      if (!mounted) return;
      ref.read(bookingProvider.notifier).reset();
      Navigator.pushNamedAndRemoveUntil(context, '/main', (_) => false);
    });

    _socket?.on('rideStatusChanged', (data) {
      if (!mounted) return;
      final map = Map<String, dynamic>.from(data as Map);
      if (_rideId.isNotEmpty && map['rideId'] != _rideId) return;
      final status = map['status'] as String? ?? '';
      if (status == 'PICKUP') {
        ref.read(bookingProvider.notifier).setActive(rideStatus: 'PICKUP');
        setState(() => _phase = _WaitPhase.arrived);
      } else if (status == 'ONGOING') {
        ref.read(bookingProvider.notifier).setActive(rideStatus: 'ONGOING');
        _navigateToTrip();
      } else if (status == 'DONE' || status == 'CANCELLED') {
        ref.read(bookingProvider.notifier).reset();
        Navigator.pushNamedAndRemoveUntil(context, '/main', (_) => false);
      }
    });
  }

  Future<void> _fetchAndRestorePhase() async {
    if (_rideId.isEmpty) {
      if (_isRestoring && mounted) setState(() => _isRestoring = false);
      return;
    }
    try {
      final resp = await DioClient.create().get('/booking/rides/$_rideId');
      if (!mounted) return;
      final data = resp.data as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';
      // Restore coords from API when navigating from FCM tap (no args provided)
      final apiDestLat = num.tryParse(data['destinationLat']?.toString() ?? '')?.toDouble();
      final apiDestLng = num.tryParse(data['destinationLng']?.toString() ?? '')?.toDouble();
      final apiOriginLat = num.tryParse(data['originLat']?.toString() ?? '')?.toDouble();
      final apiOriginLng = num.tryParse(data['originLng']?.toString() ?? '')?.toDouble();
      if (apiDestLat != null && apiDestLng != null) {
        _destLat = apiDestLat;
        _destLng = apiDestLng;
      }
      if (apiOriginLat != null && apiOriginLng != null) {
        _passengerPos = LatLng(apiOriginLat, apiOriginLng);
      }
      // Restore driver info if available
      final driver = data['driver'] as Map<String, dynamic>?;
      if (driver != null) {
        _driverName  = (driver['name']  as String?) ?? _driverName;
        _driverPlate = (driver['vehiclePlate'] as String?) ?? _driverPlate;
        _driverPhone = (driver['phone'] as String?) ?? _driverPhone;
        _driverRating = num.tryParse(driver['rating']?.toString() ?? '')?.toDouble() ?? _driverRating;
      }
      if (status == 'ONGOING') {
        ref.read(bookingProvider.notifier).setActive(rideStatus: 'ONGOING');
        _navigateToTrip();
      } else if (status == 'ACCEPTED' || status == 'PICKUP') {
        ref.read(bookingProvider.notifier).setActive(rideStatus: status);
        setState(() {
          _phase = status == 'PICKUP' ? _WaitPhase.arrived : _WaitPhase.pickup;
          _isRestoring = false;
        });
        _cardSlideController.forward();
        _progressController.stop();
      } else if (status == 'DONE' || status == 'CANCELLED') {
        ref.read(bookingProvider.notifier).reset();
        Navigator.pushNamedAndRemoveUntil(context, '/main', (_) => false);
      } else {
        if (mounted) setState(() => _isRestoring = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  void _navigateToTrip() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      '/trip',
      arguments: TripArgs(
        rideId: _rideId,
        driverName: _driverName,
        driverPlate: _driverPlate,
        driverPhone: _driverPhone,
        driverLat: _driverPos?.latitude ?? _passengerPos.latitude,
        driverLng: _driverPos?.longitude ?? _passengerPos.longitude,
        destLat: _destLat,
        destLng: _destLng,
        initialStatus: 'ONGOING',
      ),
    );
  }

  Future<void> _makeCall(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PassengerChatDetail()),
    );
  }

  // Called after driver approves OR when no driver yet (still searching)
  Future<void> _doHttpCancel() async {
    _socket?.off('rideCancelled');
    _socket?.off('cancelApproved');
    _socket?.off('cancelRejected');
    try {
      if (_rideId.isNotEmpty) {
        await DioClient.create().post('/booking/rides/$_rideId/cancel');
      }
    } catch (_) {}
    if (!mounted) return;
    ref.read(bookingProvider.notifier).reset();
    ref.read(chatProvider.notifier).disconnect();
    Navigator.pushNamedAndRemoveUntil(context, '/main', (_) => false);
  }

  Future<void> _confirmCancel() async {
    // If no driver yet (still searching), cancel directly without approval
    if (_phase == _WaitPhase.searching) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Batalkan Pesanan?',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
          content: Text('Apakah kamu yakin ingin membatalkan?',
              style: GoogleFonts.plusJakartaSans(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Tidak', style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text('Ya, Batalkan',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      if (confirmed == true) _doHttpCancel();
      return;
    }

    // Driver is assigned — passenger can cancel directly
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Batalkan Pesanan?',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: Text('Apakah kamu yakin ingin membatalkan pesanan ini?',
            style: GoogleFonts.plusJakartaSans(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Tidak', style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('Ya, Batalkan',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) _doHttpCancel();
  }

  @override
  void dispose() {
    _dotController.dispose();
    _progressController.dispose();
    _cardSlideController.dispose();
    _pulseController.dispose();
    _dotTimer?.cancel();
    _offlineCheckTimer?.cancel();
    if (_rideId.isNotEmpty) {
      _socket?.emit('leaveRide', {'rideId': _rideId});
    }
    _socket?.disconnect();
    super.dispose();
  }

  Widget _buildAnimatedDot(int index) {
    return AnimatedBuilder(
      animation: _dotController,
      builder: (_, _) {
        final t = ((_dotController.value + index * 0.33) % 1.0);
        final scale = 0.6 + 0.4 * (1 - (2 * t - 1).abs()).clamp(0.0, 1.0);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 10 * scale,
          height: 10 * scale,
          decoration: const BoxDecoration(
            color: AppColors.accentColor,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final driverFound = _phase != _WaitPhase.searching;

    return Scaffold(
      body: Stack(
        children: [
          // Map background
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _passengerPos,
              initialZoom: 14,
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
              MarkerLayer(
                markers: [
                  Marker(
                    point: _passengerPos,
                    width: 48,
                    height: 48,
                    child: _PulseMarker(
                      pulse: _pulse,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryColor.withValues(alpha: 0.35),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_pin_circle_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  if (_driverPos != null)
                    Marker(
                      point: _driverPos!,
                      width: 52,
                      height: 52,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.4, end: 1.0),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutBack,
                        builder: (_, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF2CB05), Color(0xFFE6B800)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.primaryColor, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentColor.withValues(alpha: 0.5),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.electric_moped_rounded,
                            color: AppColors.primaryDark,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (_driverPos != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_driverPos!, _passengerPos],
                      strokeWidth: 3.5,
                      color: AppColors.primaryColor.withValues(alpha: 0.5),
                      isDotted: true,
                    ),
                  ],
                ),
            ],
          ),

          // Gradient overlay at bottom for readability
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: 280,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.08),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Driver offline warning banner
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

          // Re-center button (shown when user has panned/zoomed away)
          if (_userInteracted)
            Positioned(
              top: 120, right: 16,
              child: GestureDetector(
                onTap: () {
                  setState(() => _userInteracted = false);
                  final target = _driverPos ?? _passengerPos;
                  try { _mapController.move(target, 14); } catch (_) {}
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

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Status card ──
                  _buildStatusCard(driverFound),

                  const Spacer(),

                  // ── Driver info card (slides up when driver found) ──
                  if (driverFound)
                    SlideTransition(
                      position: _cardSlide,
                      child: _buildDriverCard(),
                    )
                  else
                    TextButton.icon(
                      onPressed: _confirmCancel,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: Text(
                        'Batalkan Pesanan',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool driverFound) {
    if (_isRestoring) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Memuat perjalanan...',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppColors.primaryColor,
              ),
            ),
          ],
        ),
      );
    }
    final isArrived = _phase == _WaitPhase.arrived;
    final Color iconBgStart = driverFound
        ? (isArrived ? const Color(0xFF16A34A) : const Color(0xFF0540F2))
        : const Color(0xFF0540F2);
    final Color iconBgEnd = driverFound
        ? (isArrived ? const Color(0xFF22C55E) : const Color(0xFF056CF2))
        : const Color(0xFF056CF2);

    String title;
    String subtitle;
    switch (_phase) {
      case _WaitPhase.searching:
        title = 'Mencari Driver Terdekat';
        subtitle = 'Mohon tunggu sebentar...';
      case _WaitPhase.pickup:
        title = 'Driver Menuju Lokasimu';
        subtitle = 'Driver sudah dalam perjalanan menuju titik jemput';
      case _WaitPhase.arrived:
        title = 'Driver Sudah Tiba!';
        subtitle = 'Silakan naik ke kendaraan driver';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [iconBgStart, iconBgEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconBgEnd.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Icon(
                driverFound
                    ? (isArrived
                        ? Icons.person_pin_circle_rounded
                        : Icons.electric_moped_rounded)
                    : Icons.search_rounded,
                key: ValueKey(_phase),
                color: Colors.white,
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              title,
              key: ValueKey(title),
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: driverFound
                    ? (isArrived ? AppColors.online : AppColors.primaryColor)
                    : AppColors.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              subtitle,
              key: ValueKey(subtitle),
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (_phase == _WaitPhase.searching) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, _buildAnimatedDot),
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _progressController,
              builder: (_, _) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progressController.value,
                  minHeight: 6,
                  backgroundColor: AppColors.primaryLight,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.accentColor),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDriverCard() {
    final isArrived = _phase == _WaitPhase.arrived;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withValues(alpha: 0.14),
            blurRadius: 32,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Gradient header strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isArrived
                    ? [const Color(0xFF16A34A), const Color(0xFF22C55E)]
                    : [const Color(0xFF04198C), const Color(0xFF0540F2)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Row(
              children: [
                Icon(
                  isArrived
                      ? Icons.person_pin_circle_rounded
                      : Icons.navigation_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isArrived
                      ? 'Driver Sudah Tiba — Silakan Naik!'
                      : 'Driver Menuju Lokasi Penjemputan',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Driver info row
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0540F2), Color(0xFF056CF2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _driverName.isNotEmpty
                              ? _driverName[0].toUpperCase()
                              : 'D',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Name + rating + plate
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _driverName.isNotEmpty ? _driverName : 'Driver',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: AppColors.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Color(0xFFFFB800), size: 15),
                              const SizedBox(width: 3),
                              Text(
                                _driverRating.toStringAsFixed(1),
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _driverPlate,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: AppColors.primaryColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // ETA chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accentColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isArrived ? 'Sudah tiba' : _driverEta,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Chat + Phone action buttons
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.chat_bubble_rounded,
                        label: 'Chat',
                        color: AppColors.primaryColor,
                        onTap: _openChat,
                      ),
                    ),
                    if (_driverPhone.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.phone_rounded,
                          label: 'Telepon',
                          color: const Color(0xFF22C55E),
                          onTap: () => _makeCall(_driverPhone),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 4),
                Center(
                    child: TextButton.icon(
                      onPressed: _confirmCancel,
                      icon: const Icon(Icons.cancel_outlined, size: 15),
                      label: Text('Batalkan Pesanan',
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444)),
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

// ── Supporting widgets ──────────────────────────────────────────────────────

class _PulseMarker extends StatelessWidget {
  const _PulseMarker({required this.pulse, required this.child});
  final Animation<double> pulse;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: pulse,
        builder: (_, c) => Transform.scale(scale: pulse.value, child: c),
        child: child,
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
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
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
}

enum _WaitPhase { searching, pickup, arrived }
