import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:excel/excel.dart' as xl;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../auth/providers/auth_provider.dart';

class _C {
  static const bg       = Color(0xFFF0F4FF);
  static const card     = Colors.white;
  static const primary  = Color(0xFF0540F2);
  static const dark     = Color(0xFF04198C);
  static const accent   = Color(0xFFF2CB05);
  static const green    = Color(0xFF059669);
  static const purple   = Color(0xFF7C3AED);
  static const orange   = Color(0xFFD97706);
  static const red      = Color(0xFFDC2626);
  static const shadow   = Color(0x180540F2);
}

final _demoComplaints = <_ComplaintD>[];

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen>
    with TickerProviderStateMixin {
  final _dio = ApiClient.create();
  Timer? _refreshTimer;
  late AnimationController _entryCtrl;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;

  int    _totalUsers           = 0;
  int    _totalDrivers         = 0;
  int    _activeTrips          = 0;
  double _todayRevenue         = 0;
  double _weekRevenue          = 0;
  int    _openComplaints       = 0;
  int    _onlineDrivers        = 0;
  int    _pendingVerifications = 0;
  int    _unreadNotifications  = 0;

  List<_UserD>           _users            = [];
  List<_DriverD>         _drivers          = [];
  List<_TripD>           _trips            = [];
  List<_DriverTripGroup> _driverTripGroups = [];

  List<_ChartPoint> _chartData  = [];
  double _weeklyGrowth          = 0;

  io.Socket? _socket;
  final Map<String, _LiveDriver> _liveDrivers = {};
  final List<_LiveRide>          _liveRides   = [];
  final List<_LiveEvent>         _liveEvents  = [];

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _entryFade  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.06), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();
    _loadStats();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadStats());
    _connectSocket();
  }

  Future<void> _connectSocket() async {
    final token = await SecureStorage.getAccessToken();
    _socket = io.io(
      '${ApiConstants.wsUrl}${ApiConstants.trackingNamespace}',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    _socket!.onConnect((_) {
      if (mounted) setState(() {});
    });

    _socket!.on('driverStatusChanged', (data) {
      if (!mounted) return;
      final d = Map<String, dynamic>.from(data as Map);
      final id = d['driverId'] as String? ?? '';
      final online = (d['status'] as String?) == 'online';
      setState(() {
        if (online) {
          _liveDrivers.putIfAbsent(id, () => _LiveDriver(id, 0, 0));
          _liveDrivers[id]!.online = true;
          _onlineDrivers = _liveDrivers.values.where((x) => x.online).length;
        } else {
          _liveDrivers.remove(id);
          _onlineDrivers = _liveDrivers.values.where((x) => x.online).length;
        }
      });
      _addEvent(online ? '🟢 Driver online: $id' : '🔴 Driver offline: $id');
    });

    _socket!.on('driverLocationUpdated', (data) {
      if (!mounted) return;
      final d   = Map<String, dynamic>.from(data as Map);
      final id  = d['driverId'] as String? ?? '';
      final lat = (d['latitude']  as num?)?.toDouble() ?? 0;
      final lng = (d['longitude'] as num?)?.toDouble() ?? 0;
      setState(() {
        final drv = _liveDrivers.putIfAbsent(id, () => _LiveDriver(id, lat, lng));
        drv.lat = lat; drv.lng = lng; drv.online = true;
      });
    });

    _socket!.on('newRideRequest', (data) {
      if (!mounted) return;
      final d = Map<String, dynamic>.from(data as Map);
      final id = d['rideId'] as String? ?? '';
      setState(() {
        _liveRides.removeWhere((r) => r.rideId == id);
        _liveRides.insert(0, _LiveRide(
          rideId: id,
          passengerName: d['passengerName'] as String? ?? 'Penumpang',
          status: 'SEARCHING',
          fare: (d['estimatedFare'] as num?)?.toDouble() ?? 0,
        ));
        if (_liveRides.length > 20) _liveRides.removeLast();
        _activeTrips = _liveRides.where((r) => _activeStatus(r.status)).length;
      });
      _addEvent('🔔 Pesanan baru: ${d['passengerName'] ?? '?'}');
    });

    _socket!.on('rideAccepted', (data) {
      if (!mounted) return;
      final d = Map<String, dynamic>.from(data as Map);
      final id = d['rideId'] as String? ?? '';
      setState(() {
        final ride = _liveRides.firstWhere(
          (r) => r.rideId == id, orElse: () {
            final nr = _LiveRide(rideId: id, passengerName: '?', status: 'ACCEPTED', fare: 0);
            _liveRides.insert(0, nr);
            return nr;
          });
        ride.status = 'ACCEPTED';
        ride.driverName = d['driverName'] as String? ?? 'Driver';
      });
      _addEvent('✅ Diterima oleh ${d['driverName'] ?? 'Driver'}');
    });

    _socket!.on('rideStatusChanged', (data) {
      if (!mounted) return;
      final d  = Map<String, dynamic>.from(data as Map);
      final id = d['rideId'] as String? ?? '';
      final st = d['status'] as String? ?? '';
      setState(() {
        final ride = _liveRides.firstWhereOrNull((r) => r.rideId == id);
        if (ride != null) {
          ride.status = st;
          if (!_activeStatus(st)) {
            _activeTrips = _liveRides.where((r) => _activeStatus(r.status)).length;
          }
        }
      });
      if (st == 'ONGOING') _addEvent('🚀 Trip mulai: $id');
    });

    _socket!.on('rideEnded', (data) {
      if (!mounted) return;
      final d  = Map<String, dynamic>.from(data as Map);
      final id = d['rideId'] as String? ?? '';
      setState(() {
        final ride = _liveRides.firstWhereOrNull((r) => r.rideId == id);
        if (ride != null) {
          ride.status = 'DONE';
          ride.fare   = (d['finalFare'] as num?)?.toDouble() ?? ride.fare;
        }
        _activeTrips = _liveRides.where((r) => _activeStatus(r.status)).length;
      });
      final fare = d['finalFare'] ?? 0;
      _addEvent('🏁 Trip selesai — Rp ${NumberFormat.compact(locale: 'id').format(fare)}');
    });

    _socket!.on('rideCancelled', (data) {
      if (!mounted) return;
      final d  = Map<String, dynamic>.from(data as Map);
      final id = d['rideId'] as String? ?? '';
      setState(() {
        _liveRides.firstWhereOrNull((r) => r.rideId == id)?.status = 'CANCELLED';
        _activeTrips = _liveRides.where((r) => _activeStatus(r.status)).length;
      });
      _addEvent('❌ Trip dibatalkan: $id');
    });
  }

  bool _activeStatus(String s) =>
      s == 'SEARCHING' || s == 'ACCEPTED' || s == 'PICKUP' || s == 'ONGOING';

  void _addEvent(String msg) {
    if (!mounted) return;
    setState(() {
      _liveEvents.insert(0, _LiveEvent(msg, DateTime.now()));
      if (_liveEvents.length > 30) _liveEvents.removeLast();
    });
  }

  Widget _buildLiveMonitor() {
    final idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final onlineDrivers = _liveDrivers.values.where((d) => d.online).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
          child: Row(children: [
            Text('Monitor Live',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold, fontSize: 17, color: _C.dark)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 7, height: 7,
                    decoration: const BoxDecoration(
                        color: Color(0xFFD97706), shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('${onlineDrivers.length} Driver  •  ${_liveRides.where((r) => _activeStatus(r.status)).length} Trip',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10, fontWeight: FontWeight.bold,
                        color: const Color(0xFFD97706))),
              ]),
            ),
          ]),
        ),

        if (onlineDrivers.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: _C.shadow, blurRadius: 12, offset: Offset(0, 4))],
            ),
            clipBehavior: Clip.hardEdge,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(
                    onlineDrivers.first.lat != 0 ? onlineDrivers.first.lat : -7.25,
                    onlineDrivers.first.lng != 0 ? onlineDrivers.first.lng : 112.75),
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.lungo.app',
                ),
                MarkerLayer(
                  markers: onlineDrivers
                      .where((d) => d.lat != 0 || d.lng != 0)
                      .map((d) => Marker(
                            point: LatLng(d.lat, d.lng),
                            width: 36,
                            height: 36,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _C.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [BoxShadow(
                                    color: _C.primary.withValues(alpha: 0.4),
                                    blurRadius: 6, offset: const Offset(0, 2))],
                              ),
                              child: const Icon(Icons.electric_moped_rounded,
                                  color: Colors.white, size: 18),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),

        if (onlineDrivers.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: _C.shadow, blurRadius: 8)],
            ),
            child: Center(
              child: Text('Belum ada driver online',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, color: _C.dark.withValues(alpha: 0.4))),
            ),
          ),

        const SizedBox(height: 16),

        if (_liveRides.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text('Pesanan Realtime',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, fontSize: 13, color: _C.dark)),
          ),
          ...(_liveRides.take(5).map((r) {
            final (color, label) = switch (r.status) {
              'SEARCHING' => (_C.orange,  'Mencari Driver'),
              'ACCEPTED'  => (_C.primary, 'Diterima'),
              'PICKUP'    => (_C.primary, 'Menjemput'),
              'ONGOING'   => (_C.green,   'Perjalanan'),
              'DONE'      => (_C.green,   'Selesai'),
              _           => (_C.red,     'Batal'),
            };
            return Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: _C.shadow, blurRadius: 8)],
              ),
              child: Row(children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.passengerName,
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600, fontSize: 13, color: _C.dark)),
                  if (r.driverName.isNotEmpty)
                    Text('Driver: ${r.driverName}',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, color: _C.dark.withValues(alpha: 0.5))),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(label,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                  ),
                  if (r.fare > 0) ...[
                    const SizedBox(height: 2),
                    Text(idr.format(r.fare),
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, fontWeight: FontWeight.w600, color: _C.primary)),
                  ],
                ]),
              ]),
            );
          })),
        ],

        if (_liveEvents.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text('Log Aktivitas',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, fontSize: 13, color: _C.dark)),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0940),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: _liveEvents.take(8).map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Text(DateFormat('HH:mm:ss').format(e.time),
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 10, color: Colors.white38)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e.message,
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 11, color: Colors.white70)),
                  ),
                ]),
              )).toList(),
            ),
          ),
        ],

        const SizedBox(height: 8),
      ],
    );
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _refreshTimer?.cancel();
    _socket?.disconnect();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final r = await _dio.get('/admin/stats');
      final d = Map<String, dynamic>.from(r.data as Map);
      if (!mounted) return;
      setState(() {
        _totalUsers           = (d['totalUsers']           as num?)?.toInt()    ?? 0;
        _totalDrivers         = (d['totalDrivers']         as num?)?.toInt()    ?? 0;
        _activeTrips          = (d['activeTrips']          as num?)?.toInt()    ?? 0;
        _todayRevenue         = (d['todayRevenue']         as num?)?.toDouble() ?? 0;
        _weekRevenue          = (d['weekRevenue']          as num?)?.toDouble() ?? 0;
        _openComplaints       = (d['openComplaints']       as num?)?.toInt()    ?? 0;
        _onlineDrivers        = (d['onlineDrivers']        as num?)?.toInt()    ?? 0;
        _pendingVerifications = (d['pendingVerifications'] as num?)?.toInt()    ?? 0;
        _unreadNotifications  = (d['unreadNotifications']  as num?)?.toInt()    ?? 0;
      });
    } catch (_) {}
    await Future.wait([_loadUsers(), _loadDrivers(), _loadTrips(), _loadTripsByDriver(), _loadRevenueChart()]);
  }

  Future<void> _loadUsers() async {
    try {
      final r = await _dio.get('/admin/users', queryParameters: {'limit': '500'});
      final raw  = r.data;
      final list = (raw is Map ? raw['users'] : raw) as List? ?? [];
      if (!mounted) return;
      setState(() {
        _users = list.map((u) {
          final m = Map<String, dynamic>.from(u as Map);
          return _UserD(
            m['id']         as String? ?? '',
            m['name']       as String? ?? '-',
            m['phone']      as String? ?? '-',
            m['role']       as String? ?? 'PASSENGER',
            m['isVerified'] as bool?   ?? false,
            m['createdAt']  as String? ?? '',
          );
        }).where((u) => u.role == 'PASSENGER').toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      });
    } catch (_) {}
  }

  Future<void> _loadDrivers() async {
    try {
      final r = await _dio.get('/admin/drivers');

      final rawData = r.data;
      List<dynamic> rawList = [];
      if (rawData is List) {
        rawList = rawData;
      } else if (rawData is Map) {
        rawList = (rawData['drivers'] ?? rawData['data'] ?? []) as List<dynamic>;
      }

      if (!mounted) return;

      final parsed = <_DriverD>[];
      for (int i = 0; i < rawList.length; i++) {
        try {
          final d = rawList[i];
          final m = Map<String, dynamic>.from(d as Map);
          final userRaw = m['user'];
          final user = userRaw != null
              ? Map<String, dynamic>.from(userRaw as Map)
              : <String, dynamic>{};

          debugPrint('[DRIVER] Item $i: id=${m['id']}, '
              'name=${user['name']}, phone=${user['phone']}, '
              'rating=${m['rating']} (${m['rating'].runtimeType}), '
              'isOnline=${m['isOnline']} (${m['isOnline'].runtimeType}), '
              'totalRides=${m['totalRides']}, plate=${m['vehiclePlate']}');

          parsed.add(_DriverD(
            m['id']?.toString()           ?? '',
            user['name']?.toString()      ?? '-',
            user['phone']?.toString()     ?? '-',
            m['isOnline'] == true,
            double.tryParse(m['rating']?.toString() ?? '0') ?? 0.0,
            int.tryParse(m['totalRides']?.toString() ?? '0') ?? 0,
            m['vehiclePlate']?.toString() ?? '-',
            m['vehicleType']?.toString()  ?? '-',
            m['ktpNumber']?.toString()    ?? '-',
            m['createdAt']?.toString()    ?? '',
          ));
        } catch (_) {}
      }

      setState(() => _drivers = parsed);
    } catch (_) {}

  }

  Future<void> _loadTrips() async {
    try {
      final r    = await _dio.get('/admin/trips/active');
      final list = r.data as List? ?? [];
      if (!mounted) return;
      setState(() => _trips = list.map((t) {
        final m = Map<String, dynamic>.from(t as Map);
        return _TripD(
          m['passengerName']      as String? ?? '-',
          m['driverName']         as String? ?? '-',
          m['originAddress']      as String? ?? 'Asal',
          m['destinationAddress'] as String? ?? 'Tujuan',
          (m['fare'] as num?)?.toDouble() ?? 0,
          m['status']             as String? ?? '-',
        );
      }).toList());
    } catch (_) {}
  }

  Future<void> _loadRevenueChart() async {
    try {
      final r = await _dio.get('/admin/revenue/chart');
      final d = Map<String, dynamic>.from(r.data as Map);
      final days = (d['days'] as List? ?? []);
      if (!mounted || days.isEmpty) return;
      setState(() {
        _chartData = days.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return _ChartPoint(
            day:       m['day']?.toString() ?? '',
            revenue:   double.tryParse(m['revenue']?.toString()   ?? '0') ?? 0.0,
            tripCount: int.tryParse(m['tripCount']?.toString()    ?? '0') ?? 0,
          );
        }).toList();
        _weeklyGrowth = double.tryParse(d['growth']?.toString() ?? '0') ?? 0.0;
      });
    } catch (_) {}
  }

  Future<void> _loadTripsByDriver() async {
    try {
      final r    = await _dio.get('/admin/trips/by-driver');
      final list = r.data as List? ?? [];
      if (!mounted) return;
      setState(() => _driverTripGroups = list.map((g) {
        final m     = Map<String, dynamic>.from(g as Map);
        final trips = (m['trips'] as List? ?? []).map((t) {
          final tm = Map<String, dynamic>.from(t as Map);
          return _TripItem2(
            tm['id']?.toString()              ?? '',
            tm['passengerName']?.toString()   ?? '-',
            tm['originAddress']?.toString()   ?? 'Asal',
            tm['destinationAddress']?.toString() ?? 'Tujuan',
            tm['status']?.toString()          ?? '-',
            double.tryParse(tm['fare']?.toString() ?? '0') ?? 0,
            tm['createdAt']?.toString()       ?? '',
            double.tryParse(tm['distanceKm']?.toString() ?? '0') ?? 0,
          );
        }).toList();
        return _DriverTripGroup(
          m['driverId']     as String? ?? '',
          m['driverName']   as String? ?? '-',
          (m['totalTrips']  as num?)?.toInt()    ?? 0,
          (m['totalRevenue'] as num?)?.toDouble() ?? 0,
          trips,
        );
      }).toList());
    } catch (_) {}
  }

  void _showUsers() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _BottomSheet(
          title: 'Total Penumpang',
          count: _totalUsers,
          icon: Icons.people_rounded,
          color: _C.primary,
          child: _UserList(users: _users),
        ),
      );

  void _showDrivers() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _BottomSheet(
          title: 'Total Driver',
          count: _totalDrivers,
          icon: Icons.electric_moped_rounded,
          color: _C.green,
          child: _DriverListLoader(dio: _dio),
        ),
      );

  void _showTrips() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _BottomSheet(
          title: 'Trip per Driver',
          count: _driverTripGroups.fold<int>(0, (s, g) => s + g.totalTrips),
          icon: Icons.route_rounded,
          color: _C.orange,
          child: _TripsByDriverList(groups: _driverTripGroups),
        ),
      );

  void _showRevenue() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _BottomSheet(
          title: 'Pendapatan',
          count: null,
          icon: Icons.payments_rounded,
          color: _C.primary,
          child: _RevenuePeriodSheet(dio: _dio),
        ),
      );

  void _showWeeklyReports() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _BottomSheet(
          title: 'Laporan Mingguan',
          count: null,
          icon: Icons.description_rounded,
          color: _C.primary,
          child: _WeeklyReportLoader(dio: _dio),
        ),
      );

  void _showComplaints() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _BottomSheet(
          title: 'Saran & Kritik',
          count: _openComplaints,
          icon: Icons.rate_review_rounded,
          color: _C.purple,
          child: _ComplaintList(complaints: _demoComplaints),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final now  = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);
    final greeting = now.hour < 12 ? 'Selamat Pagi' :
                     now.hour < 17 ? 'Selamat Siang' : 'Selamat Malam';

    return Scaffold(
      backgroundColor: _C.bg,
      body: RefreshIndicator(
        onRefresh: _loadStats,
        color: _C.primary,
        child: FadeTransition(
          opacity: _entryFade,
          child: SlideTransition(
            position: _entrySlide,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              slivers: [

                SliverToBoxAdapter(child: _buildHeader(user?.name, greeting, dateStr)),

                SliverToBoxAdapter(child: _buildStatRow()),

                SliverToBoxAdapter(child: _buildRevenueChart()),

                SliverToBoxAdapter(child: _buildQuickActions()),

                SliverToBoxAdapter(child: _buildOnlineDrivers()),

                SliverToBoxAdapter(child: _buildActiveTrips()),

                SliverToBoxAdapter(child: _buildLiveMonitor()),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String? name, String greeting, String dateStr) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B0940), Color(0xFF0540F2), Color(0xFF056CF2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            children: [
              Row(children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFF2CB05), Color(0xFFFFE066)]),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color: _C.accent.withValues(alpha: 0.4),
                        blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Center(
                    child: Text(
                      name?.isNotEmpty == true ? name![0].toUpperCase() : 'A',
                      style: GoogleFonts.plusJakartaSans(
                          color: _C.dark, fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$greeting, ${name ?? 'Admin'}',
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(dateStr,
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white60, fontSize: 11)),
                  ],
                )),
                _HeaderBtn(icon: Icons.refresh_rounded, onTap: _loadStats),
              ]),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Row(children: [
                  _BannerStat(
                      label: 'Penumpang', value: '$_totalUsers',
                      icon: Icons.people_rounded,
                      onTap: _showUsers),
                  _divider(),
                  _BannerStat(
                      label: 'Driver', value: '$_totalDrivers',
                      icon: Icons.electric_moped_rounded,
                      onTap: _showDrivers),
                  _divider(),
                  _BannerStat(
                      label: 'Trip Aktif', value: '$_activeTrips',
                      icon: Icons.route_rounded,
                      onTap: _showTrips),
                  _divider(),
                  _BannerStat(
                      label: 'Pengaduan', value: '$_openComplaints',
                      icon: Icons.inbox_rounded, alert: _openComplaints > 0,
                      onTap: _showComplaints),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 32, color: Colors.white.withValues(alpha: 0.2),
      margin: const EdgeInsets.symmetric(horizontal: 8));

  Widget _buildStatRow() {
    final idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
          child: Row(children: [
            Text('Statistik Platform',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold, fontSize: 17, color: _C.dark)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _C.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6,
                    decoration: const BoxDecoration(
                        color: Color(0xFF059669), shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('Live',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, fontWeight: FontWeight.w700, color: _C.primary)),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            Row(children: [
              Expanded(child: _StatCard2(
                icon: Icons.people_rounded,
                value: '$_totalUsers',
                label: 'Total Penumpang',
                sub: 'Tap lihat daftar A-Z',
                onTap: _showUsers,
              )),
              const SizedBox(width: 14),
              Expanded(child: _StatCard2(
                icon: Icons.electric_moped_rounded,
                value: '$_totalDrivers',
                label: 'Total Driver',
                sub: '$_onlineDrivers sedang online',
                onTap: _showDrivers,
              )),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _StatCard2(
                icon: Icons.route_rounded,
                value: '$_activeTrips',
                label: 'Trip',
                sub: 'Tap lihat per driver',
                onTap: _showTrips,
              )),
              const SizedBox(width: 14),
              Expanded(child: _StatCard2(
                icon: Icons.payments_rounded,
                value: idr.format(_todayRevenue),
                label: 'Pendapatan Hari Ini',
                sub: 'Per driver',
                isRevenue: true,
                onTap: _showRevenue,
              )),
            ]),
          ]),
        ),
      ],
    );
  }

  Widget _buildRevenueChart() {
    final idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: _C.shadow, blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pendapatan 7 Hari',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold, fontSize: 15, color: _C.dark)),
              Text(idr.format(_weekRevenue),
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900, fontSize: 22, color: _C.primary)),
            ]),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  _weeklyGrowth >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 14, color: const Color(0xFF059669)),
                const SizedBox(width: 4),
                Text(
                  '${_weeklyGrowth >= 0 ? '+' : ''}${_weeklyGrowth.toStringAsFixed(1)}%',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, fontWeight: FontWeight.bold,
                      color: const Color(0xFF059669))),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          _chartData.isEmpty
              ? SizedBox(
                  height: 90,
                  child: Center(
                    child: Text('Belum ada data pendapatan',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: _C.dark.withValues(alpha: 0.35))),
                  ),
                )
              : _buildBarChart(),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final maxY = _chartData.map((p) => p.revenue).reduce(math.max);
    final idrCompact = NumberFormat('#,###', 'id_ID');
    return SizedBox(
      height: 90,
      child: BarChart(
        BarChartData(
          maxY: maxY > 0 ? maxY * 1.3 : 50000,
          minY: 0,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= _chartData.length) return const SizedBox();
                  final isToday = idx == _chartData.length - 1;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_chartData[idx].day,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday
                                ? _C.primary
                                : _C.dark.withValues(alpha: 0.5))),
                  );
                },
              ),
            ),
          ),
          barGroups: _chartData.asMap().entries.map((entry) {
            final isToday = entry.key == _chartData.length - 1;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.revenue,
                  gradient: LinearGradient(
                    colors: isToday
                        ? [const Color(0xFF0540F2), const Color(0xFF056CF2)]
                        : [const Color(0xFF0540F2).withValues(alpha: 0.25),
                           const Color(0xFF0540F2).withValues(alpha: 0.45)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 22,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            );
          }).toList(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => _C.dark,
              getTooltipItem: (group, groupIdx, rod, rodIdx) {
                final p = _chartData[group.x];
                return BarTooltipItem(
                  'Rp ${idrCompact.format(rod.toY.toInt())}\n${p.tripCount} trip',
                  GoogleFonts.plusJakartaSans(
                      color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text('Menu Cepat',
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold, fontSize: 17, color: _C.dark)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.assignment_ind_rounded,
                  label: 'Verifikasi Driver',
                  color: _C.orange,
                  badge: _pendingVerifications,
                  onTap: () => Navigator.pushNamed(context, '/admin/pending-drivers')
                      .then((_) => _loadStats()),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.rate_review_rounded,
                  label: 'Saran & Kritik',
                  color: _C.purple,
                  badge: _openComplaints,
                  onTap: _showComplaints,
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.description_rounded,
                  label: 'Laporan',
                  color: _C.primary,
                  onTap: _showWeeklyReports,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.notifications_outlined,
                  label: 'Notifikasi',
                  color: _C.dark,
                  badge: _unreadNotifications,
                  onTap: () => Navigator.pushNamed(context, '/admin/notifications')
                      .then((_) => _loadStats()),
                ),
              ),
            ]),
          ]),
        ),
      ],
    );
  }

  Widget _buildOnlineDrivers() {
    final online = _drivers.where((d) => d.online).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
          child: Row(children: [
            Text('Driver Online',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold, fontSize: 17, color: _C.dark)),
            const SizedBox(width: 10),
            _LiveBadge(count: online.length),
            const Spacer(),
            GestureDetector(
              onTap: _showDrivers,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _C.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Lihat Semua',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, fontWeight: FontWeight.w700, color: _C.primary)),
              ),
            ),
          ]),
        ),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: online.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, i) => _OnlineDriverCard(
              driver: online[i],
              onTap: () => Navigator.pushNamed(
                  context, '/admin/driver-detail',
                  arguments: online[i].id),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveTrips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(children: [
            Text('Trip Berlangsung',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold, fontSize: 17, color: _C.dark)),
            const SizedBox(width: 8),
            _LiveBadge(count: _activeTrips),
            const Spacer(),
            TextButton(
              onPressed: _showTrips,
              child: Text('Lihat Semua',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, fontWeight: FontWeight.w700, color: _C.primary)),
            ),
          ]),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: math.min(_trips.length, 3),
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _ActiveTripCard(
            trip: _trips[i],
            onTap: _showTrips,
          ),
        ),
      ],
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      );
}

