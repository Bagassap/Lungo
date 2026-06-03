import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../booking/providers/booking_provider.dart';
import '../../booking/screens/trip_screen.dart';
import '../../shared/providers/nav_tab_provider.dart';

const _kPromo = Color(0xFFFF6B35);

class PassengerHomeScreen extends ConsumerStatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  ConsumerState<PassengerHomeScreen> createState() => _HomeState();
}

class _HomeState extends ConsumerState<PassengerHomeScreen>
    with TickerProviderStateMixin {

  final _map = MapController();
  final _dio = ApiClient.create();
  static const _defaultPos = LatLng(-6.9175, 107.6191);
  LatLng _pos           = _defaultPos;
  List<_Driver> _drivers = [];
  int   _driverCount    = 0;
  List<_Dest> _dests    = [];
  bool  _gpsLoading     = true;
  String _locationLabel = 'Mencari lokasi...';
  Timer? _timer;

  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double>   _topFade;
  late Animation<Offset>   _topSlide;
  late Animation<double>   _bottomFade;
  late Animation<Offset>   _bottomSlide;
  late Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));

    _topFade = CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut));
    _topSlide =
        Tween<Offset>(begin: const Offset(0, -0.06), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _entryCtrl,
                curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic)));

    _bottomFade = CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.2, 0.9, curve: Curves.easeOut));
    _bottomSlide =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _entryCtrl,
                curve: const Interval(0.2, 0.9, curve: Curves.easeOutCubic)));

    _pulse = Tween<double>(begin: 1.0, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _pulseCtrl.repeat(reverse: true);
    _entryCtrl.forward();
    _initGps();
    ref.read(bookingProvider.notifier).restoreFromStorage();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initGps() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _gpsLoading = false;
            _locationLabel = 'Aktifkan GPS';
          });
        }
        await _refresh();
        _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _gpsLoading = false;
            _locationLabel = 'Izin lokasi ditolak';
          });
        }
        await _refresh();
        _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
        return;
      }
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        if (mounted) {
          setState(() {
            _pos = LatLng(p.latitude, p.longitude);
            _gpsLoading = false;
          });
          try { _map.move(_pos, 16); } catch (_) {}
          ref.read(locationProvider.notifier).update(p.latitude, p.longitude);
          _fetchLocation(p.latitude, p.longitude);
        }
      } else {
        if (mounted) {
          setState(() {
            _gpsLoading = false;
            _locationLabel = 'Lokasi tidak diketahui';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _gpsLoading = false;
          _locationLabel = 'Lokasi tidak diketahui';
        });
      }
    }
    await _refresh();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  Future<void> _fetchLocation(double lat, double lng) async {
    try {
      final r = await Dio().get(
        'https://revgeocode.search.hereapi.com/v1/revgeocode',
        queryParameters: {
          'at': '$lat,$lng',
          'lang': 'id',
          'apiKey': ApiConstants.hereApiKey,
        },
      );
      final items = r.data['items'] as List? ?? [];
      if (items.isEmpty) {
        if (mounted) setState(() => _locationLabel = 'Lokasi Anda');
        return;
      }
      final address  = items[0]['address'] as Map? ?? {};
      final district = address['district'] as String? ?? '';
      final county   = address['county']   as String? ?? '';
      final city     = address['city']     as String? ?? '';
      final street   = address['street']   as String? ?? '';
      final area     = district.isNotEmpty ? district
                     : county.isNotEmpty   ? county
                     : city.isNotEmpty     ? city
                     : street;
      final cityLabel = city.isNotEmpty ? city : county;
      final label = (area.isNotEmpty && cityLabel.isNotEmpty && area != cityLabel)
          ? '$area, $cityLabel'
          : area.isNotEmpty ? area : 'Lokasi Anda';
      if (mounted) setState(() => _locationLabel = label);
    } catch (_) {
      if (mounted) setState(() => _locationLabel = 'Lokasi Anda');
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await Future.wait([_fetchDrivers(), _fetchCount(), _fetchDests()]);
  }

  Future<void> _fetchDrivers() async {
    try {
      final r = await _dio.get('/tracking/drivers/nearby', queryParameters: {
        'lat': _pos.latitude, 'lng': _pos.longitude, 'radius': 3,
      });
      final list = r.data is List ? r.data as List : <dynamic>[];
      if (mounted) {
        setState(() => _drivers = list
            .map((d) => _Driver.fromJson(Map<String, dynamic>.from(d as Map)))
            .toList());
      }
    } catch (_) {}
  }

  Future<void> _fetchCount() async {
    try {
      final r = await _dio.get('/tracking/drivers/count',
          queryParameters: {'lat': _pos.latitude, 'lng': _pos.longitude});
      if (mounted) {
        final data = r.data;
        setState(() => _driverCount = data is Map
            ? (data['count'] as num?)?.toInt() ?? 0
            : (data as num?)?.toInt() ?? 0);
      }
    } catch (_) {
      if (mounted) setState(() => _driverCount = _drivers.length);
    }
  }

  Future<void> _fetchDests() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    try {
      final r = await _dio.get('/users/last-destinations/${user.id}',
          queryParameters: {'lat': _pos.latitude, 'lng': _pos.longitude});
      final list = r.data is List ? r.data as List : <dynamic>[];
      if (!mounted) return;
      if (list.isEmpty) return;
      setState(() => _dests = list
          .map((d) => _Dest.fromJson(Map<String, dynamic>.from(d as Map)))
          .toList());
    } catch (_) {}
  }

  void _goDest() {
    final booking = ref.read(bookingProvider);
    if (booking.status == BookingStatus.active ||
        booking.status == BookingStatus.searching) {
      unawaited(_returnToTrip());
      return;
    }
    Navigator.pushNamed(context, '/destination');
  }

  Future<void> _returnToTrip() async {

    if (ref.read(bookingProvider).ride != null) {
      await ref.read(bookingProvider.notifier).refreshRide();
    } else {
      await ref.read(bookingProvider.notifier).restoreFromStorage();
    }

    final booking = ref.read(bookingProvider);
    final ride = booking.ride;

    if (ride == null) {
      return;
    }

    final status = ride.status.toUpperCase();

    if (!mounted) return;

    switch (status) {
      case 'ONGOING':
        ref.read(bookingProvider.notifier).setActive(rideStatus: 'ONGOING');
        Navigator.pushNamed(context, '/trip', arguments: TripArgs(
          rideId: ride.id,
          initialStatus: 'ONGOING',
          driverName: ride.driverName ?? 'Driver',
          driverPlate: ride.driverPlate ?? '-',
          driverPhone: ride.driverPhone ?? '',
          driverLat: ride.originLat,
          driverLng: ride.originLng,
          destLat: ride.destinationLat,
          destLng: ride.destinationLng,
        ));
        break;
      case 'ACCEPTED':
        ref.read(bookingProvider.notifier).setActive(rideStatus: 'ACCEPTED');
        Navigator.pushNamed(context, '/waiting',
            arguments: {'rideId': ride.id, 'restore': true});
        break;
      case 'PICKUP':
        ref.read(bookingProvider.notifier).setActive(rideStatus: 'PICKUP');
        Navigator.pushNamed(context, '/waiting',
            arguments: {'rideId': ride.id, 'restore': true});
        break;
      case 'SEARCHING':
        Navigator.pushNamed(context, '/waiting',
            arguments: {'rideId': ride.id, 'restore': false});
        break;
      default:
        ref.read(bookingProvider.notifier).reset();
        await SecureStorage.clearPassengerRideId();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user    = ref.watch(authProvider).user;
    final name    = user?.name ?? 'Penumpang';
    final count   = _driverCount > 0 ? _driverCount : _drivers.length;
    final booking = ref.watch(bookingProvider);
    final tripActive = booking.status == BookingStatus.active ||
        booking.status == BookingStatus.searching;

    return Scaffold(
      body: Stack(
        children: [

          _OSMMap(pos: _pos, drivers: _drivers, mapCtrl: _map),

          Positioned(
            top: 0, left: 0, right: 0,
            child: FadeTransition(
              opacity: _topFade,
              child: SlideTransition(
                position: _topSlide,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(
                      name: name,
                      gpsLoading: _gpsLoading,
                      locationLabel: _locationLabel,
                      onAvatarTap: () =>
                          ref.read(navTabProvider.notifier).state = 3,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _SearchBar(
                        onTap: tripActive
                            ? () => _returnToTrip()
                            : _goDest,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (!tripActive)
            Positioned(
              bottom: 368, left: 0, right: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: count > 0 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, child) =>
                        Transform.scale(scale: _pulse.value, child: child),
                    child: _DriverBadge(count: count),
                  ),
                ),
              ),
            ),

          if (!tripActive)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: FadeTransition(
                opacity: _bottomFade,
                child: SlideTransition(
                  position: _bottomSlide,
                  child: _BottomSheet(
                    dests: _dests,
                    onOjek: _goDest,
                    onDestTap: _goDest,
                    onLihatSemua: _goDest,
                  ),
                ),
              ),
            ),

          if (tripActive)
            Positioned(
              bottom: 16, left: 16, right: 16,
              child: _TripActiveBanner(
                onTap: () => _returnToTrip(),
                isSearching: booking.status == BookingStatus.searching,
              ),
            ),
        ],
      ),
    );
  }
}

