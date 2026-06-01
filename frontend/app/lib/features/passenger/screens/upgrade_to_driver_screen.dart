import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/lungo_snackbar.dart';
import '../../auth/providers/auth_provider.dart';

class UpgradeToDriverScreen extends ConsumerStatefulWidget {
  const UpgradeToDriverScreen({super.key});

  @override
  ConsumerState<UpgradeToDriverScreen> createState() => _UpgradeToDriverScreenState();
}

class _UpgradeToDriverScreenState extends ConsumerState<UpgradeToDriverScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _plateCtrl  = TextEditingController();
  final _ktpCtrl    = TextEditingController();

  String _vehicleType      = 'MOTOR';
  String _motorSubtype     = 'Matic';
  bool   _agreeTerms       = false;
  bool   _loading          = false;
  bool   _submitAttempted  = false;

  static const _motorSubtypes = ['Bebek', 'Matic', 'Sport'];

  @override
  void dispose() {
    _plateCtrl.dispose();
    _ktpCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitAttempted = true);
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeTerms) {
      LungoSnackbar.warning(context, 'Centang persetujuan syarat & ketentuan');
      return;
    }
    setState(() => _loading = true);
    try {
      await DioClient.create().post('/drivers/upgrade', data: {
        'vehiclePlate': _plateCtrl.text.trim().toUpperCase(),
        'vehicleType': _vehicleType,
        'motorSubtype': _vehicleType == 'MOTOR' ? _motorSubtype : null,
        'ktpNumber': _ktpCtrl.text.trim(),
      });
      if (!mounted) return;
      _showSuccessSheet();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('409')
          ? 'Kamu sudah terdaftar sebagai driver.'
          : 'Gagal mendaftar. Coba lagi.';
      LungoSnackbar.error(context, msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuccessSheet(onDone: () {
        Navigator.of(context)
          ..pop()
          ..pop();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4FF),
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoBanner(),
                      const SizedBox(height: 24),

                      _SectionLabel('Nama Lengkap'),
                      const SizedBox(height: 10),
                      TextFormField(
                        initialValue: user?.name ?? '',
                        readOnly: true,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, color: const Color(0xFF9AAAD0)),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person_outline_rounded,
                              color: Color(0xFF9AAAD0)),
                          filled: true,
                          fillColor: const Color(0xFFF5F7FF),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFEEF1FF), width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFEEF1FF), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      _SectionLabel('Jenis Kendaraan'),
                      const SizedBox(height: 10),
                      Row(
                        children: ['MOTOR', 'MOBIL'].map((t) {
                          final isSelected = t == _vehicleType;
                          final icon = t == 'MOTOR'
                              ? Icons.electric_moped_rounded
                              : Icons.directions_car_rounded;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _vehicleType = t),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: EdgeInsets.only(right: t == 'MOTOR' ? 12 : 0),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF0540F2) : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF0540F2) : const Color(0xFFDDE3FF),
                                    width: 2,
                                  ),
                                  boxShadow: isSelected
                                      ? [BoxShadow(
                                          color: const Color(0xFF0540F2).withValues(alpha: 0.3),
                                          blurRadius: 12, offset: const Offset(0, 4))]
                                      : [const BoxShadow(
                                          color: Color(0x100540F2), blurRadius: 6, offset: Offset(0, 2))],
                                ),
                                child: Column(
                                  children: [
                                    Icon(icon,
                                        color: isSelected ? Colors.white : const Color(0xFF0540F2),
                                        size: 28),
                                    const SizedBox(height: 6),
                                    Text(t,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: isSelected ? Colors.white : const Color(0xFF0540F2),
                                          fontWeight: FontWeight.w700, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      if (_vehicleType == 'MOTOR') ...[
                        const SizedBox(height: 20),
                        _SectionLabel('Tipe Motor'),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFDDE3FF), width: 1.5),
                          ),
                          child: DropdownButtonFormField<String>(
                            initialValue: _motorSubtype,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: InputBorder.none,
                              prefixIcon: Icon(Icons.two_wheeler_rounded, color: Color(0xFF0540F2)),
                            ),
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 14, color: const Color(0xFF0D1240)),
                            items: _motorSubtypes.map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s),
                            )).toList(),
                            onChanged: (v) => setState(() => _motorSubtype = v!),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      _SectionLabel('Plat Nomor Kendaraan'),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _plateCtrl,
                        textCapitalization: TextCapitalization.characters,
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 1.5),
                        decoration: InputDecoration(
                          hintText: 'Contoh: D 1234 ABC',
                          hintStyle: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFADB5D6), fontSize: 14, letterSpacing: 0),
                          prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF0540F2)),
                          filled: true, fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFDDE3FF), width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFDDE3FF), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF0540F2), width: 2),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Plat nomor tidak boleh kosong';
                          if (v.trim().length < 4) return 'Plat nomor tidak valid';
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),
                      _SectionLabel('Nomor KTP'),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _ktpCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 16,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF0D1240)),
                        decoration: InputDecoration(
                          hintText: '16 digit nomor KTP',
                          hintStyle: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFADB5D6), fontSize: 14),
                          counterText: '',
                          prefixIcon: const Icon(Icons.credit_card_rounded, color: Color(0xFF0540F2)),
                          filled: true, fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFDDE3FF), width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFDDE3FF), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF0540F2), width: 2),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Nomor KTP tidak boleh kosong';
                          if (v.trim().length != 16) return 'KTP harus 16 digit (sekarang: ${v.trim().length})';
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () => setState(() => _agreeTerms = !_agreeTerms),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: _agreeTerms ? const Color(0xFF0540F2) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _agreeTerms ? const Color(0xFF0540F2) : const Color(0xFFDDE3FF),
                                  width: 2,
                                ),
                              ),
                              child: _agreeTerms
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13, color: const Color(0xFF4B5563)),
                                  children: const [
                                    TextSpan(text: 'Saya menyetujui '),
                                    TextSpan(
                                      text: 'Syarat & Ketentuan',
                                      style: TextStyle(
                                          color: Color(0xFF0540F2), fontWeight: FontWeight.w700),
                                    ),
                                    TextSpan(text: ' serta '),
                                    TextSpan(
                                      text: 'Kebijakan Privasi',
                                      style: TextStyle(
                                          color: Color(0xFF0540F2), fontWeight: FontWeight.w700),
                                    ),
                                    TextSpan(text: ' Lungo.'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_submitAttempted && !_agreeTerms)
                        Padding(
                          padding: const EdgeInsets.only(left: 32, top: 6),
                          child: Text(
                            'Wajib dicentang sebelum mendaftar',
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.red, fontSize: 12),
                          ),
                        ),

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: _loading ? null : _submit,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: _loading
                                  ? const LinearGradient(colors: [Color(0xFF9CA3AF), Color(0xFF9CA3AF)])
                                  : const LinearGradient(
                                      colors: [Color(0xFF0540F2), Color(0xFF2A6AFF)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: _loading
                                  ? []
                                  : [BoxShadow(
                                      color: const Color(0xFF0540F2).withValues(alpha: 0.4),
                                      blurRadius: 16, offset: const Offset(0, 6))],
                            ),
                            child: Center(
                              child: _loading
                                  ? const SizedBox(
                                      width: 22, height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5, color: Colors.white))
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.electric_moped_rounded,
                                            color: Colors.white, size: 20),
                                        const SizedBox(width: 8),
                                        Text('Daftar Sekarang',
                                            style: GoogleFonts.plusJakartaSans(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15)),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B0940), Color(0xFF04198C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Upgrade ke Driver',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0540F2), Color(0xFF2A6AFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0540F2).withValues(alpha: 0.3),
              blurRadius: 16, offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.electric_moped_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mulai Menghasilkan Uang!',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                    'Daftarkan kendaraanmu dan mulai terima order dari penumpang sekitarmu.',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.85), fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: const Color(0xFF04198C),
        ),
      );
}

class _SuccessSheet extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessSheet({required this.onDone});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C896), Color(0xFF00BCD4)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C896).withValues(alpha: 0.4),
                    blurRadius: 20, offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 38),
            ),
            const SizedBox(height: 20),
            Text('Pendaftaran Berhasil!',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900, fontSize: 20,
                    color: const Color(0xFF1F2937))),
            const SizedBox(height: 8),
            Text(
              'Akunmu sedang dalam review.\nKamu akan bisa terima order setelah diverifikasi.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, height: 1.6, color: const Color(0xFF6B7280)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0540F2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Kembali ke Profil',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white, fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
            ),
          ],
        ),
      );
}
