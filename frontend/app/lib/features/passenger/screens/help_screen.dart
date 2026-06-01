import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class _Faq {
  final String question, answer;
  bool expanded = false;
  _Faq(this.question, this.answer);
}

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final List<_Faq> _faqs = [
    _Faq('Bagaimana cara memesan ojek?',
        'Buka aplikasi, masukkan tujuan, lalu tekan "Pesan". Driver terdekat akan segera menjemputmu.'),
    _Faq('Apa metode pembayaran yang tersedia?',
        'Lungo mendukung pembayaran tunai dan e-wallet (OVO, GoPay, Dana, ShopeePay).'),
    _Faq('Bagaimana jika driver tidak datang?',
        'Hubungi driver via chat atau telepon. Jika tidak ada respons dalam 5 menit, batalkan pesanan dan buat pesanan baru.'),
    _Faq('Bagaimana cara mendapatkan promo?',
        'Cek menu Promo & Voucher di halaman profil. Masukkan kode promo saat checkout.'),
    _Faq('Apakah saya bisa membatalkan pesanan?',
        'Ya, kamu dapat membatalkan pesanan sebelum driver tiba. Pembatalan berulang dapat memengaruhi akun kamu.'),
    _Faq('Bagaimana cara menghubungi support?',
        'Kamu dapat menghubungi kami melalui tombol "Hubungi Kami" di bawah ini, atau email ke support@lungo.id.'),
  ];

  final _categories = [
    ('Pemesanan', Icons.motorcycle_rounded, Color(0xFFE0E8FF), Color(0xFF0540F2)),
    ('Pembayaran', Icons.payment_rounded, Color(0xFFDCFCE7), Color(0xFF059669)),
    ('Akun', Icons.person_rounded, Color(0xFFF0E8FF), Color(0xFF7C3AED)),
    ('Keamanan', Icons.shield_rounded, Color(0xFFFEF3C7), Color(0xFFD97706)),
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: _buildCategories()),
            SliverToBoxAdapter(child: _buildFaqSection()),
            SliverToBoxAdapter(child: _buildContactCard()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
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
                  child: Text('Bantuan & FAQ',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                ),
                const SizedBox(width: 44),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Text('Ada yang bisa kami bantu?',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
          ),
        ],
      ),
    ),
  );

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
    child: TextField(
      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.primaryDark),
      decoration: InputDecoration(
        hintText: 'Cari pertanyaan...',
        hintStyle: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF9AAAD0), fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryColor),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDDE6FF), width: 1.5)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDDE6FF), width: 1.5)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryColor, width: 2)),
      ),
    ),
  );

  Widget _buildCategories() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Topik Bantuan',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryDark)),
        const SizedBox(height: 12),
        Row(
          children: _categories.map((cat) {
            return Expanded(
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(color: Color(0x100540F2), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                            color: cat.$3, shape: BoxShape.circle),
                        child: Icon(cat.$2, color: cat.$4, size: 20),
                      ),
                      const SizedBox(height: 6),
                      Text(cat.$1,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );

  Widget _buildFaqSection() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pertanyaan Umum',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryDark)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x100540F2), blurRadius: 10, offset: Offset(0, 3)),
            ],
          ),
          child: Column(
            children: _faqs.asMap().entries.map((e) {
              final i = e.key;
              final faq = e.value;
              final isLast = i == _faqs.length - 1;
              return Column(
                children: [
                  InkWell(
                    onTap: () => setState(() => faq.expanded = !faq.expanded),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(faq.question,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600, fontSize: 13,
                                color: const Color(0xFF0D1240))),
                          ),
                          AnimatedRotation(
                            turns: faq.expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(Icons.keyboard_arrow_down_rounded,
                                color: AppColors.primaryColor, size: 22),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Text(faq.answer,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: const Color(0xFF7B8FC0), height: 1.5)),
                    ),
                    crossFadeState: faq.expanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                  ),
                  if (!isLast)
                    const Divider(height: 1, indent: 16, endIndent: 16,
                        color: Color(0xFFEEF1FF)),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    ),
  );

  Widget _buildContactCard() => Container(
    margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0540F2), Color(0xFF2A6AFF)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(color: Color(0x300540F2), blurRadius: 16, offset: Offset(0, 6)),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Masih butuh bantuan?',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 4),
              Text('Tim support kami siap membantu 24/7',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF2CB05),
                  foregroundColor: const Color(0xFF04198C),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.headset_mic_rounded, size: 16),
                label: Text('Hubungi Kami',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
        ),
        const Icon(Icons.support_agent_rounded, color: Colors.white38, size: 64),
      ],
    ),
  );
}
