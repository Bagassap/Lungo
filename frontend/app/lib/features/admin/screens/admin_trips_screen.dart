import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/api_client.dart';

class AdminTripsScreen extends StatefulWidget {
  const AdminTripsScreen({super.key});

  @override
  State<AdminTripsScreen> createState() => _AdminTripsScreenState();
}

class _AdminTripsScreenState extends State<AdminTripsScreen>
    with SingleTickerProviderStateMixin {
  static const _darkest = Color(0xFF0B0940);
  static const _dark    = Color(0xFF04198C);
  static const _primary = Color(0xFF0540F2);
  static const _bg      = Color(0xFFF0F4FF);

  late final TabController _tab;
  final _statuses = ['ALL', 'ONGOING', 'DONE', 'CANCELLED'];
  final _labels   = ['Semua', 'Aktif', 'Selesai', 'Dibatalkan'];

  List<Map<String, dynamic>> _trips = [];
  bool _loading = true;
  int  _total   = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _statuses.length, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final status = _statuses[_tab.index];
      final resp = await ApiClient.create().get('/admin/trips',
          queryParameters: {'status': status, 'page': 1, 'limit': 50});
      final d = resp.data as Map<String, dynamic>;
      setState(() {
        _trips = List<Map<String, dynamic>>.from(d['rides'] as List);
        _total = (d['total'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat data perjalanan')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _rupiah(num v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    int cnt = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (cnt > 0 && cnt % 3 == 0) buf.write('.');
      buf.write(s[i]);
      cnt++;
    }
    return 'Rp ${buf.toString().split('').reversed.join()}';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: Column(
          children: [
            _buildHeader(),
            _buildTabs(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_darkest, _dark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('Riwayat Trip',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white, fontWeight: FontWeight.w700,
                        fontSize: 18)),
                    Text('$_total perjalanan',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: _dark,
      child: TabBar(
        controller: _tab,
        indicatorColor: const Color(0xFFF2CB05),
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
        labelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 12),
        tabs: _labels.map((l) => Tab(text: l)).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    if (_trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.route_rounded,
                size: 64, color: Color(0xFFB0BFDF)),
            const SizedBox(height: 12),
            Text('Tidak ada perjalanan pada kategori ini',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF7B8FC0), fontSize: 15)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: _primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _trips.length,
        itemBuilder: (_, i) => _TripCard(trip: _trips[i], rupiah: _rupiah),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  static const _shadow = Color(0x180540F2);

  final Map<String, dynamic> trip;
  final String Function(num) rupiah;
  const _TripCard({required this.trip, required this.rupiah});

  @override
  Widget build(BuildContext context) {
    final passenger = trip['passengerName'] as String? ?? '-';
    final driver    = trip['driverName']    as String? ?? '-';
    final status    = (trip['status']       as String? ?? '').toUpperCase();
    final fare      = (trip['fare']         as num?) ?? 0;
    final distKm    = (trip['distanceKm']   as num?)?.toDouble() ?? 0.0;
    final createdAt = (trip['createdAt']    as String? ?? '').substring(0, 10);

    final (statusColor, statusBg, statusLabel) = switch (status) {
      'DONE'      => (const Color(0xFF059669), const Color(0xFFDCFCE7), 'Selesai'),
      'ONGOING'   => (const Color(0xFF0540F2), const Color(0xFFE0E8FF), 'Berlangsung'),
      'CANCELLED' => (const Color(0xFFEF4444), const Color(0xFFFFEDE8), 'Dibatalkan'),
      _           => (const Color(0xFFD97706), const Color(0xFFFEF3C7), 'Menunggu'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: _shadow, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(passenger,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700, fontSize: 14,
                          color: const Color(0xFF0D1240))),
                      Text('Driver: $driver',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: const Color(0xFF9AAAD0))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(statusLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFEEF1FF)),
            const SizedBox(height: 10),
            Row(
              children: [
                _InfoChip(Icons.route_rounded, '${distKm.toStringAsFixed(1)} km'),
                const SizedBox(width: 12),
                _InfoChip(Icons.payments_outlined, rupiah(fare)),
                const Spacer(),
                Text(createdAt,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: const Color(0xFFB0BFDF))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: const Color(0xFF9AAAD0)),
      const SizedBox(width: 4),
      Text(text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: const Color(0xFF0D1240))),
    ],
  );
}
