import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/api_client.dart';
import 'admin_driver_detail_screen.dart';

class AdminDriversScreen extends StatefulWidget {
  const AdminDriversScreen({super.key});

  @override
  State<AdminDriversScreen> createState() => _AdminDriversScreenState();
}

class _AdminDriversScreenState extends State<AdminDriversScreen>
    with SingleTickerProviderStateMixin {
  static const _darkest = Color(0xFF0B0940);
  static const _dark    = Color(0xFF04198C);
  static const _primary = Color(0xFF0540F2);
  static const _bg      = Color(0xFFF0F4FF);

  late final TabController _tab;
  final _filters = ['all', 'pending', 'verified', 'online'];
  final _labels  = ['Semua', 'Menunggu', 'Disetujui', 'Online'];

  List<Map<String, dynamic>> _drivers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _filters.length, vsync: this);
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
      final filter = _filters[_tab.index];
      final resp = await ApiClient.create().get('/admin/drivers',
          queryParameters: {'filter': filter});
      setState(() {
        _drivers = List<Map<String, dynamic>>.from(resp.data as List);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat data driver')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify(String id, bool approve) async {
    try {
      await ApiClient.create().patch('/admin/drivers/$id/verify',
          data: {'approved': approve});
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(approve ? 'Driver berhasil disetujui' : 'Driver ditolak'),
          backgroundColor: approve
              ? const Color(0xFF059669)
              : const Color(0xFFEF4444),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memperbarui status driver')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: Column(
          children: [

            _buildHeaderWithTabs(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderWithTabs() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_darkest, _dark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Color(0x380B0940), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
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
                        Text('Verifikasi Driver',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18)),
                        Text('${_drivers.length} driver',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withValues(alpha: 0.6),
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
            TabBar(
              controller: _tab,
              indicatorColor: const Color(0xFFF2CB05),
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.45),
              labelStyle: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700, fontSize: 12),
              unselectedLabelStyle:
                  GoogleFonts.plusJakartaSans(fontSize: 12),
              dividerColor: Colors.transparent,
              tabs: _labels.map((l) => Tab(text: l)).toList(),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _primary));
    }
    if (_drivers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.electric_moped_rounded,
                size: 64, color: Color(0xFFB0BFDF)),
            const SizedBox(height: 12),
            Text('Tidak ada driver pada kategori ini',
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
        itemCount: _drivers.length,
        itemBuilder: (_, i) => _DriverCard(
          driver: _drivers[i],
          onVerify: _verify,
          onDetail: (userId) => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => AdminDriverDetailScreen(driverId: userId)),
          ),
        ),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  static const _shadow  = Color(0x180540F2);
  static const _primary = Color(0xFF0540F2);

  final Map<String, dynamic> driver;
  final void Function(String driverEntityId, bool approve) onVerify;
  final void Function(String userId) onDetail;

  const _DriverCard({
    required this.driver,
    required this.onVerify,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {

    final driverEntityId = driver['id'] as String? ?? '';
    final userId   = driver['userId'] as String? ?? driverEntityId;
    final user     = driver['user'] as Map<String, dynamic>?;
    final name     = user?['name'] as String? ?? '-';
    final phone    = user?['phone'] as String? ?? '-';
    final status   = (driver['registrationStatus'] as String? ?? 'PENDING').toUpperCase();
    final rating   = (driver['rating'] as num?)?.toDouble() ?? 5.0;
    final rides    = (driver['totalRides'] as num?)?.toInt() ?? 0;
    final isOnline = driver['isOnline'] as bool? ?? false;
    final plate    = driver['vehiclePlate'] as String?;

    final (statusColor, statusBg, statusLabel) = switch (status) {
      'APPROVED' => (const Color(0xFF059669), const Color(0xFFDCFCE7), 'Disetujui'),
      'REJECTED' => (const Color(0xFFEF4444), const Color(0xFFFFEDE8), 'Ditolak'),
      _          => (const Color(0xFFD97706), const Color(0xFFFEF3C7), 'Menunggu'),
    };

    final initials = name.trim().split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: _shadow, blurRadius: 10, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(
              children: [

                Stack(
                  children: [
                    Container(
                      width: 50, height: 50,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0540F2), Color(0xFF2A6AFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(initials.isEmpty ? '?' : initials,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17)),
                      ),
                    ),
                    if (isOnline)
                      Positioned(
                        right: 1, bottom: 1,
                        child: Container(
                          width: 14, height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isEmpty ? '(Belum ada nama)' : name,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700, fontSize: 14,
                          color: const Color(0xFF0D1240))),
                      Text(phone,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: const Color(0xFF9AAAD0))),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _Chip(statusLabel, statusColor, statusBg),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Color(0xFFD97706), size: 13),
                              const SizedBox(width: 2),
                              Text(rating.toStringAsFixed(1),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: const Color(0xFFD97706))),
                              const SizedBox(width: 6),
                              Text('$rides trip',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFF9AAAD0))),
                            ],
                          ),
                          if (plate != null && plate.isNotEmpty)
                            _Chip(plate, _primary, const Color(0xFFE0E8FF)),
                        ],
                      ),
                    ],
                  ),
                ),

                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E8FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    onPressed: () => onDetail(userId),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.open_in_new_rounded,
                        size: 17, color: _primary),
                    tooltip: 'Detail',
                  ),
                ),
              ],
            ),
          ),

          if (status == 'PENDING')
            Container(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onVerify(driverEntityId, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: Text('Tolak',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => onVerify(driverEntityId, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: Text('Setujui',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700, fontSize: 13)),
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

class _Chip extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color bgColor;
  const _Chip(this.label, this.textColor, this.bgColor);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: bgColor, borderRadius: BorderRadius.circular(8)),
    child: Text(label,
      style: GoogleFonts.plusJakartaSans(
          fontSize: 10, fontWeight: FontWeight.w700, color: textColor)),
  );
}
