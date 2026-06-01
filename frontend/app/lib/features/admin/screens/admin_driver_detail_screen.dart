import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class AdminDriverDetailScreen extends StatefulWidget {
  final String driverId;
  const AdminDriverDetailScreen({super.key, required this.driverId});

  @override
  State<AdminDriverDetailScreen> createState() =>
      _AdminDriverDetailScreenState();
}

class _AdminDriverDetailScreenState extends State<AdminDriverDetailScreen>
    with SingleTickerProviderStateMixin {
  final _dio = ApiClient.create();
  final _idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};

  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _dio.get('/admin/drivers/${widget.driverId}/report');
      setState(() { _data = Map<String, dynamic>.from(r.data as Map); _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _toggleVerify(bool approve) async {
    final driver = _data['driver'] as Map<String, dynamic>?;
    if (driver == null) return;

    if (widget.driverId.startsWith('demo-')) {
      setState(() {
        (_data['driver'] as Map<String, dynamic>)['registrationStatus'] =
            approve ? 'APPROVED' : 'REJECTED';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(approve ? 'Driver diverifikasi (demo)' : 'Driver ditolak (demo)'),
          backgroundColor: approve ? AppColors.primaryColor : Colors.red,
        ));
      }
      return;
    }
    try {
      await _dio.patch('/admin/drivers/${driver['id']}/verify',
          data: {'approved': approve});
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(approve ? 'Driver diverifikasi' : 'Driver ditolak'),
          backgroundColor: approve ? AppColors.primaryColor : Colors.red,
        ));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryColor))
          : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.plusJakartaSans(color: Colors.red)))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final user     = Map<String, dynamic>.from((_data['user']   as Map?) ?? {});
    final driver   = Map<String, dynamic>.from((_data['driver'] as Map?) ?? {});
    final stats    = Map<String, dynamic>.from((_data['stats']  as Map?) ?? {});
    final name     = user['name']?.toString() ?? 'Driver';
    final phone    = user['phone']?.toString() ?? '-';
    final status   = driver['registrationStatus']?.toString() ?? 'PENDING';
    final isOnline = driver['isOnline'] == true;
    final rating   = (driver['rating'] as num?)?.toDouble() ?? 0.0;
    final initials = name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join();

    return Column(
      children: [

        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0B0E6E), Color(0xFF0540F2), Color(0xFF056CF2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [

                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                      onPressed: _load,
                    ),
                  ]),
                ),

                Container(
                  width: 76, height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2.5),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Center(
                    child: Text(initials,
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26)),
                  ),
                ),
                const SizedBox(height: 10),
                Text(name,
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19)),
                const SizedBox(height: 3),
                Text(phone,
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withValues(alpha: 0.65), fontSize: 13)),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Badge(label: status, color: _statusColor(status)),
                    const SizedBox(width: 8),
                    _Badge(
                      label: isOnline ? 'ONLINE' : 'OFFLINE',
                      color: isOnline ? const Color(0xFF059669) : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    _Badge(label: '★  $rating', color: const Color(0xFFD97706)),
                  ],
                ),
                const SizedBox(height: 16),

                TabBar(
                  controller: _tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: const Color(0xFFF2CB05),
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 13),
                  tabs: const [
                    Tab(text: 'Statistik'),
                    Tab(text: 'Dokumen'),
                    Tab(text: 'Laporan'),
                    Tab(text: 'Trip'),
                  ],
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildStatsTab(stats, driver, status),
              _buildDocsTab(driver),
              _buildReportsTab(),
              _buildTripsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsTab(
      Map<String, dynamic> stats, Map<String, dynamic> driver, String status) {
    final total     = stats['totalRides'] as int? ?? 0;
    final completed = stats['completedRides'] as int? ?? 0;
    final cancelled = stats['cancelledRides'] as int? ?? 0;
    final earnings  = (stats['totalEarnings'] as num?)?.toDouble() ?? 0;
    final plate     = driver['vehiclePlate']?.toString() ?? '-';
    final type      = driver['vehicleType']?.toString() ?? '-';

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primaryColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12, mainAxisSpacing: 12,
            childAspectRatio: 1.45,
            children: [
              _StatCard(label: 'Total Trip', value: '$total',
                  icon: Icons.route_rounded,
                  grad: const [Color(0xFF0540F2), Color(0xFF2A6AFF)]),
              _StatCard(label: 'Selesai', value: '$completed',
                  icon: Icons.check_circle_rounded,
                  grad: const [Color(0xFF059669), Color(0xFF34D399)]),
              _StatCard(label: 'Dibatalkan', value: '$cancelled',
                  icon: Icons.cancel_rounded,
                  grad: const [Color(0xFFDC2626), Color(0xFFF87171)]),
              _StatCard(label: 'Pendapatan', value: _idr.format(earnings),
                  icon: Icons.payments_rounded,
                  grad: const [Color(0xFF7C3AED), Color(0xFFA78BFA)]),
            ],
          ),
          const SizedBox(height: 20),

          _InfoCard(title: 'Data Kendaraan', children: [
            _InfoRow(label: 'Jenis', value: type),
            _InfoRow(label: 'Plat Nomor', value: plate),
            _InfoRow(
              label: 'Dokumen',
              value: driver['ktpPhotoUrl'] != null ? 'Lengkap' : 'Belum lengkap',
            ),
          ]),
          const SizedBox(height: 16),

          if (status == 'PENDING' || status == 'PAYMENT_PENDING') ...[
            _InfoCard(title: 'Informasi Pendaftaran', children: [
              _InfoRow(label: 'Tempat Lahir', value: driver['birthPlace']?.toString() ?? '-'),
              _InfoRow(label: 'Tanggal Lahir', value: driver['birthDate']?.toString().substring(0, 10) ?? '-'),
              _InfoRow(label: 'Alamat', value: driver['address']?.toString() ?? '-'),
            ]),
            const SizedBox(height: 16),
            _InfoCard(title: 'Verifikasi Driver', children: [
              Text(
                status == 'PAYMENT_PENDING'
                    ? 'Driver telah submit dokumen. Periksa tab Dokumen sebelum menyetujui.'
                    : 'Driver ini menunggu pengisian dokumen pendaftaran.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _toggleVerify(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                    label: Text('Setujui',
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _toggleVerify(false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFDC2626)),
                    label: Text('Tolak',
                        style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildDocsTab(Map<String, dynamic> driver) {
    final docLabels = ['KTP', 'SIM', 'BPKB', 'STNK'];
    final docUrls = [
      driver['ktpPhotoUrl']  as String?,
      driver['simPhotoUrl']  as String?,
      driver['bpkbPhotoUrl'] as String?,
      driver['stnkPhotoUrl'] as String?,
    ];
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      itemCount: 4,
      itemBuilder: (_, i) {
        final label = docLabels[i];
        final url   = docUrls[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primaryColor.withValues(alpha: 0.07),
                  blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(label,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, fontWeight: FontWeight.bold,
                            color: AppColors.primaryColor)),
                  ),
                  const Spacer(),
                  Icon(
                    url != null ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 16,
                    color: url != null ? const Color(0xFF059669) : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 4),
                  Text(url != null ? 'Tersedia' : 'Belum diupload',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: url != null ? const Color(0xFF059669) : Colors.grey)),
                ]),
              ),
              if (url != null)
                GestureDetector(
                  onTap: () => _showFullImage(url, label),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                    child: Image.network(
                      url,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : Container(
                              height: 200,
                              color: const Color(0xFFF0F4FF),
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded /
                                          progress.expectedTotalBytes!
                                      : null,
                                  color: AppColors.primaryColor,
                                ),
                              ),
                            ),
                      errorBuilder: (_, _, _) => Container(
                        height: 120,
                        color: const Color(0xFFF0F4FF),
                        child: Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.broken_image_rounded,
                                size: 36, color: Colors.grey.shade400),
                            const SizedBox(height: 6),
                            Text('Gagal memuat gambar',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12, color: Colors.grey)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: 80,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFF),
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(
                    child: Text('Dokumen belum diupload',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, color: Colors.grey.shade400)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showFullImage(String url, String label) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain,
                width: double.infinity, height: double.infinity),
          ),
          Positioned(
            top: 40, left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
          Positioned(
            top: 40, left: 0, right: 0,
            child: Center(
              child: Text(label,
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildReportsTab() {
    final reports = (_data['weeklyReports'] as List?) ?? [];
    if (reports.isEmpty) {
      return Center(
        child: Text('Belum ada laporan mingguan',
            style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final r = Map<String, dynamic>.from(reports[i] as Map);
        final weekStart = r['weekStart']?.toString().substring(0, 10) ?? '-';
        final weekEnd   = r['weekEnd']?.toString().substring(0, 10) ?? '-';
        final rides     = r['completedRides'] as int? ?? 0;
        final earnings  = (r['totalEarnings'] as num?)?.toDouble() ?? 0;
        final rating    = (r['avgRating'] as num?)?.toDouble();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: AppColors.primaryColor.withValues(alpha: 0.07),
                  blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                  child: Text('$weekStart → $weekEnd',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: AppColors.primaryColor)),
                ),
                const Spacer(),
                if (rating != null)
                  Text('★ $rating',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, fontWeight: FontWeight.bold,
                          color: const Color(0xFFD97706))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _MiniStat(label: 'Trip', value: '$rides'),
                _MiniStat(label: 'Pendapatan', value: _idr.format(earnings)),
                _MiniStat(
                    label: 'Dibatalkan',
                    value: '${r['cancelledRides'] ?? 0}'),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTripsTab() {
    final rides = (_data['recentRides'] as List?) ?? [];
    if (rides.isEmpty) {
      return Center(
        child: Text('Belum ada trip',
            style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rides.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r     = Map<String, dynamic>.from(rides[i] as Map);
        final fare  = (r['fare'] as num?)?.toDouble() ?? 0;
        final dist  = (r['distanceKm'] as num?)?.toDouble() ?? 0;
        final status = r['status']?.toString() ?? '-';
        final date  = r['createdAt']?.toString().substring(0, 10) ?? '-';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: AppColors.primaryColor.withValues(alpha: 0.06),
                  blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _rideStatusColor(status).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.route_rounded, color: _rideStatusColor(status), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r['originAddress']?.toString() ?? 'Asal tidak diketahui',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppColors.primaryColor),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${dist.toStringAsFixed(1)} km  •  $date',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_idr.format(fare),
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold, fontSize: 13,
                      color: AppColors.primaryColor)),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: _rideStatusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(status,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10, fontWeight: FontWeight.bold,
                        color: _rideStatusColor(status))),
              ),
            ]),
          ]),
        );
      },
    );
  }

  Color _statusColor(String s) {
    return switch (s) {
      'APPROVED' => const Color(0xFF059669),
      'REJECTED' => const Color(0xFFDC2626),
      _ => const Color(0xFFD97706),
    };
  }

  Color _rideStatusColor(String s) {
    return switch (s) {
      'DONE'      => const Color(0xFF059669),
      'CANCELLED' => const Color(0xFFDC2626),
      'ONGOING'   => AppColors.primaryColor,
      _ => AppColors.textSecondary,
    };
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(label,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
      );
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final List<Color> grad;
  const _StatCard({required this.label, required this.value, required this.icon, required this.grad});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
              color: grad[0].withValues(alpha: 0.30),
              blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900, fontSize: 17, color: Colors.white),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
                maxLines: 1),
          ]),
        ]),
      );
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.primaryColor.withValues(alpha: 0.07), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryColor)),
          const SizedBox(height: 12),
          ...children,
        ]),
      );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          SizedBox(width: 110,
              child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary))),
          Expanded(child: Text(value,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryDark))),
        ]),
      );
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryColor)),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
        ]),
      );
}