class _BannerStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final bool alert;
  final VoidCallback? onTap;
  const _BannerStat({
    required this.label, required this.value, required this.icon,
    this.alert = false, this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Column(children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.75), size: 16),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.plusJakartaSans(
                    color: alert ? _C.accent : Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54, fontSize: 10)),
          ]),
        ),
      );
}

class _StatCard2 extends StatelessWidget {
  final IconData icon;
  final String value, label, sub;
  final bool isRevenue;
  final VoidCallback onTap;
  const _StatCard2({
    required this.icon, required this.value, required this.label,
    required this.sub, required this.onTap, this.isRevenue = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF0540F2).withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0540F2).withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0540F2).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF0540F2), size: 20),
                ),
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0540F2).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF0540F2), size: 16),
                ),
              ]),
              const SizedBox(height: 12),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: isRevenue ? 14 : 24,
                  color: const Color(0xFF0B0940),
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: const Color(0xFF0B0940).withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10, color: const Color(0xFF0540F2),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int badge;
  final VoidCallback onTap;
  const _QuickActionTile({
    required this.icon, required this.label, required this.color,
    required this.onTap, this.badge = 0});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.08), color.withValues(alpha: 0.18)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 5)),
            ],
          ),
          child: Stack(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(label,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, fontWeight: FontWeight.w800, color: color),
                      maxLines: 2),
                ),
              ]),
            ),
            if (badge > 0)
              Positioned(
                top: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: _C.red, borderRadius: BorderRadius.circular(20)),
                  child: Text('$badge baru',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 9, fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
          ]),
        ),
      );
}

