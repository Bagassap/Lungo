import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_theme.dart';

const _kGreen  = Color(0xFF16A34A);
const _kOrange = Color(0xFFFF6B35);

class HomeContent extends StatefulWidget {
  final VoidCallback? onHistoryTap;
  const HomeContent({super.key, this.onHistoryTap});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent>
    with TickerProviderStateMixin {

  io.Socket? _socket;

  bool   _isOnline   = false;
  bool   _isToggling = false;
  String _driverName = 'Driver';
  String _greeting   = 'Selamat Pagi';

  final _map           = MapController();
  static const _bandung = LatLng(-6.9175, 107.6191);
  LatLng _pos          = _bandung;
  bool   _gpsLoading   = true;

  int    _todayTrips    = 0;
  double _todayEarnings = 0;
  double _todayKm       = 0;
  double _rating        = 4.9;
  double _todayTarget   = 200000;

  List<_TripRecord> _recentTrips = [];
  List<_HotZone>    _hotZones    = [];

  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double>   _topFade;
  late Animation<Offset>   _topSlide;
  late Animation<double>   _bottomFade;
  late Animation<Offset>   _bottomSlide;
  late Animation<double>   _pulse;

  final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _setGreeting();
    _setupAnims();
    _initGps();
    _loadData();
    _connectSocket();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  void _setGreeting() {
    final h = DateTime.now().hour;
    _greeting = h < 12 ? 'Selamat Pagi'
              : h < 15 ? 'Selamat Siang'
              : h < 18 ? 'Selamat Sore'
              :           'Selamat Malam';
  }

  void _setupAnims() {
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
                curve:
                    const Interval(0.0, 0.65, curve: Curves.easeOutCubic)));

