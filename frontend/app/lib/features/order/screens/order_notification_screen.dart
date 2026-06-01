import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_theme.dart';

class OrderNotificationScreen extends StatefulWidget {
  const OrderNotificationScreen({super.key});
  @override
  State<OrderNotificationScreen> createState() =>
      _OrderNotificationScreenState();
}

class _OrderNotificationScreenState extends State<OrderNotificationScreen>
    with TickerProviderStateMixin {
  late AnimationController _bounceCtrl;
  late AnimationController _countdownCtrl;
  late Animation<double> _bounceAnim;
  late Animation<double> _countdownAnim;
  late Timer _timer;
  int _secondsLeft = 30;
  bool _isAccepting = false;

  late Map<String, dynamic> _rideData;

  String get _rideId => (_rideData['rideId'] as String?) ?? '';
  String get _passengerName {
    final v = _rideData['passengerName'] as String?;
    return (v != null && v.isNotEmpty) ? v : 'Penumpang';
  }
  String get _pickup {
    final v = _rideData['originAddress'] as String?;
    return (v != null && v.isNotEmpty) ? v : 'Titik Jemput';
  }
  String get _destination {
    final v = _rideData['destinationAddress'] as String?;
    return (v != null && v.isNotEmpty) ? v : 'Tujuan tidak diset';
  }
  double _toDouble(dynamic v, [double fallback = 0.0]) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  int _toInt(dynamic v, [int fallback = 0]) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? (double.tryParse(v)?.toInt() ?? fallback);
    return fallback;
  }

  String get _distanceLabel {
    final km = _toDouble(_rideData['distanceKm']);
    return '${km.toStringAsFixed(1)} km';
  }
  String get _fareLabel {
    final fare = _toInt(_rideData['estimatedFare'], 14000);
    return 'Rp ${_formatRp(fare)}';
  }

  String _formatRp(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  void initState() {
    super.initState();

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _bounceAnim = Tween<double>(begin: 0.9, end: 1.1).animate(
        CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut));

    _countdownCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..forward();

    _countdownAnim = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _countdownCtrl, curve: Curves.linear));

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        if (mounted) Navigator.pop(context);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    _rideData = (args is Map<String, dynamic>) ? args : {};
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _countdownCtrl.dispose();
    _timer.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_isAccepting) return;
    _timer.cancel();
    setState(() => _isAccepting = true);

    try {
      final driverId = await SecureStorage.getUserId() ?? '';
      if (_rideId.isNotEmpty) {
        await DioClient.create()
            .post('/booking/rides/$_rideId/accept', data: {'driverId': driverId});
      }
    } catch (_) {

    }

    if (!mounted) return;
    FcmService.setPendingDriverAccept(_rideData);
    Navigator.pushReplacementNamed(context, '/main');
  }

  void _reject() {
    _timer.cancel();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primaryColor.withValues(alpha: 0.95),
                  AppColors.primaryDark.withValues(alpha: 0.98),
                ],
              ),
            ),
          ),

          ...List.generate(6, (i) {
            final sizes  = [160.0, 120.0, 80.0, 200.0, 100.0, 140.0];
            final lefts  = [-40.0, 280.0, 150.0, -60.0, 300.0, 200.0];
            final tops   = [60.0, 40.0, 200.0, 400.0, 500.0, 650.0];
            return Positioned(
              left: lefts[i],
              top: tops[i],
              child: Container(
                width: sizes[i],
                height: sizes[i],
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            );
          }),

          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 40,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      ScaleTransition(
                        scale: _bounceAnim,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.accentColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.accentColor.withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                              Icons.notifications_active_rounded,
                              color: AppColors.primaryDark,
                              size: 40),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        'Order Masuk!',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                            color: AppColors.primaryColor),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _passengerName,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 24),

                      _infoRow(Icons.my_location_rounded, 'Jemput di',
                          _pickup, AppColors.primaryColor),
                      const Padding(
                        padding: EdgeInsets.only(left: 18),
                        child: SizedBox(
                            height: 12,
                            child: VerticalDivider(
                                color: AppColors.primaryLight, width: 2)),
                      ),
                      _infoRow(Icons.location_on_rounded, 'Tujuan',
                          _destination, Colors.red),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          _chipInfo(Icons.route_rounded, _distanceLabel),
                          const SizedBox(width: 12),
                          _chipInfo(Icons.payments_rounded, _fareLabel),
                        ],
                      ),
                      const SizedBox(height: 28),

                      Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _countdownAnim,
                            builder: (_, child) => SizedBox(
                              width: 72,
                              height: 72,
                              child: CircularProgressIndicator(
                                value: _countdownAnim.value,
                                strokeWidth: 6,
                                backgroundColor: AppColors.primaryLight,
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                        AppColors.accentColor),
                              ),
                            ),
                          ),
                          Text(
                            '$_secondsLeft',
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                color: AppColors.primaryColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'detik tersisa',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isAccepting ? null : _reject,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade600,
                                side: BorderSide(
                                    color: Colors.red.shade400, width: 2),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: Text(
                                'TOLAK',
                                style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _isAccepting ? null : _accept,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accentColor,
                                foregroundColor: AppColors.primaryDark,
                                elevation: 6,
                                shadowColor: AppColors.accentColor
                                    .withValues(alpha: 0.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: _isAccepting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: AppColors.primaryDark),
                                    )
                                  : Text(
                                      'TERIMA',
                                      style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
      IconData icon, String label, String value, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: AppColors.textSecondary)),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.primaryColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chipInfo(IconData icon, String text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.primaryColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.primaryColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