class _LiveBadge extends StatelessWidget {
  final int count;
  const _LiveBadge({required this.count});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7,
              decoration: const BoxDecoration(
                  color: Color(0xFF059669), shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text('$count AKTIF',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 10, fontWeight: FontWeight.bold,
                  color: const Color(0xFF059669))),
        ]),
      );
}

class _OnlineDriverCard extends StatelessWidget {
  final _DriverD driver;
  final VoidCallback? onTap;
  const _OnlineDriverCard({required this.driver, this.onTap});
  @override
  Widget build(BuildContext context) {
    final initials = driver.name.trim().split(' ').take(2).map((w) => w[0]).join();
    return GestureDetector(
      onTap: onTap,
      child: Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B0E6E), Color(0xFF0540F2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: _C.primary.withValues(alpha: 0.30),
              blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5)),
              child: Center(
                child: Text(initials,
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: _C.green.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6,
                    decoration: const BoxDecoration(
                        color: Color(0xFF34D399), shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('Online',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 9, fontWeight: FontWeight.bold,
                        color: Color(0xFF34D399))),
              ]),
            ),
          ]),
          const Spacer(),
          Text(driver.name.split(' ').first,
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
          const SizedBox(height: 2),
          Text(driver.plate,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 10, color: Colors.white.withValues(alpha: 0.6))),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFBBF24)),
            const SizedBox(width: 3),
            Text('${driver.rating}',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(width: 10),
            const Icon(Icons.local_taxi_rounded, size: 11, color: Colors.white54),
            const SizedBox(width: 3),
            Text('${driver.trips} trip',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
          ]),
        ],
      ),
    ));
  }
}

