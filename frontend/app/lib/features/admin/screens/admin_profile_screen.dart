import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../passenger/screens/edit_profile_screen.dart';
import 'admin_users_screen.dart';
import 'admin_drivers_screen.dart';
import 'admin_tariff_screen.dart';
import 'admin_trips_screen.dart';
import 'admin_audit_screen.dart';

class _P {
  static const darkest = Color(0xFF0B0940);
  static const dark    = Color(0xFF04198C);
  static const primary = Color(0xFF0540F2);
  static const accent  = Color(0xFFF2CB05);
  static const bg      = Color(0xFFF0F4FF);
  static const white   = Colors.white;
  static const logout  = Color(0xFFFF6B35);
  static const shadow  = Color(0x180540F2);
}

const _kIconColors = [
  Color(0xFF0540F2), Color(0xFF7C3AED), Color(0xFF0891B2),
  Color(0xFF059669), Color(0xFFD97706), Color(0xFF0540F2),
  Color(0xFF7C3AED), Color(0xFF0891B2), Color(0xFF059669),
  Color(0xFFFF6B35),
];
const _kIconBgs = [
  Color(0xFFE0E8FF), Color(0xFFF0E8FF), Color(0xFFE0F4FF),
  Color(0xFFDCFCE7), Color(0xFFFEF3C7), Color(0xFFE0E8FF),
  Color(0xFFF0E8FF), Color(0xFFE0F4FF), Color(0xFFDCFCE7),
  Color(0xFFFFEDE8),
];

class _AdminStats {
  final int totalUsers, totalDrivers, openComplaints;
  const _AdminStats({
    required this.totalUsers,
    required this.totalDrivers,
    required this.openComplaints,
  });
}

final _adminStatsProvider = FutureProvider<_AdminStats>((ref) async {
  try {
    final resp = await ApiClient.create().get('/admin/stats');
    final d = resp.data as Map<String, dynamic>;
    return _AdminStats(
      totalUsers:     (d['totalUsers']     as num?)?.toInt() ?? 0,
      totalDrivers:   (d['totalDrivers']   as num?)?.toInt() ?? 0,
      openComplaints: (d['openComplaints'] as num?)?.toInt() ?? 0,
    );
  } catch (_) {
    return const _AdminStats(totalUsers: 0, totalDrivers: 0, openComplaints: 0);
  }
});

