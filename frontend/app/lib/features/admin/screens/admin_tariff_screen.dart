import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/api_client.dart';

class AdminTariffScreen extends StatefulWidget {
  const AdminTariffScreen({super.key});

  @override
  State<AdminTariffScreen> createState() => _AdminTariffScreenState();
}

class _AdminTariffScreenState extends State<AdminTariffScreen> {
  static const _darkest = Color(0xFF0B0940);
  static const _dark    = Color(0xFF04198C);
  static const _primary = Color(0xFF0540F2);
  static const _accent  = Color(0xFFF2CB05);
  static const _bg      = Color(0xFFF0F4FF);
  static const _shadow  = Color(0x180540F2);

  Map<String, dynamic>? _tariff;
  bool _loading = true;
  bool _saving  = false;

  final _baseCtrl    = TextEditingController();
  final _perKmCtrl   = TextEditingController();
  final _perMinCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _baseCtrl.dispose();
    _perKmCtrl.dispose();
    _perMinCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await ApiClient.create().get('/admin/tariff');
      final d = resp.data as Map<String, dynamic>;
      setState(() {
        _tariff = d;
        _baseCtrl.text   = (d['basePrice']      as num?)?.toInt().toString()    ?? '14000';
        _perKmCtrl.text  = (d['pricePerKm']     as num?)?.toInt().toString()    ?? '2100';
        _perMinCtrl.text = (d['pricePerMinute'] as num?)?.toInt().toString()    ?? '500';
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat tarif')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final base   = int.tryParse(_baseCtrl.text.replaceAll('.', ''));
    final perKm  = int.tryParse(_perKmCtrl.text.replaceAll('.', ''));
    final perMin = int.tryParse(_perMinCtrl.text.replaceAll('.', ''));

    if (base == null || perKm == null || perMin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi semua kolom tarif dengan benar')));
      return;
    }

    setState(() => _saving = true);
    try {
      await ApiClient.create().patch('/admin/tariff', data: {
        'basePrice': base,
        'pricePerKm': perKm,
        'pricePerMinute': perMin,
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tarif berhasil diperbarui'),
            backgroundColor: Color(0xFF059669),
          ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan tarif')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _rupiah(num v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    int cnt = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (cnt > 0 && cnt % 3 == 0) buf.write('.');
      buf.write(s[i]);
      cnt++;
    }
    return 'Rp ${buf.toString().split('').reversed.join()}';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _primary))
                  : _buildBody(),
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
          colors: [_darkest, _dark],
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
              const Expanded(
                child: Text('Pengaturan Tarif',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700,
                    fontSize: 18, fontFamily: 'PlusJakartaSans')),
              ),
              const SizedBox(width: 44),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final history = _tariff?['history'] as List<dynamic>? ?? [];
    final updatedAt = _tariff?['updatedAt'] as String?;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_darkest, _dark],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: _shadow, blurRadius: 16, offset: Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.price_change_rounded,
                      color: _accent, size: 20),
                  const SizedBox(width: 8),
                  Text('Tarif Berlaku',
                    style: GoogleFonts.plusJakartaSans(
                      color: _accent, fontWeight: FontWeight.w700,
                      fontSize: 13, letterSpacing: 0.5)),
                  const Spacer(),
                  if (updatedAt != null)
                    Text(updatedAt.substring(0, 10),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11)),
                ],
              ),
              const SizedBox(height: 16),
              _TariffRow('Tarif Dasar',
                  _rupiah(_tariff?['basePrice'] as num? ?? 0)),
              _TariffRow('Per Kilometer',
                  _rupiah(_tariff?['pricePerKm'] as num? ?? 0)),
              _TariffRow('Per Menit',
                  _rupiah(_tariff?['pricePerMinute'] as num? ?? 0)),
              _TariffRow('Minimum Fare',
                  _rupiah(_tariff?['minimumFare'] as num? ?? 0)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: _shadow, blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ubah Tarif',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800, fontSize: 16,
                  color: const Color(0xFF0D1240))),
              const SizedBox(height: 4),
              Text('Perubahan langsung berlaku untuk pemesanan baru',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: const Color(0xFF9AAAD0))),
              const SizedBox(height: 20),
              _TariffField('Tarif Dasar (Rp)', _baseCtrl),
              const SizedBox(height: 14),
              _TariffField('Per Kilometer (Rp)', _perKmCtrl),
              const SizedBox(height: 14),
              _TariffField('Per Menit (Rp)', _perMinCtrl),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Simpan Tarif',
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (history.isNotEmpty) ...[
          Text('Riwayat Perubahan',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, fontSize: 11,
              letterSpacing: 1.0, color: const Color(0xFF7B8FC0))),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: _shadow, blurRadius: 8, offset: Offset(0, 2))
              ],
            ),
            child: Column(
              children: history.asMap().entries.map((e) {
                final h = e.value as Map<String, dynamic>;
                final isLast = e.key == history.length - 1;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 8, height: 8,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: const BoxDecoration(
                              color: _primary, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(h['change'] as String? ?? '-',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0D1240))),
                                const SizedBox(height: 2),
                                Text(h['date'] as String? ?? '-',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11, color: const Color(0xFF9AAAD0))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      const Divider(height: 1, indent: 36, endIndent: 16,
                          color: Color(0xFFEEF1FF)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _TariffRow extends StatelessWidget {
  final String label;
  final String value;
  const _TariffRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.65), fontSize: 13)),
          Text(value,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }
}

class _TariffField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _TariffField(this.label, this.controller);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: const Color(0xFF7B8FC0))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15, fontWeight: FontWeight.w700,
            color: const Color(0xFF0D1240)),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF0F4FF),
            prefixText: 'Rp ',
            prefixStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14, color: const Color(0xFF0540F2),
              fontWeight: FontWeight.w600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color(0xFF0540F2), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}
