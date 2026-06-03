import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';

class _C {
  static const bg      = Color(0xFFF1F5FB);
  static const primary = Color(0xFF0540F2);
  static const dark    = Color(0xFF0C1445);
  static const green   = Color(0xFF00B87C);
  static const orange  = Color(0xFFFF8C00);
  static const red     = Color(0xFFEF4444);
  static const purple  = Color(0xFF7C3AED);
  static const card    = Colors.white;
}

final _idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

class AdminActivityScreen extends StatefulWidget {
  const AdminActivityScreen({super.key});
  @override
  State<AdminActivityScreen> createState() => _AdminActivityScreenState();
}

class _AdminActivityScreenState extends State<AdminActivityScreen>
    with TickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: const [
                _UsersTab(),
                _DriversTab(),
                _TripsTab(),
                _TariffTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF020B52), Color(0xFF0B35D4), Color(0xFF0B5CF2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Manajemen',
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white, fontWeight: FontWeight.w900,
                          fontSize: 26, letterSpacing: -0.5)),
                  const SizedBox(height: 2),
                  Text('Kelola pengguna, driver & tarif',
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                ]),
                const Spacer(),
              ]),
            ),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                height: 48,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: TabBar(
                  controller: _tab,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  labelColor: _C.primary,
                  unselectedLabelColor: Colors.white.withValues(alpha: 0.65),
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800, fontSize: 12),
                  unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w500, fontSize: 12),
                  tabs: const [
                    Tab(text: 'Pengguna'),
                    Tab(text: 'Driver'),
                    Tab(text: 'Trip'),
                    Tab(text: 'Tarif'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _dio    = ApiClient.create();
  final _search = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _users = [];
  String _filter = 'Semua';
  final _filters = ['Semua', 'Penumpang', 'Driver'];

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _dio.get('/admin/users', queryParameters: {'limit': '100'});
      final list = (r.data['users'] as List?) ?? [];
      setState(() {
        _users = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() { _users = []; _loading = false; });
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> user) async {
    final newVal = !(user['isVerified'] as bool? ?? true);
    try {
      await _dio.patch('/admin/users/${user['id']}/status', data: {'active': newVal});
      setState(() => user['isVerified'] = newVal);
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _users;
    if (_filter == 'Penumpang') list = list.where((u) => u['role'] == 'PASSENGER').toList();
    if (_filter == 'Driver')    list = list.where((u) => u['role'] == 'DRIVER').toList();
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((u) =>
          (u['name']?.toString().toLowerCase().contains(q) ?? false) ||
          (u['phone']?.toString().contains(q) ?? false)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final total    = _users.length;
    final active   = _users.where((u) => u['isVerified'] == true).length;
    final inactive = total - active;

    return Column(children: [

      Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: Row(children: [
          _MiniStat('$total',    'Total',    Icons.people_rounded,
              const [Color(0xFF0540F2), Color(0xFF2A6AFF)]),
          const SizedBox(width: 10),
          _MiniStat('$active',   'Aktif',    Icons.check_circle_outline_rounded,
              const [Color(0xFF00B87C), Color(0xFF34D399)]),
          const SizedBox(width: 10),
          _MiniStat('$inactive', 'Nonaktif', Icons.highlight_off_rounded,
              const [Color(0xFFEF4444), Color(0xFFFF6B6B)]),
        ]),
      ),

      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Container(
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 12, offset: const Offset(0, 3))],
          ),
          child: TextField(
            controller: _search,
            style: GoogleFonts.plusJakartaSans(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Cari nama atau nomor HP...',
              hintStyle: GoogleFonts.plusJakartaSans(
                  color: Colors.grey.shade400, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded,
                  color: _C.primary.withValues(alpha: 0.5), size: 20),
              suffixIcon: _search.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () => _search.clear(),
                      child: Icon(Icons.close_rounded,
                          color: Colors.grey.shade400, size: 18))
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),

      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: _filters.map((f) {
            final sel = _filter == f;
            return GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? _C.primary : _C.card,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: sel
                      ? [BoxShadow(color: _C.primary.withValues(alpha: 0.35),
                          blurRadius: 10, offset: const Offset(0, 3))]
                      : [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Text(f,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : _C.dark.withValues(alpha: 0.65))),
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _C.primary))
            : RefreshIndicator(
                onRefresh: _load,
                color: _C.primary,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _UserCard(
                    user: _filtered[i],
                    onToggle: () => _toggleStatus(_filtered[i]),
                  ),
                ),
              ),
      ),
    ]);
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onToggle;
  const _UserCard({required this.user, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final name      = user['name']?.toString() ?? '-';
    final phone     = user['phone']?.toString() ?? '-';
    final role      = user['role']?.toString() ?? 'PASSENGER';
    final active    = user['isVerified'] as bool? ?? true;
    final isDriver  = role == 'DRIVER';
    final roleColor = isDriver ? _C.green : _C.primary;
    final roleLabel = isDriver ? 'Driver' : 'Penumpang';
    final initial   = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 16, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 3),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              Container(width: 4, color: roleColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Row(children: [

                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDriver
                              ? [const Color(0xFF00B87C), const Color(0xFF2DD4A0)]
                              : [const Color(0xFF0540F2), const Color(0xFF2A6AFF)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: Text(initial,
                          style: GoogleFonts.plusJakartaSans(
                              color: Colors.white, fontWeight: FontWeight.w800,
                              fontSize: 20))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(name,
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700, fontSize: 14.5,
                                color: _C.dark),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 5),
                        Row(children: [
                          Icon(Icons.phone_rounded,
                              size: 11, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(phone,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12, color: Colors.grey.shade500)),
                        ]),
                      ],
                    )),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(roleLabel,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10, fontWeight: FontWeight.w700,
                                  color: roleColor)),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: onToggle,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: (active ? _C.green : _C.red)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(width: 6, height: 6,
                                  decoration: BoxDecoration(
                                      color: active ? _C.green : _C.red,
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Text(active ? 'Aktif' : 'Nonaktif',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10, fontWeight: FontWeight.w700,
                                      color: active ? _C.green : _C.red)),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriversTab extends StatefulWidget {
  const _DriversTab();
  @override
  State<_DriversTab> createState() => _DriversTabState();
}

class _DriversTabState extends State<_DriversTab> {
  final _dio = ApiClient.create();
  bool _loading = true;
  List<Map<String, dynamic>> _drivers = [];
  String _filter = 'Semua';
  final _filters = ['Semua', 'Online', 'Offline', 'Verifikasi'];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _dio.get('/admin/drivers');
      final list = (r.data as List?) ?? [];
      setState(() {
        _drivers = list.map((e) {
          final d = Map<String, dynamic>.from(e as Map);
          final u = d['user'] as Map? ?? {};
          return {
            'id': d['userId'] ?? d['id'],
            'driverName': u['name'] ?? '-',
            'phone': u['phone'] ?? '-',
            'isOnline': d['isOnline'] ?? false,
            'rating': (d['rating'] as num?)?.toDouble() ?? 0.0,
            'trips': d['totalRides'] ?? 0,
            'plate': d['vehiclePlate'] ?? '-',
            'status': d['registrationStatus'] ?? 'PENDING',
          };
        }).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() { _drivers = []; _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'Online')     return _drivers.where((d) => d['isOnline'] == true).toList();
    if (_filter == 'Offline')    return _drivers.where((d) => d['isOnline'] != true).toList();
    if (_filter == 'Verifikasi') return _drivers.where((d) => d['status'] == 'PENDING').toList();
    return _drivers;
  }

  @override
  Widget build(BuildContext context) {
    final online  = _drivers.where((d) => d['isOnline'] == true).length;
    final pending = _drivers.where((d) => d['status'] == 'PENDING').length;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: Row(children: [
          _MiniStat('${_drivers.length}', 'Total', Icons.badge_rounded,
              const [Color(0xFF0540F2), Color(0xFF2A6AFF)]),
          const SizedBox(width: 10),
          _MiniStat('$online', 'Online', Icons.radio_button_checked_rounded,
              const [Color(0xFF00B87C), Color(0xFF34D399)]),
          const SizedBox(width: 10),
          _MiniStat('$pending', 'Verifikasi', Icons.pending_rounded,
              pending > 0
                  ? const [Color(0xFFFF8C00), Color(0xFFFFB347)]
                  : const [Color(0xFF94A3B8), Color(0xFFCBD5E1)]),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((f) {
              final sel = _filter == f;
              return GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? _C.primary : _C.card,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: sel
                        ? [BoxShadow(color: _C.primary.withValues(alpha: 0.35),
                            blurRadius: 10, offset: const Offset(0, 3))]
                        : [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (f == 'Verifikasi' && pending > 0) ...[
                      Container(
                        width: 18, height: 18,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                            color: sel ? Colors.white : _C.orange,
                            shape: BoxShape.circle),
                        child: Center(child: Text('$pending',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 9, fontWeight: FontWeight.bold,
                                color: sel ? _C.orange : Colors.white))),
                      ),
                    ],
                    Text(f,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : _C.dark.withValues(alpha: 0.65))),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _C.primary))
            : RefreshIndicator(
                onRefresh: _load,
                color: _C.primary,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _DriverCard(
                    driver: _filtered[i],
                    onTap: () => Navigator.pushNamed(
                        context, '/admin/driver-detail',
                        arguments: _filtered[i]['id']?.toString() ?? ''),
                  ),
                ),
              ),
      ),
    ]);
  }
}

