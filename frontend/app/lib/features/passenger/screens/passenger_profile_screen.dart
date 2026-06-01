import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/widgets/lungo_snackbar.dart';
import '../../auth/providers/auth_provider.dart';
import 'passenger_activity_screen.dart';

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

class PassengerProfileScreen extends ConsumerStatefulWidget {
  const PassengerProfileScreen({super.key});

  @override
  ConsumerState<PassengerProfileScreen> createState() =>
      _PassengerProfileScreenState();
}

class _PassengerProfileScreenState
    extends ConsumerState<PassengerProfileScreen>
    with TickerProviderStateMixin {

  late final AnimationController _headerAnim;
  late final AnimationController _statsAnim;
  late final AnimationController _listAnim;

  int _displayTrips      = 0;
  int _displayKm         = 0;
  double _displayRating  = 0.0;
  static const _targetTrips  = 0;
  static const _targetKm     = 0;
  static const _targetRating = 0.0;
  Timer? _countTimer;

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _statsAnim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _listAnim   = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _headerAnim.forward();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        _statsAnim.forward();
        _startCountUp();
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        _listAnim.forward();
      });
    });
  }

  void _startCountUp() {
    int step = 0;
    const total = 30;
    _countTimer = Timer.periodic(const Duration(milliseconds: 28), (t) {
      step++;
      final pct = step / total;
      setState(() {
        _displayTrips  = (_targetTrips  * pct).round().clamp(0, _targetTrips);
        _displayKm     = (_targetKm     * pct).round().clamp(0, _targetKm);
        _displayRating = double.parse(
            (_targetRating * pct).clamp(0.0, _targetRating).toStringAsFixed(1));
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
    final name     = user?.name ?? 'Penumpang';
    final phone    = user?.phone ?? '-';
    final words    = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    final initials = words.isNotEmpty ? words.map((w) => w[0]).take(2).join().toUpperCase() : '?';

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
                        child: Text('Profil Saya',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/profile/edit'),
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

                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0540F2), Color(0xFF2A6AFF)],
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
                    decoration: BoxDecoration(color: _P.accent, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.motorcycle_rounded, color: _P.dark, size: 14),
                        const SizedBox(width: 5),
                        Text('PENUMPANG',
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
              _StatCard(icon: Icons.route_rounded, value: '$_displayTrips×',
                label: 'Perjalanan', iconColor: _P.primary, iconBg: const Color(0xFFE0E8FF)),
              Container(width: 1, height: 52, color: const Color(0xFFE8EEFF)),
              _StatCard(icon: Icons.straighten_rounded, value: '${_displayKm}km',
                label: 'Jarak Total', iconColor: const Color(0xFF059669), iconBg: const Color(0xFFDCFCE7)),
              Container(width: 1, height: 52, color: const Color(0xFFE8EEFF)),
              _StatCard(icon: Icons.star_rounded, value: '$_displayRating★',
                label: 'Rating', iconColor: const Color(0xFFD97706), iconBg: const Color(0xFFFEF3C7)),
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
      _Item(Icons.person_outline_rounded, 'Edit Profil', 'Ubah nama dan foto profil',
          () => Navigator.pushNamed(context, '/profile/edit')),
      _Item(Icons.location_on_outlined, 'Alamat Tersimpan', 'Rumah, kantor & favorit',
          () => Navigator.pushNamed(context, '/profile/addresses')),
      _Item(Icons.electric_moped_rounded, 'Beralih ke Mode Driver',
          'Aktifkan mode driver & terima pesanan',
          _switchToDriver),
      _Item(Icons.add_circle_outline_rounded, 'Upgrade ke Driver',
          'Daftar kendaraan & mulai terima order',
          _switchToDriver),
    ]),
    _MenuSection(title: 'AKTIVITAS', items: [
      _Item(Icons.history_rounded, 'Riwayat Perjalanan', 'Lihat semua perjalananmu',
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerActivityScreen()))),
      _Item(Icons.star_outline_rounded, 'Nilai Perjalanan', 'Beri rating driver-mu',
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _RatingScreen()))),
    ]),
    _MenuSection(title: 'LAINNYA', items: [
      _Item(Icons.notifications_outlined, 'Notifikasi', 'Atur preferensi notifikasi',
          () => Navigator.pushNamed(context, '/profile/notifications')),
      _Item(Icons.help_outline_rounded, 'Bantuan & FAQ', 'Temukan jawaban di sini',
          () => Navigator.pushNamed(context, '/profile/help')),
      _Item(Icons.rate_review_rounded, 'Saran & Kritik', 'Bantu kami jadi lebih baik',
          () => Navigator.pushNamed(context, '/profile/complaint')),
      _Item(Icons.description_outlined, 'Syarat & Ketentuan', 'Kebijakan privasi & TOS',
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _TermsScreen()))),
      _Item(Icons.info_outline_rounded, 'Versi Aplikasi', null, null,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFE8EEFF), borderRadius: BorderRadius.circular(20)),
            child: Text('v1.0.0',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: _P.primary)),
          )),
      _Item(Icons.logout_rounded, 'Keluar', 'Sampai jumpa lagi!',
          _confirmLogout, isLogout: true),
    ]),
  ];

  Future<void> _switchToDriver() async {
    final phone = await SecureStorage.getUserPhone();
    if (phone == null || phone.isEmpty) {
      if (!mounted) return;
      LungoSnackbar.error(context, 'Gagal mendapatkan data akun');
      return;
    }

    // Try direct role-switch first — works if driver account already exists
    try {
      final response = await DioClient.create().post('/auth/select-role', data: {
        'phone': phone,
        'role': 'DRIVER',
      });
      if (!mounted) return;
      final data         = response.data as Map<String, dynamic>;
      final accessToken  = data['accessToken']  as String;
      final refreshToken = data['refreshToken'] as String;
      final userId       = (data['user'] as Map<String, dynamic>)['id'] as String;

      await SecureStorage.saveTokens(
        accessToken:  accessToken,
        refreshToken: refreshToken,
        userId:       userId,
      );
      await SecureStorage.saveRole('DRIVER');

      await ref.read(authProvider.notifier).checkSession();
      if (!mounted) return;
      LungoSnackbar.success(context, 'Berhasil beralih ke mode driver');
      Navigator.pushNamedAndRemoveUntil(context, '/main', (_) => false);
    } catch (e) {
      if (!mounted) return;
      final isNotFound = e.toString().contains('404') || e.toString().contains('tidak ditemukan');
      if (isNotFound) {
        // No driver account — go through full driver registration
        Navigator.pushNamed(context, '/driver-register');
      } else {
        LungoSnackbar.error(context, 'Gagal beralih mode. Coba lagi.');
      }
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LogoutSheet(),
    );
    if (confirmed == true && mounted) {
      final nav = Navigator.of(context);
      nav.pushNamedAndRemoveUntil('/login', (_) => false);
      await ref.read(authProvider.notifier).logout();
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
            fontWeight: FontWeight.w800, fontSize: 16, color: _P.dark)),
        Text(label,
          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF7B8FC0))),
      ],
    ),
  );
}