class _ActiveTripCard extends StatelessWidget {
  final _TripD trip;
  final VoidCallback? onTap;
  const _ActiveTripCard({required this.trip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final isOngoing = trip.status == 'ONGOING';

    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: _C.shadow, blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: isOngoing
                ? _C.primary.withValues(alpha: 0.1)
                : _C.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isOngoing ? Icons.directions_bike_rounded : Icons.person_pin_circle_rounded,
            color: isOngoing ? _C.primary : _C.orange, size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${trip.from.isEmpty ? "Asal" : trip.from}  →',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600, fontSize: 12, color: _C.dark),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(trip.to.isEmpty ? 'Tujuan' : trip.to,
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600, fontSize: 12, color: _C.primary),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('${trip.passenger}  •  Driver: ${trip.driver}',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: _C.dark.withValues(alpha: 0.55))),
          ],
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(idr.format(trip.fare),
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold, fontSize: 13, color: _C.primary)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isOngoing
                  ? _C.primary.withValues(alpha: 0.1)
                  : _C.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(isOngoing ? 'Perjalanan' : 'Menjemput',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10, fontWeight: FontWeight.bold,
                    color: isOngoing ? _C.primary : _C.orange)),
          ),
        ]),
      ]),
    ));
  }
}

class _BottomSheet extends StatelessWidget {
  final String title;
  final int? count;
  final IconData icon;
  final Color color;
  final Widget child;
  const _BottomSheet({
    required this.title, this.count, required this.icon,
    required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(
            width: 44, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold, fontSize: 18, color: _C.dark)),
                  if (count != null)
                    Text('$count item',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, color: _C.dark.withValues(alpha: 0.5))),
                ],
              )),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.black54),
              ),
            ]),
          ),
          const Divider(height: 24, indent: 20, endIndent: 20),
          Expanded(child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [child, const SizedBox(height: 32)],
          )),
        ]),
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  final List<_UserD> users;
  const _UserList({required this.users});
  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text('Belum ada penumpang terdaftar',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, color: _C.dark.withValues(alpha: 0.4))),
        ),
      );
    }
    return Column(
        children: users.map((u) {
          final dtStr = u.createdAt.isNotEmpty
              ? () {
                  try {
                    final dt = DateTime.parse(u.createdAt).toLocal();
                    return DateFormat('dd MMM yyyy', 'id_ID').format(dt);
                  } catch (_) { return ''; }
                }()
              : '';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _C.primary.withValues(alpha: 0.12),
                child: Text(u.name.isNotEmpty ? u.name[0] : '?',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold, color: _C.primary, fontSize: 14)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.name,
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600, fontSize: 14, color: _C.dark)),
                  Text(u.phone,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: _C.dark.withValues(alpha: 0.5))),
                  if (dtStr.isNotEmpty)
                    Text('Bergabung $dtStr',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 10, color: _C.primary.withValues(alpha: 0.65))),
                ],
              )),
              Row(children: [
                Container(width: 7, height: 7,
                    decoration: BoxDecoration(
                        color: u.active ? _C.green : Colors.grey,
                        shape: BoxShape.circle)),
                const SizedBox(width: 3),
                Text(u.active ? 'Aktif' : 'Nonaktif',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10, color: u.active ? _C.green : Colors.grey)),
              ]),
            ]),
          );
        }).toList(),
      );
  }
}