class _DriverCard extends StatelessWidget {
  final Map<String, dynamic> driver;
  final VoidCallback onTap;
  const _DriverCard({required this.driver, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name     = driver['driverName']?.toString() ?? '-';
    final plate    = driver['plate']?.toString() ?? '-';
    final online   = driver['isOnline'] as bool? ?? false;
    final rating   = (driver['rating'] as num?)?.toDouble() ?? 0.0;
    final trips    = driver['trips'] as int? ?? 0;
    final status   = driver['status']?.toString() ?? 'PENDING';
    final pending  = status == 'PENDING';
    final initials = name.trim().split(' ').take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 16, offset: const Offset(0, 4)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 3),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                    width: 4,
                    color: online ? _C.green : Colors.grey.shade300),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Stack(clipBehavior: Clip.none, children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: online
                                  ? [const Color(0xFF00B87C), const Color(0xFF2DD4A0)]
                                  : [const Color(0xFF94A3B8), const Color(0xFFCBD5E1)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(child: Text(initials,
                              style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white, fontWeight: FontWeight.bold,
                                  fontSize: 17))),
                        ),
                        Positioned(
                          bottom: 1, right: 1,
                          child: Container(
                            width: 14, height: 14,
                            decoration: BoxDecoration(
                              color: online ? _C.green : Colors.grey.shade400,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(children: [
                            Flexible(child: Text(name,
                                style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700, fontSize: 14.5,
                                    color: _C.dark),
                                overflow: TextOverflow.ellipsis)),
                            if (pending) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                    color: _C.orange.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6)),
                                child: Text('Pending',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9, fontWeight: FontWeight.bold,
                                        color: _C.orange)),
                              ),
                            ],
                          ]),
                          const SizedBox(height: 5),
                          Row(children: [
                            Icon(Icons.directions_bike_rounded,
                                size: 11, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Text(plate,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11, color: Colors.grey.shade500)),
                          ]),
                        ],
                      )),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(children: [
                            const Icon(Icons.star_rounded,
                                size: 14, color: Color(0xFFD97706)),
                            const SizedBox(width: 3),
                            Text(rating.toStringAsFixed(1),
                                style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800, fontSize: 14,
                                    color: _C.dark)),
                          ]),
                          const SizedBox(height: 6),
                          Text('$trips trip',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11, color: Colors.grey.shade500)),
                          const SizedBox(height: 6),
                          Icon(Icons.chevron_right_rounded,
                              size: 18, color: _C.primary.withValues(alpha: 0.5)),
                        ],
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TripsTab extends StatefulWidget {
  const _TripsTab();
  @override
  State<_TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends State<_TripsTab> {
  final _dio = ApiClient.create();
  bool _loading = true;
  List<Map<String, dynamic>> _trips = [];
  String _filter = 'Semua';
  final _filters = ['Semua', 'AKTIF', 'DONE', 'CANCELLED'];
  final _filterLabels = {
    'Semua': 'Semua', 'AKTIF': 'Aktif',
    'DONE': 'Selesai', 'CANCELLED': 'Dibatalkan'
  };
  static const _activeStatuses = {'SEARCHING', 'ACCEPTED', 'PICKUP', 'ONGOING'};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _dio.get('/admin/trips', queryParameters: {'limit': '100'});
      final list = (r.data['rides'] as List?) ?? [];
      setState(() {
        _trips = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() { _trips = []; _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'Semua') return _trips;
    if (_filter == 'AKTIF') return _trips.where((t) => _activeStatuses.contains(t['status'])).toList();
    return _trips.where((t) => t['status'] == _filter).toList();
  }

  Color _statusColor(String s) => switch (s) {
    'AKTIF'     => _C.primary,
    'ONGOING'   => _C.primary,
    'ACCEPTED'  => _C.green,
    'PICKUP'    => _C.green,
    'SEARCHING' => _C.orange,
    'DONE'      => _C.green,
    'CANCELLED' => _C.red,
    _           => _C.dark,
  };

  @override
  Widget build(BuildContext context) {
    final ongoing   = _trips.where((t) => _activeStatuses.contains(t['status'])).length;
    final done      = _trips.where((t) => t['status'] == 'DONE').length;
    final cancelled = _trips.where((t) => t['status'] == 'CANCELLED').length;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: Row(children: [
          _MiniStat('$ongoing',   'Berlangsung', Icons.electric_moped_rounded,
              const [Color(0xFF0540F2), Color(0xFF2A6AFF)]),
          const SizedBox(width: 10),
          _MiniStat('$done',      'Selesai',     Icons.check_circle_rounded,
              const [Color(0xFF00B87C), Color(0xFF34D399)]),
          const SizedBox(width: 10),
          _MiniStat('$cancelled', 'Dibatalkan',  Icons.cancel_rounded,
              const [Color(0xFFEF4444), Color(0xFFFF6B6B)]),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((f) {
              final sel = _filter == f;
              final sc  = _statusColor(f);
              return GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? sc : _C.card,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: sel
                        ? [BoxShadow(color: sc.withValues(alpha: 0.35),
                            blurRadius: 10, offset: const Offset(0, 3))]
                        : [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Text(_filterLabels[f] ?? f,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : _C.dark.withValues(alpha: 0.65))),
                ),
              );
            }).toList(),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _C.primary))
            : RefreshIndicator(
                onRefresh: _load,
                color: _C.primary,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _TripCard(trip: _filtered[i]),
                ),
              ),
      ),
    ]);
  }
}

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  const _TripCard({required this.trip});

  Color _statusColor(String s) => switch (s) {
    'ONGOING'   => _C.primary,
    'DONE'      => _C.green,
    'CANCELLED' => _C.red,
    _           => _C.dark,
  };

  String _statusLabel(String s) => switch (s) {
    'ONGOING'   => 'Berlangsung',
    'DONE'      => 'Selesai',
    'CANCELLED' => 'Dibatalkan',
    _           => s,
  };

  @override
  Widget build(BuildContext context) {
    final status = trip['status']?.toString() ?? '-';
    final sc     = _statusColor(status);
    final origin = trip['originAddress']?.toString() ?? '-';
    final dest   = trip['destinationAddress']?.toString() ?? '-';
    final pax    = trip['passengerName']?.toString() ?? '-';
    final drv    = trip['driverName']?.toString() ?? '-';
    final fare   = (trip['fare'] as num?)?.toDouble() ?? 0;
    final dist   = (trip['distanceKm'] as num?)?.toDouble() ?? 0;
    final date   = trip['createdAt']?.toString().substring(0, 10) ?? '-';

    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 16, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 3),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          Container(height: 3, color: sc),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: sc.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(_statusLabel(status),
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 10, fontWeight: FontWeight.w800, color: sc)),
                ),
                const Spacer(),
                if (fare > 0)
                  Text(_idr.format(fare),
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900, fontSize: 15,
                          color: _C.primary))
                else
                  Text('—',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, color: Colors.grey.shade400)),
              ]),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Column(children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                        color: _C.green.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: _C.green, width: 2)),
                  ),
                  Container(
                    width: 1.5, height: 18,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: Colors.grey.shade200,
                  ),
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                        color: _C.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: _C.primary, width: 2)),
                  ),
                ]),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(origin,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5, fontWeight: FontWeight.w600,
                            color: _C.dark),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    Text(dest,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5, fontWeight: FontWeight.w600,
                            color: _C.dark),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                )),
              ]),
              const SizedBox(height: 12),
              Container(height: 1, color: const Color(0xFFF0F4FF)),
              const SizedBox(height: 10),
              Row(children: [
                _InfoChip(Icons.person_rounded, pax),
                const SizedBox(width: 14),
                _InfoChip(Icons.electric_moped_rounded, drv),
                const Spacer(),
                if (dist > 0) ...[
                  Text('${dist.toStringAsFixed(1)} km',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500)),
                  Text('  ·  ', style: TextStyle(
                      color: Colors.grey.shade300, fontSize: 10)),
                ],
                Text(date,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10, color: Colors.grey.shade400)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Text(text,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: Colors.grey.shade600)),
      ]);
}