class _OSMMap extends StatelessWidget {
  final LatLng pos;
  final List<_Driver> drivers;
  final MapController mapCtrl;
  const _OSMMap({required this.pos, required this.drivers, required this.mapCtrl});

  @override
  Widget build(BuildContext context) => FlutterMap(
        mapController: mapCtrl,
        options: MapOptions(
          initialCenter: pos,
          initialZoom: 16,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: ApiConstants.hereTileUrl,
            userAgentPackageName: 'com.lungo.app',
            maxNativeZoom: 19,
            maxZoom: 19,
          ),
          MarkerLayer(markers: [

            Marker(
              point: pos, width: 52, height: 52,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryColor.withValues(alpha: 0.45),
                      blurRadius: 14, spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.person_pin_circle_rounded,
                    color: Colors.white, size: 26),
              ),
            ),

            ...drivers.map((d) => Marker(
                  point: LatLng(d.lat, d.lng),
                  width: 38, height: 38,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accentColor, width: 2),
                    ),
                    child: const Icon(Icons.electric_moped_rounded,
                        color: Colors.white, size: 18),
                  ),
                )),
          ]),
        ],
      );
}

class _TopBar extends StatelessWidget {
  final String name;
  final bool gpsLoading;
  final String locationLabel;
  final VoidCallback onAvatarTap;
  const _TopBar({
    required this.name,
    required this.gpsLoading,
    required this.locationLabel,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0540F2), Color(0xFF04198C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x440540F2),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.electric_moped_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Lungo',
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onAvatarTap,
                    child: CircleAvatar(
                      radius: 19,
                      backgroundColor: Colors.white.withValues(alpha: 0.22),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontFamily: 'Satoshi',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_rounded,
                      color: Colors.white70, size: 15),
                  const SizedBox(width: 4),
                  Text(
                    gpsLoading ? 'Mencari lokasi...' : locationLabel,
                    style: const TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.white70, size: 17),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primaryLight,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryColor.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded,
                    color: AppColors.primaryColor, size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Mau ke mana hari ini?',
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _DriverBadge extends StatelessWidget {
  final int count;
  const _DriverBadge({required this.count});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.accentColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentColor.withValues(alpha: 0.55),
              blurRadius: 14, spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.electric_moped_rounded,
                color: AppColors.primaryDark, size: 15),
            const SizedBox(width: 6),
            Text(
              '$count Driver Aktif',
              style: const TextStyle(
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      );
}

class _BottomSheet extends StatelessWidget {
  final List<_Dest> dests;
  final VoidCallback onOjek;
  final VoidCallback onDestTap;
  final VoidCallback onLihatSemua;

  const _BottomSheet({
    required this.dests,
    required this.onOjek,
    required this.onDestTap,
    required this.onLihatSemua,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: 300,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A0540F2),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              _OjekButton(onTap: onOjek),
              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tujuan Terakhir',
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  GestureDetector(
                    onTap: onLihatSemua,
                    child: const Text(
                      'Lihat Semua',
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kPromo,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              ...dests.take(3).map(
                    (d) => _DestItem(dest: d, onTap: onDestTap),
                  ),
            ],
          ),
        ),
      );
}

class _OjekButton extends StatefulWidget {
  final VoidCallback onTap;
  const _OjekButton({required this.onTap});

