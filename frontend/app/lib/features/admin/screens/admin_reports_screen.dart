import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final _dio = ApiClient.create();
  final _idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  int _page = 1;
  int _total = 0;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) _page = 1;
    setState(() => _loading = true);
    try {
      final r = await _dio.get('/admin/reports/weekly?page=$_page&limit=20');
      final data = Map<String, dynamic>.from(r.data as Map);
      final list = (data['reports'] as List?) ?? [];
      setState(() {
        _reports = reset
            ? list.map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : [..._reports, ...list.map((e) => Map<String, dynamic>.from(e as Map))];
        _total   = (data['total'] as int?) ?? 0;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _generateReports() async {
    setState(() => _generating = true);
    try {
      await _dio.post('/admin/reports/generate');
      await _load(reset: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Laporan mingguan berhasil dibuat'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: _generating
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded, color: Colors.white),
                tooltip: 'Generate laporan minggu ini',
                onPressed: _generating ? null : _generateReports,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0540F2), Color(0xFF04198C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Laporan Mingguan',
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22)),
                        Text('$_total laporan tersimpan',
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_loading && _reports.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: AppColors.primaryColor)),
            )
          else if (_reports.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.description_outlined,
                      size: 56, color: AppColors.primaryLight),
                  const SizedBox(height: 12),
                  Text('Belum ada laporan',
                      style: GoogleFonts.plusJakartaSans(
                          color: AppColors.textSecondary, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _generateReports,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Buat Laporan Minggu Ini'),
                  ),
                ]),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    if (i == _reports.length) {
                      return _reports.length < _total
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: TextButton(
                                  onPressed: () {
                                    _page++;
                                    _load();
                                  },
                                  child: const Text('Muat lebih banyak'),
                                ),
                              ),
                            )
                          : const SizedBox(height: 24);
                    }
                    return _ReportCard(report: _reports[i], idr: _idr);
                  },
                  childCount: _reports.length + 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final NumberFormat idr;
  const _ReportCard({required this.report, required this.idr});

  @override
  Widget build(BuildContext context) {
    final driverName  = report['driverName']?.toString() ?? 'Driver';
    final weekStart   = report['weekStart']?.toString().substring(0, 10) ?? '-';
    final weekEnd     = report['weekEnd']?.toString().substring(0, 10) ?? '-';
    final completed   = report['completedRides'] as int? ?? 0;
    final cancelled   = report['cancelledRides'] as int? ?? 0;
    final total       = report['totalRides'] as int? ?? 0;
    final earnings    = (report['totalEarnings'] as num?)?.toDouble() ?? 0;
    final rating      = (report['avgRating'] as num?)?.toDouble();
    final distanceKm  = (report['totalDistanceKm'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    driverName.isNotEmpty ? driverName[0].toUpperCase() : 'D',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryColor,
                        fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(driverName,
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold, fontSize: 15,
                          color: AppColors.primaryDark)),
                  Text('$weekStart  →  $weekEnd',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: AppColors.textSecondary)),
                ]),
              ),
              if (rating != null)
                Row(children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 16),
                  const SizedBox(width: 3),
                  Text(rating.toStringAsFixed(1),
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold, fontSize: 14,
                          color: const Color(0xFFD97706))),
                ]),
            ]),

            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFEEF1FF)),
            const SizedBox(height: 14),

            Row(children: [
              _Metric(label: 'Trip', value: '$total'),
              _Metric(label: 'Selesai', value: '$completed', color: const Color(0xFF059669)),
              _Metric(label: 'Batal', value: '$cancelled', color: const Color(0xFFDC2626)),
              _Metric(label: 'Jarak', value: '${distanceKm.toStringAsFixed(1)} km'),
            ]),

            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0540F2), Color(0xFF056CF2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Pendapatan',
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70, fontSize: 12)),
                  Text(idr.format(earnings),
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _Metric({required this.label, required this.value, this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold, fontSize: 16,
                  color: color ?? AppColors.primaryColor)),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, color: AppColors.textSecondary)),
        ]),
      );
}