class _TariffTab extends StatefulWidget {
  const _TariffTab();
  @override
  State<_TariffTab> createState() => _TariffTabState();
}

class _TariffTabState extends State<_TariffTab> {
  final _dio = ApiClient.create();
  bool _loading = true;
  bool _saving  = false;

  late TextEditingController _baseCtrl;
  late TextEditingController _perKmCtrl;

  Map<String, dynamic> _tariff = {};

  @override
  void initState() {
    super.initState();
    _baseCtrl  = TextEditingController();
    _perKmCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _baseCtrl.dispose();
    _perKmCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _dio.get('/admin/tariff');
      _tariff = Map<String, dynamic>.from(r.data as Map);
    } catch (_) {}
    _baseCtrl.text  = '${_tariff['basePrice'] ?? 14000}';
    _perKmCtrl.text = '${_tariff['pricePerKm'] ?? 2100}';
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final base  = int.tryParse(_baseCtrl.text.trim());
    final perKm = int.tryParse(_perKmCtrl.text.trim());
    if (base == null || perKm == null) return;

    setState(() => _saving = true);
    try {
      final r = await _dio.patch('/admin/tariff',
          data: {'basePrice': base, 'pricePerKm': perKm});
      setState(() {
        _tariff = Map<String, dynamic>.from(r.data as Map);
        _saving = false;
      });
    } catch (_) {
      setState(() => _saving = false);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Tarif berhasil diperbarui',
            style: GoogleFonts.plusJakartaSans(color: Colors.white)),
        backgroundColor: _C.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _C.primary));
    final history = (_tariff['history'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final base  = (_tariff['basePrice']  as num?)?.toDouble() ?? 14000;
    final perKm = (_tariff['pricePerKm'] as num?)?.toDouble() ?? 2100;
    final perMin = (_tariff['pricePerMinute'] as num?)?.toDouble() ?? 500;
    final example5km = base + (perKm * 5 - base).clamp(0, double.infinity);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionTitle('Tarif Saat Ini'),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _TariffCard(
            label: 'Tarif Awal',
            value: _idr.format(base),
            sub: 'Tarif minimum',
            icon: Icons.payments_rounded,
            grad: const [Color(0xFF0540F2), Color(0xFF2A6AFF)],
          )),
          const SizedBox(width: 12),
          Expanded(child: _TariffCard(
            label: 'Per Kilometer',
            value: '${_idr.format(perKm)}/km',
            sub: 'Biaya jarak',
            icon: Icons.route_rounded,
            grad: const [Color(0xFF7C3AED), Color(0xFFA78BFA)],
          )),
        ]),
        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [_C.green, const Color(0xFF2DD4A0)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(
                color: _C.green.withValues(alpha: 0.3),
                blurRadius: 14, offset: const Offset(0, 5))],
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.calculate_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Estimasi 5 km',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
              Text(_idr.format(example5km),
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Per menit',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.7), fontSize: 10)),
              Text('${_idr.format(perMin)}/min',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ]),
          ]),
        ),
        const SizedBox(height: 26),

        _SectionTitle('Update Tarif'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 16, offset: const Offset(0, 4)),
              BoxShadow(color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 3),
            ],
          ),
          child: Column(children: [
            _TariffField(
                controller: _baseCtrl, label: 'Tarif Awal (Rp)',
                icon: Icons.payments_rounded, color: _C.primary),
            const SizedBox(height: 14),
            _TariffField(
                controller: _perKmCtrl, label: 'Per Kilometer (Rp/km)',
                icon: Icons.route_rounded, color: _C.purple),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.primary,
                  disabledBackgroundColor: _C.primary.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: _C.primary.withValues(alpha: 0.3),
                ),
                icon: _saving
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded,
                        color: Colors.white, size: 18),
                label: Text(_saving ? 'Menyimpan...' : 'Simpan Tarif',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 26),

        if (history.isNotEmpty) ...[
          _SectionTitle('Riwayat Perubahan'),
          const SizedBox(height: 14),
          ...history.map((h) => _HistoryRow(
              date: h['date']?.toString() ?? '-',
              change: h['change']?.toString() ?? '-')),
        ],
      ]),
    );
  }
}