  @override
  State<_OjekButton> createState() => _OjekButtonState();
}

class _OjekButtonState extends State<_OjekButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: Duration(milliseconds: _pressed ? 80 : 350),
          curve: _pressed ? Curves.easeIn : Curves.elasticOut,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0540F2), Color(0xFF04198C)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0540F2).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [

                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.electric_moped_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pesan Ojek',
                        style: TextStyle(
                          fontFamily: 'Satoshi',
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Antar jemput cepat & aman',
                        style: TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2CB05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF04198C),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _DestItem extends StatelessWidget {
  final _Dest dest;
  final VoidCallback onTap;
  const _DestItem({required this.dest, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: AppColors.primaryLight,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.access_time_rounded,
                    color: AppColors.secondaryColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dest.name,
                      style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${dest.distanceKm} km',
                      style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary, size: 18),
            ],
          ),
        ),
      );
}

class _TripActiveBanner extends StatelessWidget {
  final VoidCallback onTap;
  final bool isSearching;
  const _TripActiveBanner({required this.onTap, required this.isSearching});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF04198C),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0540F2).withValues(alpha: 0.45),
                blurRadius: 18, spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Icon(Icons.electric_moped_rounded,
                        color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSearching ? 'Mencari Driver...' : 'Perjalanan Aktif',
                      style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      isSearching
                          ? 'Mohon tunggu, driver sedang dicari'
                          : 'Ketuk untuk kembali ke perjalanan',
                      style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2CB05),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.arrow_forward_rounded,
                    color: Color(0xFF04198C), size: 18),
              ),
            ],
          ),
        ),
      );
}

class _Driver {
  final double lat, lng, dist;
  const _Driver({required this.lat, required this.lng, required this.dist});
  factory _Driver.fromJson(Map<String, dynamic> j) => _Driver(
        lat:  (j['latitude']   as num).toDouble(),
        lng:  (j['longitude']  as num).toDouble(),
        dist: (j['distanceKm'] as num).toDouble(),
      );
}

class _Dest {
  final String name;
  final double distanceKm;
  const _Dest({required this.name, required this.distanceKm});
  factory _Dest.fromJson(Map<String, dynamic> j) => _Dest(
        name:       j['name']       as String? ?? 'Tujuan',
        distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0.0,
      );
}
