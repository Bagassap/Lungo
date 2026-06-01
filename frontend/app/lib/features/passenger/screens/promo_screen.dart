import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class _Promo {
  final String code, title, desc, expiry;
  final Color color1, color2;
  final IconData icon;
  const _Promo(this.code, this.title, this.desc, this.expiry,
      this.color1, this.color2, this.icon);
}

const _kPromos = [
  _Promo('LUNGO30', 'Diskon 30%', 'Untuk semua perjalanan hari ini',
      'Berlaku s/d 30 Apr 2026',
      Color(0xFF0540F2), Color(0xFF2A6AFF), Icons.local_offer_rounded),
  _Promo('MAKAN10K', 'Hemat Rp 10.000', 'Minimum transaksi Rp 25.000',
      'Berlaku s/d 15 May 2026',
      Color(0xFF059669), Color(0xFF10B981), Icons.discount_rounded),
  _Promo('NEWUSER', 'Gratis Perjalanan', 'Khusus pengguna baru Lungo',
      'Berlaku s/d 31 May 2026',
      Color(0xFFD97706), Color(0xFFF59E0B), Icons.card_giftcard_rounded),
  _Promo('WEEKEND25', 'Diskon 25% Weekend', 'Sabtu & Minggu sepanjang bulan',
      'Berlaku s/d 31 May 2026',
      Color(0xFF7C3AED), Color(0xFF8B5CF6), Icons.weekend_rounded),
];

class PromoScreen extends StatefulWidget {
  const PromoScreen({super.key});
  @override
  State<PromoScreen> createState() => _PromoScreenState();
}

class _PromoScreenState extends State<PromoScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  final _codeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
  }

  @override
  void dispose() { _anim.dispose(); _codeCtrl.dispose(); super.dispose(); }

  void _claimPromo(String code) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kode "$code" disalin!',
            style: GoogleFonts.plusJakartaSans()),
        backgroundColor: AppColors.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: Column(
          children: [

            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0B0940), Color(0xFF04198C)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 20, 12),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: 20),
                          ),
                          Expanded(
                            child: Text('Promo & Voucher',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                          ),
                          const SizedBox(width: 44),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _codeCtrl,
                              textCapitalization: TextCapitalization.characters,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14, color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w700),
                              decoration: InputDecoration(
                                hintText: 'Masukkan kode promo',
                                hintStyle: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF7B8FC0), fontSize: 13),
                                filled: true, fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {
                              if (_codeCtrl.text.isNotEmpty) {
                                _claimPromo(_codeCtrl.text.toUpperCase());
                                _codeCtrl.clear();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentColor,
                              foregroundColor: AppColors.primaryDark,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Pakai',
                                style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _kPromos.length,
                separatorBuilder: (_, index) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final delay = i * 0.07;
                  return AnimatedBuilder(
                    animation: _anim,
                    builder: (context, child) {
                      final t = ((_anim.value - delay) / 0.3).clamp(0.0, 1.0);
                      return Opacity(
                        opacity: t,
                        child: Transform.translate(
                            offset: Offset(0, 24 * (1 - t)), child: child),
                      );
                    },
                    child: _PromoCard(
                      promo: _kPromos[i],
                      onClaim: () => _claimPromo(_kPromos[i].code),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final _Promo promo;
  final VoidCallback onClaim;
  const _PromoCard({required this.promo, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x140540F2), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [

          Container(
            width: 70,
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [promo.color1, promo.color2],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(promo.icon, color: Colors.white, size: 28),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6)),
                  child: Text(promo.code,
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white, fontWeight: FontWeight.w900,
                        fontSize: 9, letterSpacing: 0.5)),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: CustomPaint(
              size: const Size(1, 86),
              painter: _DashedPainter(),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(promo.title,
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800, fontSize: 15,
                        color: const Color(0xFF0D1240))),
                  const SizedBox(height: 4),
                  Text(promo.desc,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: const Color(0xFF7B8FC0))),
                  const SizedBox(height: 6),
                  Text(promo.expiry,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10, color: const Color(0xFFB0BFDF))),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: onClaim,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [promo.color1, promo.color2]),
                        borderRadius: BorderRadius.circular(8)),
                      child: Text('Salin Kode',
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, fontWeight: FontWeight.w700,
                            fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE0E8FF)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dashH = 5.0, gapH = 4.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dashH), paint);
      y += dashH + gapH;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