class _TileItem extends StatelessWidget {
  final _Item item;
  final Color iconColor;
  final Color iconBg;
  const _TileItem({required this.item, required this.iconColor, required this.iconBg});

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
                  color: item.isLogout ? _P.logout.withValues(alpha: 0.1) : iconBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(item.icon, color: item.isLogout ? _P.logout : iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600, fontSize: 14, color: labelColor)),
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
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(color: _P.logout.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.logout_rounded, color: _P.logout, size: 28),
        ),
        const SizedBox(height: 16),
        Text('Keluar dari Lungo?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: _P.dark)),
        const SizedBox(height: 8),
        Text('Anda perlu login kembali untuk menggunakan aplikasi.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF7B8FC0))),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFDDE6FF), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Batal',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: _P.primary)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _P.logout, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

class _TermsScreen extends StatelessWidget {
  const _TermsScreen();
  @override
  Widget build(BuildContext context) => _SimpleInfoScreen(
    title: 'Syarat & Ketentuan',
    icon: Icons.description_outlined,
    items: const [
      ('Versi Dokumen', 'v1.0 – Jan 2025'),
      ('Privasi Data', 'Data kamu aman bersama kami'),
      ('Penggunaan Layanan', 'Untuk penumpang terdaftar'),
      ('Pembatalan Trip', 'Maks. 3 kali per hari'),
      ('Sanksi', 'Penangguhan akun bila melanggar'),
      ('Kontak Legal', 'legal@lungo.id'),
    ],
  );
}

class _RatingScreen extends StatelessWidget {
  const _RatingScreen();
  @override
  Widget build(BuildContext context) => _SimpleInfoScreen(
    title: 'Nilai Perjalanan',
    icon: Icons.star_outline_rounded,
    items: const [
      ('Info', 'Fitur rating driver segera hadir'),
      ('Cara Kerja', 'Beri bintang setelah perjalanan selesai'),
      ('Manfaat', 'Bantu driver terbaik untuk semua'),
    ],
  );
}

class _SimpleInfoScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<(String, String)> items;
  const _SimpleInfoScreen({required this.title, required this.icon, required this.items});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _P.bg,
        body: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_P.darkest, _P.dark],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 20),
                      ),
                      Expanded(
                        child: Text(title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: _P.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: _P.shadow, blurRadius: 10, offset: Offset(0, 3))],
                    ),
                    child: Column(
                      children: items.asMap().entries.map((e) {
                        final isLast = e.key == items.length - 1;
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Text(e.value.$1,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13, color: const Color(0xFF7B8FC0))),
                                  const Spacer(),
                                  Flexible(
                                    child: Text(e.value.$2,
                                      textAlign: TextAlign.right,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13, fontWeight: FontWeight.w600,
                                        color: const Color(0xFF0D1240))),
                                  ),
                                ],
                              ),
                            ),
                            if (!isLast)
                              const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFEEF1FF)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
