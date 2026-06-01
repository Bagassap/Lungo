import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lungo_button.dart';

const _kDemoQris =
    '00020101021226570011ID.CO.LUNGO.WWW011893600914000123456702150000000000000000303UMI51440014ID.CO.QRIS.WWW0215ID20232255566480303UMI5204481453033605802ID5905LUNGO6013BANDUNG CITY61054017162070703A016304E1F5';

class DriverSubscriptionScreen extends StatefulWidget {
  const DriverSubscriptionScreen({super.key});

  @override
  State<DriverSubscriptionScreen> createState() =>
      _DriverSubscriptionScreenState();
}

class _DriverSubscriptionScreenState extends State<DriverSubscriptionScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _paid = false;
  DateTime? _paidUntil;

  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  final _amount = 50000;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final until = await SecureStorage.getSubscriptionPaidUntil();
    final active = until != null && DateTime.now().isBefore(until);
    if (!mounted) return;
    setState(() {
      _paidUntil = until;
      _paid = active;
      _isLoading = false;
    });
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmPayment() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    final paidUntil = DateTime.now().add(const Duration(days: 30));
    await SecureStorage.saveSubscriptionPaidUntil(paidUntil);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _paid = true;
    });
    _fadeCtrl
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0540F2), Color(0xFF04198C), Color(0xFF056CF2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: _paid ? _buildSuccess() : _buildPayment(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPayment() {
    final amtFormatted = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(_amount);

    return Column(
      children: [

        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),

        Text(
          'Langganan Bulanan',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Aktif bekerja sepanjang bulan',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 28),

        _CardShell(
          title: 'Pembayaran',
          subtitle: 'Langganan 1 bulan',
          icon: Icons.qr_code_scanner_rounded,
          child: Column(
            children: [
              Text(
                'Biaya Langganan Driver',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$amtFormatted / bulan',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryColor,
                ),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryColor.withValues(alpha: 0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryColor.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.network(
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/QRIS_logo.svg/320px-QRIS_logo.svg.png',
                          height: 22,
                          errorBuilder: (_, _, _) => Text(
                            'QRIS',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Lungo',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    QrImageView(
                      data: _kDemoQris,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF0540F2),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF04198C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scan dengan app mobile banking\natau dompet digital kamu',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              _StepList(steps: const [
                '1. Buka aplikasi mobile banking / dompet digital',
                '2. Pilih menu Scan QRIS',
                '3. Scan kode QR di atas',
                '4. Konfirmasi nominal Rp 50.000',
                '5. Tekan tombol di bawah setelah bayar',
              ]),

              const SizedBox(height: 24),
              LungoButton(
                label: _isLoading ? 'Memproses...' : '✓  Saya Sudah Bayar',
                onPressed: _isLoading ? null : _confirmPayment,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 12),
              Text(
                'Pembayaran akan diverifikasi dalam 1×24 jam',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSuccess() {
    final paidUntil = _paidUntil ?? DateTime.now().add(const Duration(days: 30));
    final formatted =
        DateFormat('d MMMM yyyy', 'id_ID').format(paidUntil);

    return Column(
      children: [
        const SizedBox(height: 60),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,
          builder: (_, value, child) =>
              Transform.scale(scale: value, child: child),
          child: Container(
            width: 110,
            height: 110,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x5522C55E),
                  blurRadius: 32,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 60,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Pembayaran Berhasil!',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Langgananmu aktif hingga $formatted.\nSelamat bekerja!',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.80),
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              _SuccessItem(
                icon: Icons.payment_rounded,
                text: 'Pembayaran dikonfirmasi',
              ),
              const SizedBox(height: 12),
              _SuccessItem(
                icon: Icons.calendar_month_rounded,
                text: 'Berlaku hingga $formatted',
              ),
              const SizedBox(height: 12),
              _SuccessItem(
                icon: Icons.electric_moped_rounded,
                text: 'Kamu siap menerima pesanan',
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 6,
                shadowColor: const Color(0x5522C55E),
              ),
              child: Text(
                'Mulai Bekerja',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _CardShell({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}

class _StepList extends StatelessWidget {
  final List<String> steps;
  const _StepList({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: steps
            .map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  s,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SuccessItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SuccessItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