class _DriverListLoader extends StatefulWidget {
  final Dio dio;
  const _DriverListLoader({required this.dio});
  @override
  State<_DriverListLoader> createState() => _DriverListLoaderState();
}

class _DriverListLoaderState extends State<_DriverListLoader> {
  bool _loading = true;
  List<_DriverD> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final r       = await widget.dio.get('/admin/drivers');
      final rawData = r.data;
      final rawList = rawData is List ? rawData : <dynamic>[];
      final parsed  = <_DriverD>[];
      for (final d in rawList) {
        try {
          final m       = Map<String, dynamic>.from(d as Map);
          final userRaw = m['user'];
          final user    = userRaw != null
              ? Map<String, dynamic>.from(userRaw as Map)
              : <String, dynamic>{};
          parsed.add(_DriverD(
            m['id']?.toString()           ?? '',
            user['name']?.toString()      ?? '-',
            user['phone']?.toString()     ?? '-',
            m['isOnline'] == true,
            double.tryParse(m['rating']?.toString() ?? '0') ?? 0.0,
            int.tryParse(m['totalRides']?.toString() ?? '0') ?? 0,
            m['vehiclePlate']?.toString() ?? '-',
            m['vehicleType']?.toString()  ?? '-',
            m['ktpNumber']?.toString()    ?? '-',
            m['createdAt']?.toString()    ?? '',
          ));
        } catch (_) {}
      }
      parsed.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (mounted) setState(() { _items = parsed; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _items = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(color: _C.primary),
      ));
    }
    return _DriverList(drivers: _items);
  }
}

class _DriverList extends StatelessWidget {
  final List<_DriverD> drivers;
  const _DriverList({required this.drivers});
  @override
  Widget build(BuildContext context) {
    if (drivers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text('Belum ada driver',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, color: _C.dark.withValues(alpha: 0.4))),
        ),
      );
    }
    return Column(
      children: drivers.map((d) => GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (ctx) => _DriverDetailDialog(driver: d),
        ),
        child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(14),
          border: d.online ? Border.all(color: _C.green.withValues(alpha: 0.3)) : null,
        ),
        child: Row(children: [
          Stack(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _C.primary.withValues(alpha: 0.12),
              child: Text(d.name.isNotEmpty ? d.name[0] : '?',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold, color: _C.primary, fontSize: 16)),
            ),
            if (d.online)
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                      color: _C.green, shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2)),
                ),
              ),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.name,
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600, fontSize: 14, color: _C.dark)),
              Text('${d.plate}  •  ${d.trips} trip',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: _C.dark.withValues(alpha: 0.5))),
            ],
          )),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(children: [
              const Icon(Icons.star_rounded, size: 14, color: Color(0xFFD97706)),
              const SizedBox(width: 3),
              Text(d.rating.toStringAsFixed(1),
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold, fontSize: 13, color: _C.dark)),
            ]),
            const SizedBox(height: 4),
            Text(d.online ? '● Online' : '○ Offline',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: d.online ? _C.green : Colors.grey)),
          ]),
        ]),
      ))).toList(),
    );
  }
}

class _DriverDetailDialog extends StatelessWidget {
  final _DriverD driver;
  const _DriverDetailDialog({required this.driver});

  String _fmtDate(String iso) {
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(iso).toLocal());
    } catch (_) { return '-'; }
  }

  @override
  Widget build(BuildContext context) {
    final initial = driver.name.isNotEmpty ? driver.name[0].toUpperCase() : '?';
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: _C.primary,
                child: Text(initial,
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(driver.name,
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold, fontSize: 16, color: _C.dark)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.circle,
                        size: 8, color: driver.online ? _C.green : Colors.grey),
                    const SizedBox(width: 4),
                    Text(driver.online ? 'Online' : 'Offline',
                        style: GoogleFonts.plusJakartaSans(
                            color: driver.online ? _C.green : Colors.grey,
                            fontSize: 12)),
                  ]),
                ],
              )),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.black54)),
            ]),
            const Divider(height: 24),
            _DrvInfoRow(Icons.phone_rounded,       'Nomor HP',         driver.phone),
            _DrvInfoRow(Icons.credit_card_rounded,  'Nomor KTP',        driver.ktpNumber),
            _DrvInfoRow(Icons.directions_bike_rounded, 'Plat Kendaraan', driver.plate),
            _DrvInfoRow(Icons.electric_moped_rounded,  'Jenis Kendaraan', driver.vehicleType),
            _DrvInfoRow(Icons.star_rounded,         'Rating',
                '${driver.rating.toStringAsFixed(1)} ⭐'),
            _DrvInfoRow(Icons.route_rounded,        'Total Trip',       '${driver.trips} trip'),
            _DrvInfoRow(Icons.calendar_today_rounded, 'Bergabung',
                driver.createdAt.isNotEmpty ? _fmtDate(driver.createdAt) : '-'),
          ],
        ),
      ),
    );
  }
}

class _DrvInfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DrvInfoRow(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            color: const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: _C.primary, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.grey, fontSize: 11)),
          Text(value.isNotEmpty ? value : '-',
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600, fontSize: 14, color: _C.dark)),
        ],
      )),
    ]),
  );
}

class _TripsByDriverList extends StatefulWidget {
  final List<_DriverTripGroup> groups;
  const _TripsByDriverList({required this.groups});
  @override
  State<_TripsByDriverList> createState() => _TripsByDriverListState();
}

class _TripsByDriverListState extends State<_TripsByDriverList> {
  final Set<String> _expanded = {};
  int _periodIdx = 0;

  static const _periodLabels = ['Hari Ini', 'Minggu Ini', 'Bulan Ini'];

  String _statusLabel(String s) => switch (s) {
    'ACCEPTED'  => 'Diterima',
    'PICKUP'    => 'Menjemput',
    'ONGOING'   => 'Perjalanan',
    'DONE'      => 'Selesai',
    'CANCELLED' => 'Batal',
    _           => s,
  };

