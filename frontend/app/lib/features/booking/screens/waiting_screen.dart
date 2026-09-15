import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../core/widgets/lungo_snackbar.dart';
import '../../passenger/providers/chat_provider.dart';
import '../../passenger/screens/passenger_chat_screen.dart';
import '../../shared/widgets/trip/map_pin_marker.dart';
import '../../shared/widgets/trip/trip_tracking_card.dart';
import '../../shared/widgets/trip/tracking_timeline.dart';
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

  DateTime? _tsCreated;
  DateTime? _tsAccepted;
  DateTime? _tsArrived;

  io.Socket? _socket;
  Timer? _offlineCheckTimer;

  bool _driverOffline = false;
  DateTime? _lastDriverUpdate;

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

  bool _initialized = false;
  bool _userInteracted = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _tsCreated = DateTime.now();
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

    _socket?.on('rideAccepted', (data) {
      if (!mounted) return;
      final map = Map<String, dynamic>.from(data as Map);
      if (_rideId.isNotEmpty && map['rideId'] != _rideId) return;
      setState(() {
        _driverName   = (map['driverName']  as String?) ?? 'Driver';
        _driverPlate  = (map['driverPlate'] as String?) ?? '-';
        _driverPhone  = (map['driverPhone'] as String?) ?? '';
        _driverRating = num.tryParse(map['driverRating']?.toString() ?? '')?.toDouble() ?? 5.0;
        _phase = _WaitPhase.pickup;
        _tsAccepted = DateTime.now();
      });
      ref.read(bookingProvider.notifier).setActive(rideStatus: 'ACCEPTED');
      if (_rideId.isNotEmpty) {
        ref.read(chatProvider.notifier).connect(_rideId);
      }
      if (_driverName.isNotEmpty || _driverPhone.isNotEmpty) {
        ref.read(chatProvider.notifier).setDriverInfo(_driverName, _driverPhone);
      }
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
        setState(() {
          _phase = _WaitPhase.arrived;
          _tsArrived = DateTime.now();
        });
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
          _tsAccepted ??= DateTime.now();
          if (status == 'PICKUP') _tsArrived ??= DateTime.now();
        });
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
    _offlineCheckTimer?.cancel();
    if (_rideId.isNotEmpty) {
      _socket?.emit('leaveRide', {'rideId': _rideId});
    }
    _socket?.disconnect();
    super.dispose();
  }

  List<TrackingStep> get _timelineSteps {
    final driverFound = _phase != _WaitPhase.searching;
    final isArrived = _phase == _WaitPhase.arrived;
    return [
      TrackingStep(label: 'Pesanan Dibuat', timestamp: _tsCreated, done: true),
      TrackingStep(label: 'Driver Diterima', timestamp: _tsAccepted, done: driverFound),
      TrackingStep(label: 'Driver Menuju Lokasi', timestamp: _tsAccepted, done: driverFound),
      TrackingStep(label: 'Penjemputan', timestamp: _tsArrived, done: isArrived),
      const TrackingStep(label: 'Dalam Perjalanan', done: false),
      const TrackingStep(label: 'Selesai', done: false),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final driverFound = _phase != _WaitPhase.searching;

    return Scaffold(
      body: Stack(
        children: [

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
                    child: const MapPinMarker(
                      icon: Icons.person_pin_circle_rounded,
                      fillColor: AppColors.primaryColor,
                      pulsing: true,
                    ),
                  ),
                  if (_driverPos != null)
                    Marker(
                      point: _driverPos!,
                      width: 52,
                      height: 52,
                      child: const MapPinMarker(
                        icon: Icons.electric_moped_rounded,
                        fillColor: AppColors.accentColor,
                        borderColor: AppColors.primaryColor,
                        iconColor: AppColors.primaryDark,
                        size: 52,
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

          if (_isRestoring)
            Center(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 40),
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
                  mainAxisSize: MainAxisSize.min,
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
              ),
            )
          else
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: TripTrackingCard(
                idLabel: _rideId.isNotEmpty ? '#Order: $_rideId' : '#Order: -',
                onCopyId: _rideId.isEmpty
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: _rideId));
                        LungoSnackbar.success(context, 'ID disalin');
                      },
                title: switch (_phase) {
                  _WaitPhase.searching => 'Mencari Driver Terdekat',
                  _WaitPhase.pickup => 'Driver Menuju Lokasimu',
                  _WaitPhase.arrived => 'Driver Sudah Tiba!',
                },
                originText: 'Lokasi kamu',
                destText: 'Tujuan',
                statusText: switch (_phase) {
                  _WaitPhase.searching => 'Mencari',
                  _WaitPhase.pickup => 'Menuju',
                  _WaitPhase.arrived => 'Tiba',
                },
                statusColor: switch (_phase) {
                  _WaitPhase.searching => AppColors.offline,
                  _WaitPhase.pickup => AppColors.secondaryColor,
                  _WaitPhase.arrived => AppColors.online,
                },
                contactName: driverFound
                    ? (_driverName.isNotEmpty ? _driverName : 'Driver')
                    : null,
                onCallTap: (driverFound && _driverPhone.isNotEmpty)
                    ? () => _makeCall(_driverPhone)
                    : null,
                timelineSteps: _timelineSteps,
                footer: driverFound
                    ? Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.chat_bubble_rounded,
                              label: 'Chat',
                              color: AppColors.primaryColor,
                              onTap: _openChat,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.cancel_outlined,
                              label: 'Batalkan',
                              color: const Color(0xFFEF4444),
                              onTap: _confirmCancel,
                            ),
                          ),
                        ],
                      )
                    : TextButton.icon(
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
              ),
            ),
        ],
      ),
    );
  }

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
