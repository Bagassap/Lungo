import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});
  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  bool _loading = true;
  int _totalUsers = 0;
  int _totalDrivers = 0;
  int _tripsToday = 0;
  double _revenueToday = 0;
  List<Map<String, dynamic>> _onlineDrivers = [];
  List<Map<String, dynamic>> _activeTrips = [];

  final _currency = NumberFormat.currency(
      locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final dio = ApiClient.create();
      final nearbyResp = await dio
          .get('/tracking/drivers/nearby?lat=-6.9175&lng=107.6191&radius=50');
      final drivers =
          (nearbyResp.data as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (mounted) {
        setState(() {

          _totalUsers = 128;
          _totalDrivers = 24;
          _tripsToday = 37;
          _revenueToday = 629000;
          _onlineDrivers = drivers.isNotEmpty
              ? drivers
              : [
                  {'name': 'Demo Driver', 'plate': 'D 1234 LNG', 'distance': 1.2},
                  {'name': 'Andi Sopir', 'plate': 'B 5678 XYZ', 'distance': 2.8},
                ];
          _activeTrips = [
            {'passenger': 'Budi Santoso', 'driver': 'Demo Driver', 'status': 'ONGOING', 'fare': 18000},
            {'passenger': 'Siti Rahayu', 'driver': 'Andi Sopir', 'status': 'PICKUP', 'fare': 14000},
          ];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user?.role != 'ADMIN') {
      return Scaffold(
        appBar: AppBar(title: const Text('Akses Ditolak')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded,
                  size: 64, color: AppColors.primaryLight),
              const SizedBox(height: 16),
              Text('Hanya Admin yang bisa mengakses halaman ini.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 15, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.dashboard_rounded,
                color: AppColors.accentColor, size: 22),
            const SizedBox(width: 8),
            Text('Admin Dashboard Lungo',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: AppColors.white)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryColor))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text('Statistik Platform',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: [
                        _statCard('Total Pengguna', '$_totalUsers',
                            Icons.people_rounded, AppColors.primaryColor),
                        _statCard('Total Driver', '$_totalDrivers',
                            Icons.electric_moped_rounded,
                            AppColors.secondaryColor),
                        _statCard('Trip Hari Ini', '$_tripsToday',
                            Icons.route_rounded, AppColors.accentColor,
                            darkText: true),
                        _statCard('Pendapatan', _currency.format(_revenueToday),
                            Icons.payments_rounded, AppColors.primaryDark),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _sectionHeader(
                        'Driver Online (${_onlineDrivers.length})',
                        Icons.wifi_rounded,
                        AppColors.online),
                    const SizedBox(height: 12),
                    if (_onlineDrivers.isEmpty)
                      _emptyState('Tidak ada driver online saat ini')
                    else
                      ..._onlineDrivers.map((d) => _driverTile(d)),
                    const SizedBox(height: 24),

                    _sectionHeader(
                        'Trip Aktif (${_activeTrips.length})',
                        Icons.directions_bike_rounded,
                        AppColors.primaryColor),
                    const SizedBox(height: 12),
                    if (_activeTrips.isEmpty)
                      _emptyState('Tidak ada trip aktif saat ini')
                    else
                      ..._activeTrips.map((t) => _tripTile(t)),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color,
      {bool darkText = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon,
              color: darkText
                  ? AppColors.primaryDark
                  : Colors.white.withValues(alpha: 0.8),
              size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: darkText ? AppColors.primaryDark : Colors.white)),
              Text(label,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: darkText
                          ? AppColors.primaryDark.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.75))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color iconColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppColors.primaryColor)),
      ],
    );
  }

  Widget _driverTile(Map<String, dynamic> d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withValues(alpha: 0.06),
            blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(
                color: AppColors.primaryLight, shape: BoxShape.circle),
            child: const Icon(Icons.electric_moped_rounded,
                color: AppColors.primaryColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d['name']?.toString() ?? '-',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 14, color: AppColors.primaryColor)),
                Text(d['plate']?.toString() ?? '',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: AppColors.online, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text('Online',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 12, color: AppColors.online)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tripTile(Map<String, dynamic> t) {
    final status = t['status']?.toString() ?? '';
    final isOngoing = status == 'ONGOING';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withValues(alpha: 0.06),
            blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isOngoing
                  ? AppColors.primaryColor.withValues(alpha: 0.1)
                  : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isOngoing ? Icons.directions_bike_rounded : Icons.person_pin_circle_rounded,
              color: AppColors.primaryColor, size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['passenger']?.toString() ?? '-',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 13, color: AppColors.primaryColor)),
                Text('Driver: ${t['driver'] ?? '-'}',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOngoing ? AppColors.primaryColor : AppColors.accentColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(status,
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: isOngoing ? Colors.white : AppColors.primaryDark)),
              ),
              const SizedBox(height: 4),
              Text(_currency.format(t['fare'] ?? 0),
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 12, color: AppColors.primaryColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String msg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(msg,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13, color: AppColors.textSecondary)),
      );
}
