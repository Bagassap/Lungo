import 'dart:async';
import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
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

final _demoReports    = <_WeeklyD>[];
final _demoComplaints = <_ComplaintD>[];

const _weekBars   = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
const _weekLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

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

  List<_UserD>   _users           = [];
  List<_DriverD> _drivers         = [];
  List<_TripD>   _trips           = [];
  List<_RevD2>   _driverEarnings  = [];

  // Live WebSocket data
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

        // Map with driver markers
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

        // Live rides
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

        // Event feed
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
    await Future.wait([_loadUsers(), _loadDrivers(), _loadTrips(), _loadTodayEarnings()]);
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
          );
        }).where((u) => u.role == 'PASSENGER').toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      });
    } catch (_) {}
  }

  Future<void> _loadDrivers() async {
    try {
      final r    = await _dio.get('/admin/drivers', queryParameters: {'filter': 'verified'});
      final list = r.data as List? ?? [];
      if (!mounted) return;
      setState(() => _drivers = list.map((d) {
        final m    = Map<String, dynamic>.from(d as Map);
        final user = m['user'] as Map? ?? {};
        return _DriverD(
          m['id']           as String? ?? '',
          user['name']      as String? ?? '-',
          user['phone']     as String? ?? '-',
          m['isOnline']     as bool?   ?? false,
          (m['rating']      as num?)?.toDouble() ?? 0.0,
          (m['totalRides']  as num?)?.toInt()    ?? 0,
          m['vehiclePlate'] as String? ?? '-',
        );
      }).toList());
    } catch (_) {}
  }

  Future<void> _loadTrips() async {
    try {
      final r    = await _dio.get('/admin/trips', queryParameters: {'limit': '50'});
      final raw  = r.data;
      final list = (raw is Map ? raw['rides'] : raw) as List? ?? [];
      if (!mounted) return;
      const activeSet = {'SEARCHING', 'ACCEPTED', 'PICKUP', 'ONGOING'};
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
      }).where((t) => activeSet.contains(t.status)).toList());
    } catch (_) {}
  }

  Future<void> _loadTodayEarnings() async {
    try {
      final r = await _dio.get('/admin/trips', queryParameters: {
        'status': 'DONE',
        'limit': '200',
      });
      final raw  = r.data;
      final list = (raw is Map ? raw['rides'] : raw) as List? ?? [];
      final today = DateTime.now();
      final Map<String, _RevD2> byDriver = {};
      for (final item in list) {
        final m = Map<String, dynamic>.from(item as Map);
        final createdAtStr = m['createdAt'] as String?;
        if (createdAtStr == null) continue;
        final date = DateTime.parse(createdAtStr).toLocal();
        if (date.year != today.year || date.month != today.month || date.day != today.day) continue;
        final driverId   = m['driverId']   as String? ?? '';
        final driverName = m['driverName'] as String? ?? '-';
        final fare   = (m['fare'] as num?)?.toDouble() ?? 0;
        final rideId = m['id']            as String? ?? '';
        final from   = m['originAddress']      as String? ?? 'Asal';
        final to     = m['destinationAddress'] as String? ?? 'Tujuan';
        if (driverId.isEmpty) continue;
        byDriver.putIfAbsent(driverId, () => _RevD2(driverId, driverName, 0.0, []));
        byDriver[driverId]!.earnings += fare;
        byDriver[driverId]!.trips.add(_TripEntry(rideId, fare, from, to));
      }
      if (!mounted) return;
      setState(() => _driverEarnings = byDriver.values.toList()
          ..sort((a, b) => b.earnings.compareTo(a.earnings)));
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
          child: _DriverList(drivers: _drivers),
        ),
      );

  void _showTrips() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _BottomSheet(
          title: 'Trip Aktif',
          count: _activeTrips,
          icon: Icons.route_rounded,
          color: _C.orange,
          child: _TripList(trips: _trips),
        ),
      );

  void _showRevenue() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _BottomSheet(
          title: 'Pendapatan Hari Ini',
          count: null,
          icon: Icons.payments_rounded,
          color: _C.primary,
          child: _RevenueDetail(
            todayRevenue:   _todayRevenue,
            weekRevenue:    _weekRevenue,
            driverEarnings: _driverEarnings,
          ),
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
          child: _WeeklyReportList(reports: _demoReports),
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
                label: 'Trip Aktif',
                sub: 'Sedang berjalan',
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
                const Icon(Icons.trending_up_rounded,
                    size: 14, color: Color(0xFF059669)),
                const SizedBox(width: 4),
                Text('+12.4%',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, fontWeight: FontWeight.bold,
                        color: const Color(0xFF059669))),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            height: 90,
            child: _BarChart(values: _weekBars, labels: _weekLabels),
          ),
        ],
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

