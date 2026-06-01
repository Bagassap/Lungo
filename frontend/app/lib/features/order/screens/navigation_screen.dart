import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../driver/providers/driver_chat_provider.dart';
import '../../driver/screens/driver_chat_screen.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key});
  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  final MapController _mapCtrl = MapController();

  io.Socket? _socket;
  Timer? _gpsTimer;

  LatLng _driverPos = const LatLng(-6.9100, 107.6140);
  LatLng _pickupPos = const LatLng(-6.9218, 107.6066);

  late Map<String, dynamic> _rideData;

  String get _rideId => (_rideData['rideId'] as String?) ?? '';
  String get _passengerName =>
      (_rideData['passengerName'] as String?) ?? 'Penumpang';
  String get _pickupLabel =>
      (_rideData['originAddress'] as String?) ?? 'Titik Jemput';

  bool _isConfirming = false;
  bool _initialized = false;
  bool _userInteracted = false;

  double _parseDouble(dynamic v, [double fallback = 0.0]) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    _connectSocket();
    _startGpsTracking();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    _rideData = (args is Map<String, dynamic>) ? args : {};

    final originLat = _parseDouble(_rideData['originLat'], -6.9218);
    final originLng = _parseDouble(_rideData['originLng'], 107.6066);
    _pickupPos = LatLng(originLat, originLng);

    // Connect driver chat so messages sync immediately
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

    _socket!.onConnect((_) async {
      _socket!.emit('driverOnline', {
        'driverId': driverId,
        'latitude': _driverPos.latitude,
        'longitude': _driverPos.longitude,
      });
      // Join ride room so we receive rideCancelled scoped to this ride
      if (_rideId.isNotEmpty) {
        _socket!.emit('joinRide', {'rideId': _rideId});
      }
    });

    // If passenger cancels while driver is navigating to pickup, go back home
    _socket!.on('rideCancelled', (data) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    });

    _socket!.connect();
  }

  Future<void> _startGpsTracking() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm != LocationPermission.always &&
        perm != LocationPermission.whileInUse) {
      return;
    }

    final driverId = await SecureStorage.getUserId();
    _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        if (!mounted) return;
        final newPos = LatLng(pos.latitude, pos.longitude);
        setState(() => _driverPos = newPos);
        if (!_userInteracted) {
          try { _mapCtrl.move(newPos, 15); } catch (_) {}
        }
        _socket?.emit('updateLocation', {
          'driverId': driverId,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'rideId': _rideId,
        });
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _openMapsNavigation() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${_driverPos.latitude},${_driverPos.longitude}'
      '&destination=${_pickupPos.latitude},${_pickupPos.longitude}'
      '&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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

  Future<void> _confirmPickup() async {
    if (_isConfirming) return;
    setState(() => _isConfirming = true);

    try {
      if (_rideId.isNotEmpty) {
        await DioClient.create().patch('/booking/rides/$_rideId/status',
            data: {'status': 'PICKUP'});
      }
    } catch (_) {}

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/trip-driver',
        arguments: _rideData);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(driverChatProvider);
    final hasPhone = (chatState.passengerPhone ?? '').isNotEmpty;
    final initial = _passengerName.isNotEmpty
        ? _passengerName[0].toUpperCase()
        : 'P';

    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: LatLng(
                (_driverPos.latitude + _pickupPos.latitude) / 2,
                (_driverPos.longitude + _pickupPos.longitude) / 2,
              ),
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
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [_driverPos, _pickupPos],
                    strokeWidth: 5,
                    color: AppColors.primaryColor,
                    isDotted: true,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _driverPos,
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
                            color: AppColors.primaryColor.withValues(alpha: 0.4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.electric_moped_rounded,
                          color: Colors.white, size: 26),
                    ),
                  ),
                  Marker(
                    point: _pickupPos,
                    width: 52, height: 52,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.primaryColor, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentColor.withValues(alpha: 0.4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.person_pin_rounded,
                          color: AppColors.primaryDark, size: 26),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Gradient overlay
          Positioned(
            bottom: 0, left: 0, right: 0, height: 260,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.06),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Top nav bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
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
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.navigation_rounded,
                          color: AppColors.accentColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Menuju Titik Jemput',
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Colors.white),
                          ),
                          Text(
                            _pickupLabel,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.7)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _openMapsNavigation,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.open_in_new_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Re-center button (shown when user has panned/zoomed away)
          if (_userInteracted)
            Positioned(
              bottom: 220, right: 16,
              child: GestureDetector(
                onTap: () {
                  setState(() => _userInteracted = false);
                  try { _mapCtrl.move(_driverPos, 15); } catch (_) {}
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
                  // Drag handle
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
                              'Menunggu di $_pickupLabel',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionBtn(
                          icon: Icons.map_rounded,
                          label: 'Maps',
                          color: const Color(0xFFE85D04),
                          onTap: _openMapsNavigation,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Confirm pickup button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isConfirming ? null : _confirmPickup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentColor,
                        foregroundColor: AppColors.primaryDark,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: AppColors.accentColor.withValues(alpha: 0.5),
                      ),
                      icon: _isConfirming
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.primaryColor))
                          : const Icon(Icons.check_circle_rounded, size: 22),
                      label: Text(
                        'Penumpang Sudah Naik',
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
    );
  }
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
