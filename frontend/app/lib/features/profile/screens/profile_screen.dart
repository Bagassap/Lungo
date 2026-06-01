import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lungo_button.dart';

class ProfileScreen extends StatefulWidget {
  final bool showBackButton;
  const ProfileScreen({super.key, this.showBackButton = true});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = 'Driver';
  String _phone = '';
  double _rating = 0.0;
  int _totalRides = 0;
  final bool _ktpVerified = true;
  final bool _simVerified = false;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await SecureStorage.getUserName();
    final phone = await SecureStorage.getUserPhone();
    if (mounted) {
      setState(() {
        _name = name ?? 'Driver';
        _phone = phone ?? '';
      });
    }
    try {
      final resp = await DioClient.create().get('/drivers/profile');
      final d = resp.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _rating = (d['rating'] as num?)?.toDouble() ?? 4.9;
          _totalRides = (d['totalRides'] as int?) ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      await DioClient.create().post('/auth/logout');
    } finally {
      await SecureStorage.clear();
    }
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        children: [

          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0540F2), Color(0xFF056CF2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 32,
              left: 24,
              right: 24,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    if (widget.showBackButton)
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white70,
                          size: 22,
                        ),
                      )
                    else
                      const SizedBox(width: 40),
                    Expanded(
                      child: Text(
                        'Profil Driver',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.accentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.primaryDark,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _name,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _phone,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFD700),
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_rating',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Colors.white38,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      '$_totalRides trip',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Dokumen'),
                  const SizedBox(height: 12),
                  _docCard('KTP', 'Kartu Tanda Penduduk', _ktpVerified),
                  const SizedBox(height: 10),
                  _docCard('SIM', 'Surat Izin Mengemudi', _simVerified),
                  const SizedBox(height: 24),

                  _sectionTitle('Statistik'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryColor.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _statItem(
                          '$_totalRides',
                          'Total Trip',
                          Icons.route_rounded,
                        ),
                        _divider(),
                        _statItem('$_rating ★', 'Rating', Icons.star_rounded),
                        _divider(),
                        _statItem(
                          '2024',
                          'Bergabung',
                          Icons.calendar_today_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  LungoButton(
                    label: 'Keluar',
                    onPressed: _logout,
                    isLoading: _isLoggingOut,
                    isSecondary: true,
                    foregroundColor: Colors.red.shade600,
                    icon: Icons.logout_rounded,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
    t,
    style: GoogleFonts.plusJakartaSans(
      fontWeight: FontWeight.w600,
      fontSize: 15,
      color: AppColors.textSecondary,
    ),
  );

  Widget _docCard(String code, String label, bool verified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: verified
                  ? AppColors.accentColor.withValues(alpha: 0.15)
                  : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.badge_rounded,
              color: verified
                  ? AppColors.primaryColor
                  : AppColors.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.primaryColor,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: verified
                  ? AppColors.accentColor
                  : Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  verified
                      ? Icons.check_circle_rounded
                      : Icons.schedule_rounded,
                  size: 14,
                  color: verified
                      ? AppColors.primaryDark
                      : Colors.orange.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  verified ? 'Terverifikasi' : 'Pending',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: verified
                        ? AppColors.primaryDark
                        : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, IconData icon) => Expanded(
    child: Column(
      children: [
        Icon(icon, color: AppColors.primaryColor, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AppColors.primaryColor,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );

  Widget _divider() => Container(
    width: 1,
    height: 40,
    color: AppColors.primaryLight,
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );
}