class _TariffCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final List<Color> grad;
  const _TariffCard({required this.label, required this.value, required this.sub,
      required this.icon, required this.grad});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
              color: grad[0].withValues(alpha: 0.3),
              blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11, fontWeight: FontWeight.w600)),
          Text(sub,
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withValues(alpha: 0.55), fontSize: 10)),
        ]),
      );
}

class _TariffField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color color;
  const _TariffField({required this.controller, required this.label,
      required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: color),
          prefixIcon: Icon(icon, color: color, size: 20),
          filled: true,
          fillColor: color.withValues(alpha: 0.04),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: color.withValues(alpha: 0.3))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: color.withValues(alpha: 0.18))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: color, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
}

class _HistoryRow extends StatelessWidget {
  final String date, change;
  const _HistoryRow({required this.date, required this.change});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: _C.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.history_rounded, size: 18, color: _C.primary),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(change,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: _C.dark))),
          const SizedBox(width: 8),
          Text(date,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 10, color: Colors.grey.shade400)),
        ]),
      );
}

class _MiniStat extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final List<Color> grad;
  const _MiniStat(this.value, this.label, this.icon, this.grad);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          height: 110,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: grad,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: grad[0].withValues(alpha: 0.38),
                  blurRadius: 16, offset: const Offset(0, 7)),
              BoxShadow(
                  color: grad[0].withValues(alpha: 0.15),
                  blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Stack(
            children: [

              Positioned(
                right: -14, bottom: -14,
                child: Container(
                  width: 76, height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                right: 24, top: -16,
                child: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(icon, color: Colors.white, size: 19),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(value,
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 26,
                                height: 1)),
                        const SizedBox(height: 3),
                        Text(label,
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 4, height: 18,
          decoration: BoxDecoration(
              color: _C.primary, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(text,
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800, fontSize: 16, color: _C.dark)),
      ]);
}
