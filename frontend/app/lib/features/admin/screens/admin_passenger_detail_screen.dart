import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class AdminPassengerDetailScreen extends StatefulWidget {
  final String userId;
  const AdminPassengerDetailScreen({super.key, required this.userId});

  @override
  State<AdminPassengerDetailScreen> createState() =>
      _AdminPassengerDetailScreenState();
}

class _AdminPassengerDetailScreenState extends State<AdminPassengerDetailScreen> {
  final _dio = ApiClient.create();
  final _idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _dio.get('/admin/users/${widget.userId}/detail');
      setState(() {
        _data = Map<String, dynamic>.from(r.data as Map);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryColor))
          : _error != null
              ? Center(child: Text(_error!,
                    style: GoogleFonts.plusJakartaSans(color: Colors.red)))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final user    = Map<String, dynamic>.from((_data['user']   as Map?) ?? {});
    final stats   = Map<String, dynamic>.from((_data['stats']  as Map?) ?? {});
    final name    = user['name']?.toString() ?? 'Penumpang';
    final phone   = user['phone']?.toString() ?? '-';
    final joined  = user['createdAt']?.toString().substring(0, 10) ?? '-';
    final active  = user['isVerified'] as bool? ?? false;
    final initials = name.trim().split(' ').take(2)
        .map((w) => w[0].toUpperCase()).join();

    final total     = stats['totalRides']     as int? ?? 0;
    final completed = stats['completedRides'] as int? ?? 0;
    final cancelled = stats['cancelledRides'] as int? ?? 0;
    final spent     = (stats['totalSpent'] as num?)?.toDouble() ?? 0;
    final rides     = (_data['recentRides'] as List?) ?? [];

    return Column(children: [
      _buildHeader(name, phone, initials, active, joined),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primaryColor,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12, mainAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: [
                  _StatCard(label: 'Total Trip',  value: '$total',
                      icon: Icons.route_rounded,
                      grad: const [Color(0xFF0540F2), Color(0xFF2A6AFF)]),
                  _StatCard(label: 'Selesai', value: '$completed',
                      icon: Icons.check_circle_rounded,
                      grad: const [Color(0xFF059669), Color(0xFF34D399)]),
                  _StatCard(label: 'Dibatalkan', value: '$cancelled',
                      icon: Icons.cancel_rounded,
                      grad: const [Color(0xFFDC2626), Color(0xFFF87171)]),
                  _StatCard(label: 'Total Pengeluaran', value: _idr.format(spent),
                      icon: Icons.payments_rounded,
                      grad: const [Color(0xFF7C3AED), Color(0xFFA78BFA)]),
                ],
              ),
              const SizedBox(height: 20),

              _InfoCard(title: 'Informasi Akun', children: [
                _InfoRow(label: 'Nama',     value: name),
                _InfoRow(label: 'Telepon',  value: phone),
                _InfoRow(label: 'Bergabung', value: joined),
                _InfoRow(label: 'Status',   value: active ? 'Aktif' : 'Nonaktif'),
              ]),
              const SizedBox(height: 20),

              if (rides.isNotEmpty) ...[
                Text('Riwayat Trip',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold, fontSize: 15,
                        color: AppColors.primaryDark)),
                const SizedBox(height: 12),
                ...rides.map((raw) {
                  final r      = Map<String, dynamic>.from(raw as Map);
                  final fare   = (r['fare'] as num?)?.toDouble() ?? 0;
                  final dist   = (r['distanceKm'] as num?)?.toDouble() ?? 0;
                  final status = r['status']?.toString() ?? '-';
                  final date   = r['createdAt']?.toString().substring(0, 10) ?? '-';
                  final dest   = r['destinationAddress']?.toString() ?? 'Tujuan';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(
                          color: AppColors.primaryColor.withValues(alpha: 0.06),
                          blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _rideColor(status).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.place_rounded,
                            color: _rideColor(status), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(dest,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: AppColors.primaryDark),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${dist.toStringAsFixed(1)} km  •  $date',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 11, color: AppColors.textSecondary)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(_idr.format(fare),
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold, fontSize: 13,
                                color: AppColors.primaryColor)),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: _rideColor(status).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(status,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9, fontWeight: FontWeight.bold,
                                  color: _rideColor(status))),
                        ),
                      ]),
                    ]),
                  );
                }),
              ] else
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Center(
                    child: Text('Belum ada riwayat trip',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ),
                ),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _buildHeader(String name, String phone, String initials,
      bool active, String joined) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B0E6E), Color(0xFF0540F2), Color(0xFF056CF2)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
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
            width: 68, height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
            ),
            child: Center(
              child: Text(initials,
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
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
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _Badge(
              label: active ? 'AKTIF' : 'NONAKTIF',
              color: active ? const Color(0xFF059669) : Colors.grey,
            ),
            const SizedBox(width: 8),
            _Badge(label: 'Bergabung $joined', color: const Color(0xFF7C3AED)),
          ]),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Color _rideColor(String s) => switch (s) {
    'DONE'      => const Color(0xFF059669),
    'CANCELLED' => const Color(0xFFDC2626),
    'ONGOING'   => AppColors.primaryColor,
    _           => AppColors.textSecondary,
  };
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
  const _StatCard({required this.label, required this.value,
      required this.icon, required this.grad});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: grad,
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: grad[0].withValues(alpha: 0.30),
              blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10, color: Colors.white.withValues(alpha: 0.8)),
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
          boxShadow: [BoxShadow(
              color: AppColors.primaryColor.withValues(alpha: 0.07),
              blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold, fontSize: 14,
                  color: AppColors.primaryColor)),
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
          SizedBox(
            width: 100,
            child: Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark)),
          ),
        ]),
      );
}