class _BarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  const _BarChart({required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    final maxVal = values.reduce(math.max);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(values.length, (i) {
        final frac = maxVal > 0 ? values[i] / maxVal : 0.0;
        final isToday = i == values.length - 1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 400 + i * 60),
                  curve: Curves.easeOutCubic,
                  height: frac * 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isToday
                          ? [const Color(0xFF0540F2), const Color(0xFF056CF2)]
                          : [const Color(0xFF0540F2).withValues(alpha: 0.25),
                             const Color(0xFF0540F2).withValues(alpha: 0.45)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(labels[i],
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday ? _C.primary : _C.dark.withValues(alpha: 0.5))),
              ],
            ),
          ),
        );
      }),
    );
  }
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
          final roleColor = u.role == 'DRIVER' ? _C.green : _C.primary;
          return GestureDetector(
            onTap: () => Navigator.pushNamed(
                context, '/admin/passenger-detail', arguments: u.id),
            child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: roleColor.withValues(alpha: 0.12),
                child: Text(u.name[0],
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold, color: roleColor, fontSize: 14)),
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
                ],
              )),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(u.role,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 10, fontWeight: FontWeight.bold, color: roleColor)),
                ),
                const SizedBox(height: 4),
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
            ]),
          ));
        }).toList(),
      );
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
        onTap: () => Navigator.pushNamed(
            context, '/admin/driver-detail', arguments: d.id),
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
              child: Text(d.name[0],
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
              Text('${d.rating}',
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

class _TripList extends StatelessWidget {
  final List<_TripD> trips;
  const _TripList({required this.trips});

  String _statusLabel(String s) => switch (s) {
    'SEARCHING' => 'Mencari Driver',
    'ACCEPTED'  => 'Driver Diterima',
    'PICKUP'    => 'Menjemput',
    'ONGOING'   => 'Dalam Perjalanan',
    _           => s,
  };

  Color _statusColor(String s) => switch (s) {
    'ONGOING'  => _C.primary,
    'ACCEPTED' => _C.green,
    'PICKUP'   => _C.green,
    _          => _C.orange,
  };

  @override
  Widget build(BuildContext context) {
    final idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    if (trips.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.route_rounded, size: 48,
                color: _C.primary.withValues(alpha: 0.25)),
            const SizedBox(height: 12),
            Text('Belum ada trip aktif',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, color: _C.dark.withValues(alpha: 0.45))),
          ]),
        ),
      );
    }
    return Column(
      children: trips.map((t) {
        final sColor = _statusColor(t.status);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _C.primary.withValues(alpha: 0.08)),
            boxShadow: [BoxShadow(
                color: _C.primary.withValues(alpha: 0.07),
                blurRadius: 12, offset: const Offset(0, 3))],
          ),
          child: Column(children: [
            // Header row — status + fare
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color: sColor.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: sColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(_statusLabel(t.status),
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, fontWeight: FontWeight.w700, color: sColor)),
                const Spacer(),
                if (t.fare > 0)
                  Text(idr.format(t.fare),
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold, fontSize: 13, color: _C.primary)),
              ]),
            ),
            // Route
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Column(children: [
                  Container(width: 8, height: 8,
                      decoration: const BoxDecoration(
                          color: Color(0xFF059669), shape: BoxShape.circle)),
                  Container(width: 1, height: 16,
                      color: _C.dark.withValues(alpha: 0.2)),
                  Container(width: 8, height: 8,
                      decoration: BoxDecoration(
                          color: _C.primary, shape: BoxShape.circle)),
                ]),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.from.isEmpty ? 'Asal tidak tersedia' : t.from,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: _C.dark),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    Text(t.to.isEmpty ? 'Tujuan tidak tersedia' : t.to,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: _C.primary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                )),
              ]),
            ),
            // People row
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(children: [
                _TripPerson(icon: Icons.person_rounded, name: t.passenger, color: _C.dark),
                Container(width: 1, height: 16,
                    color: _C.dark.withValues(alpha: 0.15),
                    margin: const EdgeInsets.symmetric(horizontal: 12)),
                _TripPerson(icon: Icons.electric_moped_rounded, name: t.driver, color: _C.primary),
              ]),
            ),
          ]),
        );
      }).toList(),
    );
  }
}