  Color _statusColor(String s) => switch (s) {
    'ONGOING'   => _C.primary,
    'DONE'      => _C.green,
    'CANCELLED' => _C.red,
    _           => _C.orange,
  };

  List<_TripItem2> _filterTrips(List<_TripItem2> trips) {
    final now = DateTime.now();
    final DateTime cutoff;
    switch (_periodIdx) {
      case 0:
        cutoff = DateTime(now.year, now.month, now.day);
      case 1:
        cutoff = now.subtract(const Duration(days: 7));
      default:
        cutoff = DateTime(now.year, now.month, 1);
    }
    return trips.where((t) {
      if (t.createdAt.isEmpty) return false;
      final dt = DateTime.tryParse(t.createdAt)?.toLocal();
      return dt != null && dt.isAfter(cutoff);
    }).toList();
  }

  String _formatTripTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    final date = DateTime.tryParse(dateStr)?.toLocal();
    if (date == null) return '-';
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yest  = today.subtract(const Duration(days: 1));
    final tripDay = DateTime(date.year, date.month, date.day);
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    final t  = '$hh:$mm';
    if (tripDay == today)     return 'Hari ini $t';
    if (tripDay == yest)      return 'Kemarin $t';
    const days   = ['Sen','Sel','Rab','Kam','Jum','Sab','Min'];
    const months = ['Jan','Feb','Mar','Apr','Mei','Jun',
                    'Jul','Agt','Sep','Okt','Nov','Des'];
    return '${days[date.weekday-1]}, ${date.day} ${months[date.month-1]} $t';
  }

  @override
  Widget build(BuildContext context) {
    final idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_periodLabels.length, (i) {
              final sel = i == _periodIdx;
              return GestureDetector(
                onTap: () => setState(() => _periodIdx = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8, bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? _C.primary : _C.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_periodLabels[i],
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : _C.primary)),
                ),
              );
            }),
          ),
        ),

        if (widget.groups.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.route_rounded, size: 48,
                    color: _C.primary.withValues(alpha: 0.25)),
                const SizedBox(height: 12),
                Text('Belum ada trip',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, color: _C.dark.withValues(alpha: 0.45))),
              ]),
            ),
          )
        else
          ...widget.groups.map((g) {
            final filtered  = _filterTrips(g.trips);
            final filtRev   = filtered.where((t) => t.status == 'DONE')
                .fold<double>(0, (s, t) => s + t.fare);
            final isExp     = _expanded.contains(g.driverId);
            final initials  = g.driverName.trim().split(' ').take(2)
                .map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _C.primary.withValues(alpha: 0.08)),
                boxShadow: [BoxShadow(
                    color: _C.primary.withValues(alpha: 0.07),
                    blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Column(children: [

                GestureDetector(
                  onTap: () => setState(() {
                    if (isExp) { _expanded.remove(g.driverId); }
                    else { _expanded.add(g.driverId); }
                  }),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                            color: _C.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle),
                        child: Center(child: Text(initials,
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                color: _C.primary, fontSize: 14))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.driverName,
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14, color: _C.dark)),
                          Text('${filtered.length} trip  •  ${idr.format(filtRev)}',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: _C.dark.withValues(alpha: 0.5))),
                        ],
                      )),
                      Icon(
                        isExp ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                        color: _C.primary.withValues(alpha: 0.5), size: 20),
                    ]),
                  ),
                ),

                if (isExp) ...[
                  Divider(height: 1, color: _C.primary.withValues(alpha: 0.08)),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text('Tidak ada trip periode ini',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: _C.dark.withValues(alpha: 0.4))),
                      ),
                    )
                  else
                    ...filtered.map((t) {
                      final sc = _statusColor(t.status);
                      return Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                                color: _C.primary.withValues(alpha: 0.05)),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(t.passengerName,
                                      style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12, color: _C.dark),
                                      overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: sc.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Text(_statusLabel(t.status),
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: sc)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            Text('${t.origin}  →  ${t.dest}',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: _C.dark.withValues(alpha: 0.55)),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 5),

                            Row(children: [
                              Icon(Icons.access_time_rounded,
                                  size: 11,
                                  color: _C.dark.withValues(alpha: 0.4)),
                              const SizedBox(width: 3),
                              Text(_formatTripTime(t.createdAt),
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      color: _C.dark.withValues(alpha: 0.5))),
                              if (t.status == 'DONE' && t.fare > 0) ...[
                                const SizedBox(width: 10),
                                Icon(Icons.payments_rounded,
                                    size: 11, color: _C.green),
                                const SizedBox(width: 3),
                                Text(idr.format(t.fare),
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: _C.green)),
                              ],
                              if (t.distanceKm > 0) ...[
                                const SizedBox(width: 10),
                                Icon(Icons.route_rounded,
                                    size: 11,
                                    color: _C.dark.withValues(alpha: 0.4)),
                                const SizedBox(width: 3),
                                Text('${t.distanceKm.toStringAsFixed(1)} km',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        color: _C.dark.withValues(alpha: 0.5))),
                              ],
                            ]),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 4),
                ],
              ]),
            );
          }),
      ],
    );
  }
}

class _DriverEarningCard extends StatefulWidget {
  final _RevD2 data;
  final double pct, totalRevenue;
  const _DriverEarningCard({
    required this.data, required this.pct, required this.totalRevenue});
  @override
  State<_DriverEarningCard> createState() => _DriverEarningCardState();
}

class _DriverEarningCardState extends State<_DriverEarningCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final initials = widget.data.driverName.trim().split(' ')
        .take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.primary.withValues(alpha: 0.10)),
        boxShadow: [BoxShadow(
            color: _C.primary.withValues(alpha: 0.07),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(children: [

        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [

              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0B0940), Color(0xFF0540F2)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(initials,
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          color: Colors.white, fontSize: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.data.driverName,
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700, fontSize: 14, color: _C.dark)),
                  const SizedBox(height: 2),
                  Text('${widget.data.trips.length} trip hari ini',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: _C.dark.withValues(alpha: 0.5))),
                ],
              )),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(idr.format(widget.data.earnings),
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900, fontSize: 14, color: _C.primary)),
                const SizedBox(height: 2),
                Text('${(widget.pct * 100).toStringAsFixed(1)}%',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10, color: _C.dark.withValues(alpha: 0.4))),
              ]),
              const SizedBox(width: 8),
              Icon(
                _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: _C.primary.withValues(alpha: 0.5), size: 20),
            ]),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: widget.pct,
              minHeight: 5,
              backgroundColor: _C.primary.withValues(alpha: 0.07),
              valueColor: const AlwaysStoppedAnimation<Color>(_C.primary),
            ),
          ),
        ),

        if (_expanded) ...[
          Divider(height: 1, color: _C.primary.withValues(alpha: 0.08)),
          ...widget.data.trips.map((t) => Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: _C.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.route_rounded, size: 14, color: _C.primary),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.from.isEmpty ? 'Asal' : t.from,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, fontWeight: FontWeight.w600, color: _C.dark),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Row(children: [
                    const Icon(Icons.arrow_downward_rounded, size: 10,
                        color: Color(0xFF0540F2)),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(t.to.isEmpty ? 'Tujuan' : t.to,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, color: _C.primary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ],
              )),
              Text(idr.format(t.fare),
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold, fontSize: 12, color: _C.primary)),
            ]),
          )),
          const SizedBox(height: 4),
        ],
      ]),
    );
  }
}

class _RevenuePeriodSheet extends StatefulWidget {
  final Dio dio;
  const _RevenuePeriodSheet({required this.dio});
  @override
  State<_RevenuePeriodSheet> createState() => _RevenuePeriodSheetState();
}

