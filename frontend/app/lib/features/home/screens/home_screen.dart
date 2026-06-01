import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lungo_button.dart';
import '../../../core/widgets/lungo_text_field.dart';
import '../../auth/providers/auth_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final MapController _mapController = MapController();
  final _destinationController = TextEditingController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  static const _defaultCenter = LatLng(-6.9175, 107.6191);

  LatLng _userLocation = _defaultCenter;
  List<_NearbyDriver> _nearbyDrivers = [];
  bool _isSearching = false;
  bool _expandedSearch = false;
  bool _loadingLocation = true;
  Timer? _refreshTimer;
  final Dio _dio = ApiClient.create();

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        if (mounted) {
          setState(() {
            _userLocation = LatLng(pos.latitude, pos.longitude);
            _loadingLocation = false;
          });
          _mapController.move(_userLocation, 15);
        }
      } else {
        setState(() => _loadingLocation = false);
      }
    } catch (_) {

      setState(() => _loadingLocation = false);
    }

    await _fetchNearbyDrivers();

    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _fetchNearbyDrivers();
    });
  }

  Future<void> _fetchNearbyDrivers() async {
    try {
      final resp = await _dio.get(
        '/tracking/drivers/nearby',
        queryParameters: {
          'lat': _userLocation.latitude,
          'lng': _userLocation.longitude,
          'radius': 3,
        },
      );

      final List<dynamic> raw = resp.data is List ? resp.data as List : [];
      final drivers = raw
          .map(
            (d) => _NearbyDriver.fromJson(Map<String, dynamic>.from(d as Map)),
          )
          .toList();

      if (mounted) {
        setState(() {
          _nearbyDrivers = drivers;
          _expandedSearch =
              drivers.isNotEmpty && (drivers.first.distanceKm > 3.0);
        });
      }
    } catch (_) {

    }
  }

  void _orderRide() {
    if (_destinationController.text.trim().isEmpty) return;
    Navigator.pushNamed(context, '/waiting');
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).status == AuthStatus.loading;

    return Scaffold(
      body: Stack(
        children: [

          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation,
              initialZoom: 15,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: ApiConstants.hereTileUrl,
                userAgentPackageName: 'com.lungo.passenger_app',
              ),
              MarkerLayer(
                markers: [

                  Marker(
                    point: _userLocation,
                    width: 48,
                    height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryColor.withValues(
                              alpha: 0.4,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_pin_circle_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),

                  ..._nearbyDrivers.map(
                    (driver) => Marker(
                      point: LatLng(driver.latitude, driver.longitude),
                      width: 44,
                      height: 44,
                      child: Tooltip(
                        message: '${driver.distanceKm.toStringAsFixed(1)} km',
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.accentColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryColor,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryColor.withValues(
                                  alpha: 0.25,
                                ),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.electric_moped_rounded,
                            color: AppColors.primaryDark,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.electric_moped_rounded,
                          color: AppColors.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ref.watch(authProvider).user?.name ?? 'Lungo',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.primaryColor,
                              ),
                            ),
                            Text(
                              ref.watch(authProvider).user?.role ?? '',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  if (_nearbyDrivers.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.electric_moped_rounded,
                            color: AppColors.primaryDark,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_nearbyDrivers.length}',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        await ref.read(authProvider.notifier).logout();
                        nav.pushNamedAndRemoveUntil('/login', (_) => false);
                      },
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: AppColors.primaryColor,
                      ),
                      tooltip: 'Logout',
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_expandedSearch)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.radar_rounded,
                        color: AppColors.accentColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Memperluas pencarian ke 5km...',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.32,
            minChildSize: 0.2,
            maxChildSize: 0.75,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1A0540F2),
                      blurRadius: 24,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Mau ke mana?',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),

                    Row(
                      children: [
                        Icon(
                          _nearbyDrivers.isEmpty
                              ? Icons.search_rounded
                              : Icons.check_circle_rounded,
                          size: 14,
                          color: _nearbyDrivers.isEmpty
                              ? AppColors.textSecondary
                              : AppColors.online,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _loadingLocation
                              ? 'Mencari lokasi...'
                              : _nearbyDrivers.isEmpty
                              ? 'Tidak ada driver terdekat'
                              : '${_nearbyDrivers.length} driver tersedia terdekat',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: _nearbyDrivers.isEmpty
                                ? AppColors.textSecondary
                                : AppColors.online,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LungoTextField(
                      controller: _destinationController,
                      label: 'Tujuan',
                      hint: 'Cari tujuan kamu...',
                      prefixIcon: const Icon(Icons.location_on_rounded),
                      onChanged: (v) =>
                          setState(() => _isSearching = v.isNotEmpty),
                    ),
                    const SizedBox(height: 20),
                    if (!_isSearching) ...[
                      Text(
                        'Tujuan Terakhir',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _recentDestination('Alun-Alun Bandung', '2.3 km'),
                      _recentDestination('Braga City Walk', '3.1 km'),
                      _recentDestination('Trans Studio Bandung', '5.6 km'),
                      const SizedBox(height: 8),
                    ],
                    LungoButton(
                      label: 'Pesan Ojek',
                      onPressed: _isSearching ? _orderRide : null,
                      isLoading: isLoading,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _recentDestination(String name, String distance) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          _destinationController.text = name;
          setState(() => _isSearching = true);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.history_rounded,
                color: AppColors.secondaryColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                distance,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbyDriver {
  final String driverId;
  final double latitude;
  final double longitude;
  final double distanceKm;

  const _NearbyDriver({
    required this.driverId,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
  });

  factory _NearbyDriver.fromJson(Map<String, dynamic> json) => _NearbyDriver(
    driverId: json['driverId']?.toString() ?? '',
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    distanceKm: (json['distanceKm'] as num).toDouble(),
  );
}