class _TripPerson extends StatelessWidget {
  final IconData icon;
  final String name;
  final Color color;
  const _TripPerson({required this.icon, required this.name, this.color = _C.dark});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(name,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.85))),
      ]);
}

class _RevenueDetail extends StatelessWidget {
  final double todayRevenue, weekRevenue;
  final List<_RevD2> driverEarnings;
  const _RevenueDetail({
    required this.todayRevenue, required this.weekRevenue,
    required this.driverEarnings,
  });

  @override
  Widget build(BuildContext context) {
    final idr   = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final total = driverEarnings.fold<double>(0, (s, r) => s + r.earnings);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Today + week summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B0940), Color(0xFF0540F2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hari Ini',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: Colors.white60)),
              const SizedBox(height: 4),
              Text(idr.format(todayRevenue),
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
            ])),
            Container(width: 1, height: 36, color: Colors.white24),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Minggu Ini',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: Colors.white60)),
              const SizedBox(height: 4),
              Text(idr.format(weekRevenue),
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
            ])),
          ]),
        ),
        const SizedBox(height: 20),

        if (driverEarnings.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.payments_outlined, size: 48,
                    color: _C.primary.withValues(alpha: 0.25)),
                const SizedBox(height: 12),
                Text('Belum ada pendapatan hari ini',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, color: _C.dark.withValues(alpha: 0.4))),
              ]),
            ),
          )
        else ...[
          Row(children: [
            Text('Pendapatan per Driver',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold, fontSize: 14, color: _C.dark)),
            const Spacer(),
            Text('${driverEarnings.length} driver',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: _C.dark.withValues(alpha: 0.45))),
          ]),
          const SizedBox(height: 12),
          ...driverEarnings.map((r) {
            final pct = total > 0 ? r.earnings / total : 0.0;
            return _DriverEarningCard(data: r, pct: pct, totalRevenue: total);
          }),
        ],
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
        // Main row
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              // Avatar
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
        // Progress bar
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
        // Expanded trip list
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

class _WeeklyReportList extends StatelessWidget {
  final List<_WeeklyD> reports;
  const _WeeklyReportList({required this.reports});
  @override
  Widget build(BuildContext context) {
    final idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_C.primary, Color(0xFF056CF2)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('Periode: 21 – 27 April 2026',
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 16),
        ...reports.map((r) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _C.primary.withValues(alpha: 0.1),
                child: Text(r.driverName[0],
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold, color: _C.primary)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(r.driverName,
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold, fontSize: 14, color: _C.dark))),
              Row(children: [
                const Icon(Icons.star_rounded, size: 14, color: Color(0xFFD97706)),
                const SizedBox(width: 3),
                Text('${r.rating}',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold, fontSize: 13,
                        color: const Color(0xFFD97706))),
              ]),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _WMini(label: 'Trip', value: '${r.trips}'),
              _WMini(label: 'Pendapatan', value: idr.format(r.earnings)),
              _WMini(label: 'Avg/Trip',
                  value: r.trips > 0
                      ? idr.format(r.earnings / r.trips)
                      : '-'),
            ]),
          ]),
        )),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/admin/reports'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _C.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 16, color: _C.primary),
            label: Text('Lihat Semua Laporan',
                style: GoogleFonts.plusJakartaSans(
                    color: _C.primary, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

class _WMini extends StatelessWidget {
  final String label, value;
  const _WMini({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold, fontSize: 14, color: _C.primary)),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 10, color: _C.dark.withValues(alpha: 0.5))),
        ]),
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
  final String id, name, phone, role;
  final bool active;
  const _UserD(this.id, this.name, this.phone, this.role, this.active);
}

class _DriverD {
  final String id, name, phone, plate;
  final bool online;
  final double rating;
  final int trips;
  const _DriverD(this.id, this.name, this.phone, this.online, this.rating, this.trips, this.plate);
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

class _WeeklyD {
  final String driverName, period;
  final int trips;
  final double earnings, rating;
  const _WeeklyD(this.driverName, this.period, this.trips, this.earnings, this.rating);
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