class AdminProfileScreen extends ConsumerStatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  ConsumerState<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends ConsumerState<AdminProfileScreen>
    with TickerProviderStateMixin {

  late final AnimationController _headerAnim;
  late final AnimationController _statsAnim;
  late final AnimationController _listAnim;

  int _displayUsers      = 0;
  int _displayDrivers    = 0;
  int _displayComplaints = 0;

  int _targetUsers      = 0;
  int _targetDrivers    = 0;
  int _targetComplaints = 0;

  Timer? _countTimer;

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _statsAnim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _listAnim   = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _headerAnim.forward();
      Future.delayed(const Duration(milliseconds: 200), () => _statsAnim.forward());
      Future.delayed(const Duration(milliseconds: 400), _listAnim.forward);
    });
  }

  void _startCountUp() {
    _countTimer?.cancel();
    int step = 0;
    const total = 30;
    _countTimer = Timer.periodic(const Duration(milliseconds: 28), (t) {
      step++;
      final pct = step / total;
      setState(() {
        _displayUsers      = (_targetUsers      * pct).round().clamp(0, _targetUsers);
        _displayDrivers    = (_targetDrivers    * pct).round().clamp(0, _targetDrivers);
        _displayComplaints = (_targetComplaints * pct).round().clamp(0, _targetComplaints);
      });
      if (step >= total) t.cancel();
    });
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    _statsAnim.dispose();
    _listAnim.dispose();
    _countTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user     = ref.watch(authProvider).user;
    final name     = user?.name ?? 'Admin';
    final phone    = user?.phone ?? '-';
    final words    = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    final initials = words.isNotEmpty
        ? words.map((w) => w[0]).take(2).join().toUpperCase()
        : 'AD';

    ref.listen<AsyncValue<_AdminStats>>(_adminStatsProvider, (_, next) {
      next.whenData((s) {
        _targetUsers      = s.totalUsers;
        _targetDrivers    = s.totalDrivers;
        _targetComplaints = s.openComplaints;
        _startCountUp();
      });
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _P.bg,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(initials, name, phone)),
            SliverToBoxAdapter(child: _buildStatRow()),
            SliverToBoxAdapter(child: _buildMenuBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String initials, String name, String phone) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.12), end: Offset.zero,
        ).animate(CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut)),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_P.darkest, _P.dark],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            boxShadow: [
              BoxShadow(color: Color(0x380B0940), blurRadius: 20, offset: Offset(0, 8)),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 44),
                      Expanded(
                        child: Text('Panel Admin',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Stack(
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: _P.accent, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: _P.accent.withValues(alpha: 0.4),
                              blurRadius: 14, offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(initials,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0, bottom: 0,
                        child: Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            color: _P.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: _P.dark, width: 2),
                          ),
                          child: const Icon(Icons.shield_rounded, color: _P.dark, size: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Text(name,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(phone,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.65), fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                        color: _P.accent, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.admin_panel_settings_rounded, color: _P.dark, size: 14),
                        const SizedBox(width: 5),
                        Text('ADMINISTRATOR',
                          style: GoogleFonts.plusJakartaSans(
                            color: _P.dark, fontWeight: FontWeight.w900,
                            fontSize: 11, letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow() {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _statsAnim, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
            .animate(CurvedAnimation(parent: _statsAnim, curve: Curves.easeOutCubic)),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _P.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: _P.shadow, blurRadius: 16, offset: Offset(0, 4))],
          ),
          child: Row(
            children: [
              _StatCard(
                icon: Icons.people_rounded,
                value: '$_displayUsers',
                label: 'Pengguna',
                iconColor: _P.primary,
                iconBg: const Color(0xFFE0E8FF),
              ),
              Container(width: 1, height: 52, color: const Color(0xFFE8EEFF)),
              _StatCard(
                icon: Icons.electric_moped_rounded,
                value: '$_displayDrivers',
                label: 'Driver',
                iconColor: const Color(0xFF059669),
                iconBg: const Color(0xFFDCFCE7),
              ),
              Container(width: 1, height: 52, color: const Color(0xFFE8EEFF)),
              _StatCard(
                icon: Icons.report_problem_rounded,
                value: '$_displayComplaints',
                label: 'Keluhan',
                iconColor: const Color(0xFFD97706),
                iconBg: const Color(0xFFFEF3C7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuBody() {
    final sections = _menuSections();
    int globalIdx = 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        children: sections.map((sec) {
          final w = _buildSection(sec, globalIdx);
          globalIdx += sec.items.length;
          return w;
        }).toList(),
      ),
    );
  }

  Widget _buildSection(_MenuSection sec, int startIdx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(sec.title,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, fontSize: 11,
              letterSpacing: 1.0, color: const Color(0xFF7B8FC0),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _P.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: _P.shadow, blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Column(
            children: sec.items.asMap().entries.map((e) {
              final i = e.key;
              final absIdx = startIdx + i;
              final isLast = i == sec.items.length - 1;
              return AnimatedBuilder(
                animation: _listAnim,
                builder: (context, child) {
                  final delay = (absIdx * 0.08).clamp(0.0, 0.7);
                  final end   = (delay + 0.3).clamp(0.0, 1.0);
                  final t = ((_listAnim.value - delay) / (end - delay)).clamp(0.0, 1.0);
                  return Opacity(
                    opacity: t,
                    child: Transform.translate(offset: Offset(18 * (1 - t), 0), child: child),
                  );
                },
                child: Column(
                  children: [
                    _TileItem(
                      item: e.value,
                      iconColor: _kIconColors[absIdx % _kIconColors.length],
                      iconBg: _kIconBgs[absIdx % _kIconBgs.length],
                    ),
                    if (!isLast)
                      const Divider(height: 1, indent: 58, endIndent: 16, color: Color(0xFFEEF1FF)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  List<_MenuSection> _menuSections() => [
    _MenuSection(title: 'AKUN', items: [
      _Item(Icons.person_outline_rounded, 'Edit Profil', 'Ubah nama dan informasi admin',
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()))),
    ]),
    _MenuSection(title: 'MANAJEMEN', items: [
      _Item(Icons.people_outline_rounded, 'Kelola Pengguna',
          'Aktifkan / nonaktifkan akun pengguna',
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AdminUsersScreen()))),
      _Item(Icons.verified_user_outlined, 'Verifikasi Driver',
          'Setujui atau tolak pendaftaran driver',
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AdminDriversScreen()))),
      _Item(Icons.report_gmailerrorred_rounded, 'Keluhan Penumpang',
          'Lihat dan tanggapi laporan keluhan',
          () => Navigator.pushNamed(context, '/admin/complaints')),
      _Item(Icons.price_change_outlined, 'Pengaturan Tarif',
          'Ubah tarif dasar, per km, dan argo',
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AdminTariffScreen()))),
    ]),
    _MenuSection(title: 'LAPORAN', items: [
      _Item(Icons.bar_chart_rounded, 'Laporan Mingguan',
          'Statistik performa driver per minggu',
          () => Navigator.pushNamed(context, '/admin/reports')),
      _Item(Icons.route_rounded, 'Riwayat Trip',
          'Semua perjalanan pengguna & driver',
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AdminTripsScreen()))),
      _Item(Icons.manage_history_rounded, 'Log Audit',
          'Rekam jejak aktivitas admin sistem',
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AdminAuditScreen()))),
    ]),
    _MenuSection(title: 'SISTEM', items: [
      _Item(Icons.info_outline_rounded, 'Versi Aplikasi', null, null,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: const Color(0xFFE8EEFF),
                borderRadius: BorderRadius.circular(20)),
            child: Text('v1.0.0',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: _P.primary)),
          )),
      _Item(Icons.logout_rounded, 'Keluar', 'Keluar dari panel admin',
          _confirmLogout, isLogout: true),
    ]),
  ];

  Future<void> _confirmLogout() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LogoutSheet(),
    );
    if (confirmed == true && mounted) {
      final nav = Navigator.of(context);
      await ref.read(authProvider.notifier).logout();
      nav.pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }
}