class _RevenuePeriodSheetState extends State<_RevenuePeriodSheet> {
  int _tabIdx = 1;
  bool _loading = false;
  List<_RevD2> _earnings = [];

  static const _periods = ['today', 'week', 'month', 'last_month'];
  static const _labels  = ['Hari Ini', 'Minggu Ini', 'Bulan Ini', 'Bulan Lalu'];

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final r    = await widget.dio.get('/admin/revenue',
          queryParameters: {'period': _periods[_tabIdx]});
      final list = r.data as List? ?? [];
      if (!mounted) return;
      setState(() {
        _earnings = list.map((item) {
          final m     = Map<String, dynamic>.from(item as Map);
          final trips = (m['trips'] as List? ?? []).map((t) {
            final tm = Map<String, dynamic>.from(t as Map);
            return _TripEntry(
              tm['rideId']            as String? ?? '',
              (tm['fare'] as num?)?.toDouble() ?? 0,
              tm['originAddress']      as String? ?? 'Asal',
              tm['destinationAddress'] as String? ?? 'Tujuan',
            );
          }).toList();
          return _RevD2(
            m['driverId']      as String? ?? '',
            m['driverName']    as String? ?? '-',
            (m['totalRevenue'] as num?)?.toDouble() ?? 0,
            trips,
          );
        }).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _earnings = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final idr   = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final total = _earnings.fold<double>(0, (s, r) => s + r.earnings);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_labels.length, (i) {
            final sel = i == _tabIdx;
            return GestureDetector(
              onTap: () { setState(() { _tabIdx = i; }); _fetch(); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? _C.primary : _C.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_labels[i],
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : _C.primary)),
              ),
            );
          }),
        ),
      ),
      const SizedBox(height: 16),

      if (_loading)
        const Center(child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: _C.primary),
        ))
      else if (_earnings.isEmpty)
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.payments_outlined, size: 48,
                  color: _C.primary.withValues(alpha: 0.25)),
              const SizedBox(height: 12),
              Text('Belum ada pendapatan periode ini',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, color: _C.dark.withValues(alpha: 0.4))),
            ]),
          ),
        )
      else ...[
        ..._earnings.map((r) {
          final pct = total > 0 ? r.earnings / total : 0.0;
          return _DriverEarningCard(data: r, pct: pct, totalRevenue: total);
        }),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF0B0940), Color(0xFF0540F2)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            const Icon(Icons.payments_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Pendapatan',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: Colors.white60)),
                Text(idr.format(total),
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900, fontSize: 18,
                        color: Colors.white)),
              ],
            )),
            Text('${_earnings.length} driver',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: Colors.white54)),
          ]),
        ),
      ],
    ]);
  }
}

class _WeeklyReportLoader extends StatefulWidget {
  final Dio dio;
  const _WeeklyReportLoader({required this.dio});
  @override
  State<_WeeklyReportLoader> createState() => _WeeklyReportLoaderState();
}

class _WeeklyReportLoaderState extends State<_WeeklyReportLoader> {
  bool _loading = true;
  Map<String, dynamic> _report = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await widget.dio.get('/admin/reports/summary');
      if (mounted) setState(() { _report = Map<String, dynamic>.from(r.data as Map); _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _report = {}; _loading = false; });
    }
  }

  Future<void> _downloadExcel(BuildContext ctx) async {
    try {
      final excel = xl.Excel.createExcel();

      final sheet = excel['Laporan Mingguan'];
      const headers = ['No','Penumpang','Driver','Asal','Tujuan','Status','Tarif (Rp)','Jarak (km)','Waktu'];
      sheet.appendRow(headers.map((h) => xl.TextCellValue(h)).toList());
      for (int c = 0; c < headers.length; c++) {
        final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
        cell.cellStyle = xl.CellStyle(
          bold: true,
          backgroundColorHex: xl.ExcelColor.fromHexString('#0540F2'),
          fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
        );
      }

      final trips = (_report['trips'] as List? ?? []);
      for (int i = 0; i < trips.length; i++) {
        final t   = Map<String, dynamic>.from(trips[i] as Map);
        final dt  = DateTime.tryParse(t['createdAt']?.toString() ?? '')?.toLocal();
        final dtS = dt != null
            ? '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'
            : '-';
        sheet.appendRow([
          xl.IntCellValue(i + 1),
          xl.TextCellValue(t['passengerName']?.toString() ?? '-'),
          xl.TextCellValue(t['driverName']?.toString()    ?? '-'),
          xl.TextCellValue(t['originAddress']?.toString() ?? '-'),
          xl.TextCellValue(t['destinationAddress']?.toString() ?? '-'),
          xl.TextCellValue(t['status']?.toString()         ?? '-'),
          xl.IntCellValue(int.tryParse(t['fare']?.toString() ?? '0') ?? 0),
          xl.DoubleCellValue(double.tryParse(t['distanceKm']?.toString() ?? '0') ?? 0),
          xl.TextCellValue(dtS),
        ]);
      }

      final s2 = excel['Ringkasan'];
      final summary = Map<String, dynamic>.from(_report['summary'] as Map? ?? {});
      s2.appendRow([xl.TextCellValue('Metrik'), xl.TextCellValue('Nilai')]);
      s2.appendRow([xl.TextCellValue('Total Trip'),         xl.IntCellValue(summary['totalTrips']     as int? ?? 0)]);
      s2.appendRow([xl.TextCellValue('Trip Selesai'),       xl.IntCellValue(summary['completedTrips'] as int? ?? 0)]);
      s2.appendRow([xl.TextCellValue('Trip Batal'),         xl.IntCellValue(summary['cancelledTrips'] as int? ?? 0)]);
      s2.appendRow([xl.TextCellValue('Total Pendapatan (Rp)'), xl.DoubleCellValue((summary['totalRevenue'] as num?)?.toDouble() ?? 0)]);
      s2.appendRow([xl.TextCellValue('Completion Rate (%)'), xl.IntCellValue(summary['completionRate'] as int? ?? 0)]);

      final bytes = excel.save();
      if (bytes == null) return;

      final dir      = await getApplicationDocumentsDirectory();
      final now      = DateTime.now();
      final filename = 'Laporan_Lungo_${now.day}-${now.month}-${now.year}.xlsx';
      final file     = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Laporan Mingguan Lungo',
        text: 'Laporan perjalanan Lungo 7 hari terakhir',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal buat laporan: $e',
            style: GoogleFonts.plusJakartaSans(color: Colors.white)),
        backgroundColor: _C.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext ctx) {
    if (_loading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(color: _C.primary),
      ));
    }
    if (_report.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Text('Gagal memuat laporan',
            style: GoogleFonts.plusJakartaSans(
                color: _C.dark.withValues(alpha: 0.4))),
      ));
    }

    final idr     = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final summary = Map<String, dynamic>.from(_report['summary'] as Map? ?? {});
    final period  = Map<String, dynamic>.from(_report['period']  as Map? ?? {});
    final trips   = (_report['trips'] as List? ?? []).take(10).toList();

    final startDt = DateTime.tryParse(period['start']?.toString() ?? '')?.toLocal();
    final endDt   = DateTime.tryParse(period['end']?.toString()   ?? '')?.toLocal();
    final periodStr = (startDt != null && endDt != null)
        ? '${DateFormat('d MMM', 'id_ID').format(startDt)} – ${DateFormat('d MMM yyyy', 'id_ID').format(endDt)}'
        : '-';

    final totalTrips     = summary['totalTrips']     as int? ?? 0;
    final completedTrips = summary['completedTrips'] as int? ?? 0;
    final cancelledTrips = summary['cancelledTrips'] as int? ?? 0;
    final totalRevenue   = (summary['totalRevenue']  as num?)?.toDouble() ?? 0.0;
    final completionRate = summary['completionRate'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: _C.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.calendar_today_rounded, size: 13, color: _C.primary),
            const SizedBox(width: 6),
            Text(periodStr,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, fontWeight: FontWeight.w600, color: _C.primary)),
          ]),
        ),
        const SizedBox(height: 16),

        Row(children: [
          _SummaryCard('Total Trip',   '$totalTrips',             Icons.route_rounded,        _C.primary),
          const SizedBox(width: 10),
          _SummaryCard('Selesai',      '$completedTrips',         Icons.check_circle_rounded, _C.green),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _SummaryCard('Dibatalkan',   '$cancelledTrips',         Icons.cancel_rounded,       _C.red),
          const SizedBox(width: 10),
          _SummaryCard('Pendapatan',   idr.format(totalRevenue),  Icons.payments_rounded,     _C.dark, small: true),
        ]),
        const SizedBox(height: 16),

        Row(children: [
          Text('$completionRate% selesai',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: _C.dark.withValues(alpha: 0.6))),
          const Spacer(),
          Text('$completedTrips / $totalTrips trip',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, color: _C.dark.withValues(alpha: 0.4))),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: totalTrips > 0 ? completedTrips / totalTrips : 0,
            minHeight: 7,
            backgroundColor: _C.primary.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(_C.green),
          ),
        ),
        const SizedBox(height: 20),

        if (trips.isNotEmpty) ...[
          Text('10 Trip Terbaru',
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold, fontSize: 13, color: _C.dark)),
          const SizedBox(height: 10),
          ...trips.map((item) {
            final t      = Map<String, dynamic>.from(item as Map);
            final status = t['status']?.toString() ?? '-';
            final sc     = switch (status) {
              'DONE'      => _C.green,
              'CANCELLED' => _C.red,
              'ONGOING'   => _C.primary,
              _           => _C.orange,
            };
            final sl = switch (status) {
              'DONE'      => 'Selesai',
              'CANCELLED' => 'Batal',
              'ONGOING'   => 'Perjalanan',
              'ACCEPTED'  => 'Diterima',
              'PICKUP'    => 'Menjemput',
              _           => status,
            };
            final fare = (t['fare'] as num?)?.toDouble() ?? 0;
            final dt   = DateTime.tryParse(t['createdAt']?.toString() ?? '')?.toLocal();
            final dtS  = dt != null
                ? DateFormat('d MMM, HH:mm', 'id_ID').format(dt)
                : '-';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text('${t['passengerName'] ?? '-'}  →  ${t['driverName'] ?? '-'}',
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600, fontSize: 12, color: _C.dark),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: sc.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(sl, style: GoogleFonts.plusJakartaSans(
                          fontSize: 9, fontWeight: FontWeight.bold, color: sc)),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text('${t['originAddress'] ?? '-'}  →  ${t['destinationAddress'] ?? '-'}',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: _C.dark.withValues(alpha: 0.5)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.access_time_rounded, size: 11, color: _C.dark.withValues(alpha: 0.4)),
                    const SizedBox(width: 3),
                    Text(dtS, style: GoogleFonts.plusJakartaSans(
                        fontSize: 10, color: _C.dark.withValues(alpha: 0.5))),
                    if (fare > 0) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.payments_rounded, size: 11, color: _C.green),
                      const SizedBox(width: 3),
                      Text(idr.format(fare), style: GoogleFonts.plusJakartaSans(
                          fontSize: 10, fontWeight: FontWeight.w600, color: _C.green)),
                    ],
                  ]),
                ],
              ),
            );
          }),
        ],

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => _downloadExcel(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF2CB05),
              foregroundColor: _C.dark,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            icon: const Icon(Icons.download_rounded, size: 20, color: _C.dark),
            label: Text('Unduh Laporan Excel',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold, fontSize: 14, color: _C.dark)),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool small;
  const _SummaryCard(this.label, this.value, this.icon, this.color, {this.small = false});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10, color: _C.dark.withValues(alpha: 0.5))),
            Text(value,
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: small ? 12 : 16, color: color),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        )),
      ]),
    ),
  );
}