    _bottomFade = CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.2, 0.9, curve: Curves.easeOut));
    _bottomSlide =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _entryCtrl,
                curve:
                    const Interval(0.2, 0.9, curve: Curves.easeOutCubic)));

    _pulse = Tween<double>(begin: 1.0, end: 1.05).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _pulseCtrl.repeat(reverse: true);
    _entryCtrl.forward();
  }

  Future<void> _connectSocket() async {
    final token = await SecureStorage.getAccessToken();
    _socket = io.io(
      '${ApiConstants.wsUrl}${ApiConstants.trackingNamespace}',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .disableAutoConnect()
          .build(),
    );
    _socket!.connect();
    _socket!.on('newRideRequest', (data) {
      if (!mounted || !_isOnline) return;
      Navigator.pushNamed(context, '/order',
          arguments: Map<String, dynamic>.from(data as Map));
    });
  }

  Future<void> _initGps() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        final p = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        if (mounted) {
          setState(() {
            _pos        = LatLng(p.latitude, p.longitude);
            _gpsLoading = false;
          });
          _map.move(_pos, 15);
        }
      } else {
        if (mounted) setState(() => _gpsLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  Future<void> _loadData() async {
    final name = await SecureStorage.getUserName();
    if (mounted) setState(() => _driverName = name ?? 'Driver');

    final dio = DioClient.create();

    try {
      final r = await dio.get('/drivers/profile');
      final d = r.data as Map<String, dynamic>;
      if (mounted) {
        setState(() => _isOnline = (d['isOnline'] as bool?) ?? false);
      }
    } catch (_) {}

    try {
      final r = await dio.get('/drivers/today-stats');
      final d = r.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _todayTrips    = (d['todayTrips']    as num?)?.toInt()    ?? 0;
          _todayEarnings = (d['todayEarnings'] as num?)?.toDouble() ?? 0;
          _todayKm       = (d['todayKm']       as num?)?.toDouble() ?? 0;
          _rating        = (d['rating']        as num?)?.toDouble() ?? 4.9;
          _todayTarget   = (d['todayTarget']   as num?)?.toDouble() ?? 200000;
        });
      }
    } catch (_) {

      try {
        final r = await dio.get('/drivers/stats');
        final d = r.data as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _todayTrips    = (d['todayTrips']    as num?)?.toInt()    ?? 0;
            _todayEarnings = (d['todayEarnings'] as num?)?.toDouble() ?? 0;
            _rating        = (d['rating']        as num?)?.toDouble() ?? 4.9;
          });
        }
      } catch (_) {}
    }

    try {
      final r = await dio.get('/drivers/hot-zones');
      if (r.data is List && mounted) {
        setState(() {
          _hotZones = (r.data as List)
              .take(3)
              .map((e) =>
                  _HotZone.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        });
      }
    } catch (_) {}

    try {
      final r = await dio.get('/drivers/history');
      if (r.data is List && mounted) {
        setState(() {
          _recentTrips = (r.data as List)
              .take(3)
              .map((e) =>
                  _TripRecord.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleOnline() async {
    if (_isToggling) return;
    setState(() => _isToggling = true);
    try {
      await DioClient.create().post('/drivers/toggle-online', data: {
        'isOnline': !_isOnline,
        'latitude': _pos.latitude,
        'longitude': _pos.longitude,
      });
      if (mounted) setState(() => _isOnline = !_isOnline);
    } catch (_) {
      // API gagal — jangan ubah state
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial =
        _driverName.isNotEmpty ? _driverName[0].toUpperCase() : 'D';

    return Scaffold(
      body: Stack(
        children: [

          _OSMMap(pos: _pos, isOnline: _isOnline, mapController: _map),

          Positioned(
            top: 0, left: 0, right: 0,
            child: FadeTransition(
              opacity: _topFade,
              child: SlideTransition(
                position: _topSlide,
                child: _TopBar(
                  initial: initial,
                  greeting: _greeting,
                  gpsLoading: _gpsLoading,
                  isOnline: _isOnline,
                  onAvatarTap: () {},
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 372, left: 0, right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, child) =>
                    Transform.scale(scale: _pulse.value, child: child),
                child: _StatusBadge(isOnline: _isOnline),
              ),
            ),
          ),

          Positioned(
            bottom: 0, left: 0, right: 0,
            child: FadeTransition(
              opacity: _bottomFade,
              child: SlideTransition(
                position: _bottomSlide,
                child: _BottomSheet(
                  driverName: _driverName,
                  greeting: _greeting,
                  isOnline: _isOnline,
                  isToggling: _isToggling,
                  todayTrips: _todayTrips,
                  todayEarnings: _todayEarnings,
                  todayKm: _todayKm,
                  rating: _rating,
                  todayTarget: _todayTarget,
                  recentTrips: _recentTrips,
                  hotZones: _hotZones,
                  currency: _currency,
                  onToggle: _toggleOnline,
                  onHistoryTap: widget.onHistoryTap ?? () {},
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OSMMap extends StatelessWidget {
  final LatLng pos;
  final bool isOnline;
  final MapController mapController;

  const _OSMMap({
    required this.pos,
    required this.isOnline,
    required this.mapController,
  });

  @override
  Widget build(BuildContext context) => FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: pos,
          initialZoom: 15,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: ApiConstants.hereTileUrl,
            userAgentPackageName: 'com.lungo.app',
          ),
          MarkerLayer(markers: [
            Marker(
              point: pos,
              width: 52,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  color: isOnline ? _kGreen : AppColors.offline,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: (isOnline ? _kGreen : AppColors.offline)
                          .withValues(alpha: 0.45),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.electric_moped_rounded,
                    color: Colors.white, size: 26),
              ),
            ),
          ]),
        ],
      );
}

class _TopBar extends StatelessWidget {
  final String initial;
  final String greeting;
  final bool gpsLoading;
  final bool isOnline;
  final VoidCallback onAvatarTap;

  const _TopBar({
    required this.initial,
    required this.greeting,
    required this.gpsLoading,
    required this.isOnline,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: Colors.white.withValues(alpha: 0.93),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                children: [

                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor,
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
                          color: AppColors.primaryColor,
                        ),
                      ),
                      const Spacer(),

                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isOnline
                              ? _kGreen.withValues(alpha: 0.12)
                              : AppColors.offline.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? _kGreen
                                    : AppColors.offline,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                fontFamily: 'Satoshi',
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: isOnline
                                    ? _kGreen
                                    : AppColors.offline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      GestureDetector(
                        onTap: onAvatarTap,
                        child: CircleAvatar(
                          radius: 19,
                          backgroundColor: AppColors.primaryColor,
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
                          color: _kOrange, size: 15),
                      const SizedBox(width: 4),
                      Text(
                        gpsLoading
                            ? 'Mencari lokasi...'
                            : 'Bandung, Jawa Barat',
                        style: const TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '· $greeting',
                        style: const TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isOnline;
  const _StatusBadge({required this.isOnline});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: isOnline ? _kGreen : AppColors.offline,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: (isOnline ? _kGreen : AppColors.offline)
                  .withValues(alpha: 0.55),
              blurRadius: 14,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.electric_moped_rounded,
                color: Colors.white, size: 15),
            const SizedBox(width: 6),
            Text(
              isOnline ? 'Kamu Online' : 'Kamu Offline',
              style: const TextStyle(
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
}

class _BottomSheet extends StatelessWidget {
  final String driverName;
  final String greeting;
  final bool isOnline;
  final bool isToggling;
  final int todayTrips;
  final double todayEarnings;
  final double todayKm;
  final double rating;
  final double todayTarget;
  final List<_TripRecord> recentTrips;
  final List<_HotZone> hotZones;
  final NumberFormat currency;
  final VoidCallback onToggle;
  final VoidCallback onHistoryTap;

  const _BottomSheet({
    required this.driverName,
    required this.greeting,
    required this.isOnline,
    required this.isToggling,
    required this.todayTrips,
    required this.todayEarnings,
    required this.todayKm,
    required this.rating,
    required this.todayTarget,
    required this.recentTrips,
    required this.hotZones,
    required this.currency,
    required this.onToggle,
    required this.onHistoryTap,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: 360,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A0540F2),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hai, $driverName! 👋',
                          style: const TextStyle(
                            fontFamily: 'Satoshi',
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isOnline
                              ? 'Siap menerima pesanan baru'
                              : 'Aktifkan untuk mulai menerima order',
                          style: const TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _PowerButton(
                    isOnline: isOnline,
                    isToggling: isToggling,
                    onTap: onToggle,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  _StatChip(
                    icon: Icons.route_rounded,
                    value: '$todayTrips',
                    label: 'Trip',
                    color: AppColors.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.payments_rounded,
                    value: todayEarnings == 0
                        ? 'Rp 0'
                        : currency.format(todayEarnings),
                    label: 'Pendapatan',
                    color: _kGreen,
                    selected: true,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.map_rounded,
                    value: todayKm.toStringAsFixed(1),
                    label: 'km',
                    color: AppColors.secondaryColor,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.star_rounded,
                    value: rating.toStringAsFixed(1),
                    label: 'Rating',
                    color: const Color(0xFFE28B00),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _TargetCard(
                earnings: todayEarnings,
                target: todayTarget,
                currency: currency,
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bar_chart_rounded,
                          color: AppColors.primaryColor, size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'Kondisi Saat Ini',
                        style: TextStyle(
                          fontFamily: 'Satoshi',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _nowTime(),
                    style: const TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (hotZones.isNotEmpty)
                Row(
                  children: hotZones
                      .take(2)
                      .map((z) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  right: z == hotZones.last ? 0 : 8),
                              child: _ZoneChip(zone: z),
                            ),
                          ))
                      .toList(),
                )
              else
                Row(
                  children: [
                    Expanded(
                        child: _ZoneChip(
                            zone: _HotZone(
                                name: 'Braga',
                                demand: 'high',
                                requestCount: 9))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _ZoneChip(
                            zone: _HotZone(
                                name: 'BIP',
                                demand: 'high',
                                requestCount: 7))),
                  ],
                ),
            ],
          ),
        ),
      );

  static String _nowTime() {
    final now = DateTime.now();
    final h   = now.hour.toString().padLeft(2, '0');
    final m   = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _PowerButton extends StatelessWidget {
  final bool isOnline;
  final bool isToggling;
  final VoidCallback onTap;

  const _PowerButton({
    required this.isOnline,
    required this.isToggling,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: isToggling ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOnline
                ? _kGreen.withValues(alpha: 0.10)
                : AppColors.primaryColor.withValues(alpha: 0.07),
            border: Border.all(
              color: isOnline ? _kGreen : AppColors.primaryColor,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isOnline ? _kGreen : AppColors.primaryColor)
                    .withValues(alpha: 0.20),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isToggling
              ? Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: isOnline ? _kGreen : AppColors.primaryColor,
                    ),
                  ),
                )
              : Icon(
                  Icons.power_settings_new_rounded,
                  color:
                      isOnline ? _kGreen : AppColors.primaryColor,
                  size: 24,
                ),
        ),
      );
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool selected;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryColor
                : AppColors.primaryLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: selected ? Colors.white : color, size: 18),
              const SizedBox(height: 5),
              FittedBox(
                child: Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: selected ? Colors.white : color,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 9,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.8)
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
}

class _TargetCard extends StatelessWidget {
  final double earnings;
  final double target;
  final NumberFormat currency;

  const _TargetCard({
    required this.earnings,
    required this.target,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final pct = target > 0 ? (earnings / target).clamp(0.0, 1.0) : 0.0;
    final pctLabel =
        '${(pct * 100).toStringAsFixed(0)}%';
    final remaining = (target - earnings).clamp(0, target);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.flag_rounded,
                      color: AppColors.primaryColor, size: 14),
                  const SizedBox(width: 6),
                  const Text(
                    'Target Harian',
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
              Text(
                pctLabel,
                style: const TextStyle(
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(
                pct >= 1.0 ? _kGreen : AppColors.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                earnings == 0 ? 'Rp 0' : currency.format(earnings),
                style: const TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${currency.format(target)} target',
                style: const TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                remaining == 0
                    ? '🎉 Target tercapai!'
                    : '${currency.format(remaining)} lagi',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: remaining == 0
                      ? _kGreen
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ZoneChip extends StatelessWidget {
  final _HotZone zone;
  const _ZoneChip({required this.zone});

  @override
  Widget build(BuildContext context) {
    final isHigh = zone.demand == 'high';
    final dotColor = isHigh ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  zone.name,
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${zone.requestCount} order',
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 10,
                    color: AppColors.textSecondary,
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

class _TripRecord {
  final String pickup, destination;
  final double fare, distanceKm;
  final int minutesAgo;

  const _TripRecord({
    required this.pickup,
    required this.destination,
    required this.fare,
    required this.distanceKm,
    required this.minutesAgo,
  });

  factory _TripRecord.fromJson(Map<String, dynamic> j) {
    final createdAt = j['createdAt'] as String?;
    int minsAgo = 0;
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) minsAgo = DateTime.now().difference(dt).inMinutes;
    }
    return _TripRecord(
      pickup: (j['pickup'] as String?) ??
          (j['pickupAddress'] as String?) ??
          (j['from'] as String?) ??
          'Titik Jemput',
      destination: (j['destination'] as String?) ??
          (j['destinationAddress'] as String?) ??
          (j['to'] as String?) ??
          'Tujuan',
      fare: (j['fare'] as num?)?.toDouble() ?? 0,
      distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0,
      minutesAgo: minsAgo,
    );
  }
}

class _HotZone {
  final String name;
  final String demand;
  final int requestCount;

  const _HotZone({
    required this.name,
    required this.demand,
    required this.requestCount,
  });

  factory _HotZone.fromJson(Map<String, dynamic> j) => _HotZone(
        name: (j['name'] as String?) ?? 'Zona',
        demand: (j['demand'] as String?) ?? 'medium',
        requestCount: (j['requestCount'] as num?)?.toInt() ?? 0,
      );
}