class _Item {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isLogout;
  const _Item(this.icon, this.label, this.subtitle, this.onTap,
      {this.trailing, this.isLogout = false});
}

class _MenuSection {
  final String title;
  final List<_Item> items;
  const _MenuSection({required this.title, required this.items});
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;
  final Color iconBg;
  const _StatCard({
    required this.icon, required this.value,
    required this.label, required this.iconColor, required this.iconBg,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800, fontSize: 16,
            color: _P.dark)),
        Text(label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11, color: const Color(0xFF7B8FC0))),
      ],
    ),
  );
}

class _TileItem extends StatelessWidget {
  final _Item item;
  final Color iconColor;
  final Color iconBg;
  const _TileItem({
    required this.item, required this.iconColor, required this.iconBg});

  @override
  Widget build(BuildContext context) {
    final labelColor = item.isLogout ? _P.logout : const Color(0xFF0D1240);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: _P.primary.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: item.isLogout
                      ? _P.logout.withValues(alpha: 0.1)
                      : iconBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(item.icon,
                  color: item.isLogout ? _P.logout : iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600, fontSize: 14,
                        color: labelColor)),
                    if (item.subtitle != null)
                      Text(item.subtitle!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: const Color(0xFF9AAAD0))),
                  ],
                ),
              ),
              item.trailing ??
                  (item.onTap != null
                    ? Icon(Icons.chevron_right_rounded,
                        color: item.isLogout
                          ? _P.logout.withValues(alpha: 0.5)
                          : const Color(0xFFB0BFDF),
                        size: 20)
                    : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(24)),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
              color: _P.logout.withValues(alpha: 0.1),
              shape: BoxShape.circle),
          child: const Icon(Icons.logout_rounded, color: _P.logout, size: 28),
        ),
        const SizedBox(height: 16),
        Text('Keluar dari Lungo?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800, fontSize: 18, color: _P.dark)),
        const SizedBox(height: 8),
        Text('Anda perlu login kembali untuk menggunakan aplikasi.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13, color: const Color(0xFF7B8FC0))),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFDDE6FF), width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Batal',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, color: _P.primary)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _P.logout,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Keluar',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}