class _ComplaintList extends StatelessWidget {
  final List<_ComplaintD> complaints;
  const _ComplaintList({required this.complaints});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ...complaints.map((c) {
        final (typeLabel, typeColor) = switch (c.type) {
          'SUGGESTION' => ('Saran',    _C.orange),
          'PRAISE'     => ('Pujian',   _C.green),
          _            => ('Pengaduan', _C.red),
        };
        final (statusLabel, statusColor) = switch (c.status) {
          'RESOLVED'  => ('Dijawab', _C.green),
          'IN_REVIEW' => ('Diproses', _C.orange),
          _           => ('Terbuka', _C.primary),
        };
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFF),
            borderRadius: BorderRadius.circular(14),
            border: c.status == 'OPEN'
                ? Border.all(color: _C.red.withValues(alpha: 0.3))
                : null,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _Chip(label: typeLabel, color: typeColor),
              const SizedBox(width: 6),
              _Chip(label: statusLabel, color: statusColor),
              const Spacer(),
              Text(c.user,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: _C.dark.withValues(alpha: 0.5))),
            ]),
            const SizedBox(height: 8),
            Text(c.message,
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _C.dark),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        );
      }),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/admin/complaints'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _C.purple),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.open_in_new_rounded, size: 16, color: _C.purple),
          label: Text('Kelola Semua Saran & Kritik',
              style: GoogleFonts.plusJakartaSans(
                  color: _C.purple, fontWeight: FontWeight.bold)),
        ),
      ),
    ],
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Text(label,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 10, fontWeight: FontWeight.bold, color: color)),
      );
}

class _UserD {
  final String id, name, phone, role, createdAt;
  final bool active;
  const _UserD(this.id, this.name, this.phone, this.role, this.active, this.createdAt);
}

class _DriverD {
  final String id, name, phone, plate, vehicleType, ktpNumber, createdAt;
  final bool online;
  final double rating;
  final int trips;
  const _DriverD(this.id, this.name, this.phone, this.online, this.rating,
      this.trips, this.plate, this.vehicleType, this.ktpNumber, this.createdAt);
}

class _TripD {
  final String passenger, driver, from, to, status;
  final double fare;
  const _TripD(this.passenger, this.driver, this.from, this.to, this.fare, this.status);
}

class _RevD2 {
  final String driverId, driverName;
  double earnings;
  final List<_TripEntry> trips;
  _RevD2(this.driverId, this.driverName, this.earnings, this.trips);
}

class _TripEntry {
  final String rideId, from, to;
  final double fare;
  const _TripEntry(this.rideId, this.fare, this.from, this.to);
}

class _ComplaintD {
  final String user, type, message, status;
  const _ComplaintD(this.user, this.type, this.message, this.status);
}

class _LiveDriver {
  final String driverId;
  double lat, lng;
  bool online;
  _LiveDriver(this.driverId, this.lat, this.lng) : online = true;
}

class _LiveRide {
  final String rideId;
  String passengerName;
  String driverName = '';
  String status;
  double fare;
  _LiveRide({
    required this.rideId,
    required this.passengerName,
    required this.status,
    required this.fare,
  });
}

class _LiveEvent {
  final String message;
  final DateTime time;
  _LiveEvent(this.message, this.time);
}

class _ChartPoint {
  final String day;
  final double revenue;
  final int tripCount;
  const _ChartPoint({required this.day, required this.revenue, required this.tripCount});
}

class _TripItem2 {
  final String id, passengerName, origin, dest, status, createdAt;
  final double fare, distanceKm;
  const _TripItem2(this.id, this.passengerName, this.origin, this.dest,
      this.status, this.fare, this.createdAt, this.distanceKm);
}

class _DriverTripGroup {
  final String driverId, driverName;
  final int totalTrips;
  final double totalRevenue;
  final List<_TripItem2> trips;
  const _DriverTripGroup(this.driverId, this.driverName, this.totalTrips,
      this.totalRevenue, this.trips);
}
