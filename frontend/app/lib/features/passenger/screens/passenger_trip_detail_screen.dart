import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../chat/screens/chat_history_screen.dart';

const _kGreen  = Color(0xFF00C896);
const _kOrange = Color(0xFFFF6B35);
const _kGold   = Color(0xFFFFB800);
const _kRed    = Color(0xFFFF4757);
const _kPurple = Color(0xFF6C5CE7);
const _kTeal   = Color(0xFF00CEC9);
const _kPink   = Color(0xFFFF7675);

class TripDetailArgs {
  final String id, date, time, from, to, status;
  final double fare, distanceKm;
  final String? driverName, vehiclePlate, vehicleType;
  final double? driverRating;
  final double? passengerRating;

  const TripDetailArgs({
    required this.id,
    required this.date,
    required this.time,
    required this.from,
    required this.to,
    required this.status,
    required this.fare,
    required this.distanceKm,
    this.driverName,
    this.vehiclePlate,
    this.vehicleType,
    this.driverRating,
    this.passengerRating,
  });
}

class PassengerTripDetailScreen extends StatefulWidget {
  final TripDetailArgs args;
  const PassengerTripDetailScreen({super.key, required this.args});

  @override
  State<PassengerTripDetailScreen> createState() => _TripDetailState();
}

class _TripDetailState extends State<PassengerTripDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerCtrl;
  late AnimationController _contentCtrl;
  late Animation<double>   _headerFade;
  late Animation<double>   _contentFade;
  late Animation<Offset>   _contentSlide;

  final _dio = ApiClient.create();

  int  _selectedRating  = 0;
  bool _ratingSubmitted = false;

  TripDetailArgs get _a => widget.args;
  bool get _isDone      => _a.status == 'DONE';
  bool get _isCancelled => _a.status == 'CANCELLED';

  List<Color> get _gradColors {
    if (_isDone)      return [_kGreen, const Color(0xFF0540F2)];
    if (_isCancelled) return [_kRed,   _kOrange];
    return [AppColors.primaryColor, _kPurple];
  }

  int get _estMin => (_a.distanceKm / 22 * 60).round().clamp(3, 120);

  @override
  void initState() {
    super.initState();

    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _headerFade  = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _contentFade = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _contentCtrl, curve: Curves.easeOutCubic));

    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _contentCtrl.forward();
    });

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _contentCtrl.dispose();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.dark,
    ));
    super.dispose();
  }

  void _copyId() {
    Clipboard.setData(ClipboardData(text: _a.id));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('ID perjalanan disalin',
          style: TextStyle(fontFamily: 'Satoshi')),
      backgroundColor: _kGreen,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _shareTrip() {
    final fare = _isDone
        ? 'Rp ${_a.fare.toInt().toString().replaceAllMapped(RegExp(r"(\d)(?=(\d{3})+$)"), (m) => "${m[1]}.")}'
        : 'Dibatalkan';
    final text =
        '🛵 Lungo - Detail Perjalanan\n📅 ${_a.date}  •  ${_a.time}\n📍 Dari: ${_a.from}\n🎯 Ke: ${_a.to}\n💰 $fare\n🆔 ID: ${_a.id}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Info perjalanan disalin ke clipboard',
          style: TextStyle(fontFamily: 'Satoshi')),
      backgroundColor: AppColors.primaryColor,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _openChat() {
    final driverName = _a.driverName ?? 'Driver';
    Navigator.pushNamed(
      context,
      '/chat-history',
      arguments: ChatHistoryArgs(rideId: _a.id, title: driverName),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _kGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.receipt_long_rounded, color: _kGreen),
              ),
              title: const Text('Kwitansi',
                  style: TextStyle(
                      fontFamily: 'Satoshi', fontWeight: FontWeight.w700)),
              subtitle: const Text('Unduh rincian pembayaran',
                  style: TextStyle(fontFamily: 'Satoshi', fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showReceiptSnack(context);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.content_copy_rounded,
                    color: AppColors.primaryColor),
              ),
              title: const Text('Salin Detail',
                  style: TextStyle(
                      fontFamily: 'Satoshi', fontWeight: FontWeight.w700)),
              subtitle: const Text('Salin informasi perjalanan',
                  style: TextStyle(fontFamily: 'Satoshi', fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _shareTrip();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _kRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.flag_outlined, color: _kRed),
              ),
              title: const Text('Laporkan',
                  style: TextStyle(
                      fontFamily: 'Satoshi', fontWeight: FontWeight.w700)),
              subtitle: const Text('Laporkan masalah perjalanan',
                  style: TextStyle(fontFamily: 'Satoshi', fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showReportSnack(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0) return;
    setState(() => _ratingSubmitted = true);
    try {
      await _dio.post(
        '/booking/rides/${_a.id}/rate',
        data: {'rating': _selectedRating},
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2FF),
      body: CustomScrollView(
        slivers: [

          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            stretch: true,
            backgroundColor: _gradColors.first,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
            ),
            actions: [
              _AppBarBtn(icon: Icons.share_rounded, onTap: _shareTrip),
              const SizedBox(width: 8),
              _AppBarBtn(icon: Icons.more_vert_rounded, onTap: _showMoreOptions),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              stretchModes: const [StretchMode.zoomBackground],
              background: FadeTransition(
                opacity: _headerFade,
                child: _HeroHeader(
                  args: _a,
                  gradColors: _gradColors,
                  estMin: _estMin,
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: SlideTransition(
              position: _contentSlide,
              child: FadeTransition(
                opacity: _contentFade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  child: Column(
                    children: [

                      Transform.translate(
                        offset: const Offset(0, -1),
                        child: _TripIdBadge(id: _a.id, onCopy: _copyId),
                      ),
                      const SizedBox(height: 12),

                      _DetailSection(
                        index: 0,
                        child: _DriverSection(args: _a, onChat: _openChat),
                      ),
                      const SizedBox(height: 12),

                      _DetailSection(
                        index: 1,
                        child: _RouteSection(args: _a),
                      ),
                      const SizedBox(height: 12),

                      _DetailSection(
                        index: 2,
                        child: _StatsGrid(
                          distanceKm: _a.distanceKm,
                          estMin: _estMin,
                          departureTime: _a.time,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_isDone) ...[
                        _DetailSection(
                          index: 3,
                          child: _FareCard(
                            fare: _a.fare,
                            distanceKm: _a.distanceKm,
                          ),
                        ),
                        const SizedBox(height: 12),

                        _DetailSection(
                          index: 4,
                          child: _RatingCard(
                            driverName: _a.driverName,
                            existingRating: _a.passengerRating,
                            selected: _selectedRating,
                            submitted: _ratingSubmitted,
                            onRate: (r) => setState(() => _selectedRating = r),
                            onSubmit: _submitRating,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (_isCancelled) ...[
                        _DetailSection(
                          index: 3,
                          child: _CancelledCard(),
                        ),
                        const SizedBox(height: 12),
                      ],

                      _DetailSection(
                        index: _isDone ? 5 : (_isCancelled ? 4 : 3),
                        child: _ActionButtons(
                          isDone: _isDone,
                          isCancelled: _isCancelled,
                          onReorder: () =>
                              Navigator.pushNamed(context, '/destination'),
                          onReceipt: () => _showReceiptSnack(context),
                          onReport: () => _showReportSnack(context),
                        ),
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

  void _showReceiptSnack(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: const Text('Kwitansi sedang disiapkan...',
            style: TextStyle(fontFamily: 'Satoshi')),
        backgroundColor: _kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showReportSnack(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: const Text('Laporan akan segera diproses.',
            style: TextStyle(fontFamily: 'Satoshi')),
        backgroundColor: _kOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final TripDetailArgs args;
  final List<Color> gradColors;
  final int estMin;
  const _HeroHeader(
      {required this.args, required this.gradColors, required this.estMin});

  bool get isDone      => args.status == 'DONE';
  bool get isCancelled => args.status == 'CANCELLED';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDone
                          ? Icons.check_circle_rounded
                          : isCancelled
                              ? Icons.cancel_rounded
                              : Icons.radio_button_checked_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isDone
                          ? 'Perjalanan Selesai'
                          : isCancelled
                              ? 'Perjalanan Dibatalkan'
                              : 'Sedang Berlangsung',
                      style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  const Icon(Icons.electric_moped_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ke ${args.to.split(',').first}',
                      style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${args.date}  •  ${args.time}',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.76),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  _QuickStat(
                    icon: Icons.route_rounded,
                    value: '${args.distanceKm.toStringAsFixed(1)} km',
                    label: 'Jarak',
                  ),
                  const SizedBox(width: 24),
                  _QuickStat(
                    icon: Icons.timer_outlined,
                    value: '~$estMin mnt',
                    label: 'Durasi',
                  ),
                  if (isDone) ...[
                    const SizedBox(width: 24),
                    _QuickStat(
                      icon: Icons.payments_outlined,
                      value: _shortFare(args.fare),
                      label: 'Dibayar',
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortFare(double f) {
    if (f >= 1000) return 'Rp ${(f / 1000).toStringAsFixed(0)}rb';
    return 'Rp ${f.toInt()}';
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  const _QuickStat(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 13),
              const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ],
      );
}

class _AppBarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _AppBarBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Material(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
          ),
        ),
      );
}

class _TripIdBadge extends StatelessWidget {
  final String id;
  final VoidCallback? onCopy;
  const _TripIdBadge({required this.id, this.onCopy});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  size: 16, color: AppColors.primaryColor),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ID Perjalanan',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 10,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                Text(
                  id.length > 16 ? '${id.substring(0, 16)}…' : id,
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Color(0xFF1F2937),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const Spacer(),

            GestureDetector(
              onTap: onCopy,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.copy_rounded,
                    size: 14, color: AppColors.primaryColor),
              ),
            ),
          ],
        ),
      );
}

class _DetailSection extends StatefulWidget {
  final int index;
  final Widget child;
  const _DetailSection({required this.index, required this.child});

  @override
  State<_DetailSection> createState() => _DetailSectionState();
}

class _DetailSectionState extends State<_DetailSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: 260 + widget.index * 80), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

class _CardShell extends StatelessWidget {
  final String title;
  final IconData titleIcon;
  final Color titleIconColor;
  final Widget child;
  final Widget? trailing;

  const _CardShell({
    required this.title,
    required this.titleIcon,
    required this.titleIconColor,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.055),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: titleIconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(titleIcon, size: 14, color: titleIconColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  if (trailing != null) ...[
                    const Spacer(),
                    trailing!,
                  ],
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: child,
            ),
          ],
        ),
      );
}

class _DriverSection extends StatelessWidget {
  final TripDetailArgs args;
  final VoidCallback? onChat;
  const _DriverSection({required this.args, this.onChat});

  @override
  Widget build(BuildContext context) {
    if (args.driverName == null) {
      return _CardShell(
        title: 'Informasi Driver',
        titleIcon: Icons.person_outline_rounded,
        titleIconColor: Colors.grey,
        child: Row(
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_off_rounded,
                  color: Colors.grey.shade400, size: 24),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Driver tidak ditemukan',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Perjalanan dibatalkan sebelum driver\nmenerima pesanan',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final initials = args.driverName!
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();
    final rating = args.driverRating ?? 5.0;

    return _CardShell(
      title: 'Driver Kamu',
      titleIcon: Icons.person_rounded,
      titleIconColor: _kPurple,
      trailing: _RatingPill(rating: rating),
      child: Column(
        children: [
          Row(
            children: [

              Container(
                width: 58, height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFF0540F2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _kPurple.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      args.driverName!,
                      style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.electric_moped_rounded,
                            size: 13, color: Color(0xFF6B7280)),
                        const SizedBox(width: 4),
                        Text(
                          args.vehicleType ?? 'Motor',
                          style: const TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              _CircleBtn(
                icon: Icons.chat_bubble_rounded,
                bg: AppColors.primaryLight,
                color: AppColors.primaryColor,
                onTap: onChat ?? () {},
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF9FAFB)),
          const SizedBox(height: 12),
          Row(
            children: [

              _PlateBig(plate: args.vehiclePlate ?? ''),
              const Spacer(),

              _StatusPill(
                label: 'Aktif',
                icon: Icons.circle,
                color: _kGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  final double rating;
  const _RatingPill({required this.rating});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _kGold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: _kGold, size: 13),
            const SizedBox(width: 3),
            Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _kGold,
              ),
            ),
          ],
        ),
      );
}

class _PlateBig extends StatelessWidget {
  final String plate;
  const _PlateBig({required this.plate});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppColors.primaryColor.withValues(alpha: 0.25)),
        ),
        child: Text(
          plate,
          style: const TextStyle(
            fontFamily: 'Satoshi',
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 1.5,
            color: AppColors.primaryDark,
          ),
        ),
      );
}

class _StatusPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _StatusPill(
      {required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 8, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      );
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color bg, color;
  final VoidCallback onTap;
  const _CircleBtn(
      {required this.icon,
      required this.bg,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      );
}

class _RouteSection extends StatelessWidget {
  final TripDetailArgs args;
  const _RouteSection({required this.args});

  @override
  Widget build(BuildContext context) => _CardShell(
        title: 'Rute Perjalanan',
        titleIcon: Icons.route_rounded,
        titleIconColor: _kPurple,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            SizedBox(
              width: 28,
              child: Column(
                children: [

                  Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),

                  Column(
                    children: [
                      ...List.generate(
                        4,
                        (_) => Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          width: 2, height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1D5DB),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_kPurple, AppColors.primaryColor],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${args.distanceKm.toStringAsFixed(1)}\nkm',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      ),
                      ...List.generate(
                        4,
                        (_) => Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          width: 2, height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1D5DB),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ],
                  ),

                  Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: _kOrange,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _kOrange.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RouteLabel(
                    tag: 'JEMPUT',
                    address: args.from,
                    time: args.time,
                    tagColor: AppColors.primaryColor,
                  ),
                  const SizedBox(height: 36),
                  _RouteLabel(
                    tag: 'TUJUAN',
                    address: args.to,
                    time: null,
                    tagColor: _kOrange,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _RouteLabel extends StatelessWidget {
  final String tag, address;
  final String? time;
  final Color tagColor;
  const _RouteLabel({
    required this.tag,
    required this.address,
    required this.time,
    required this.tagColor,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: tagColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (time != null) ...[
                const Spacer(),
                Text(
                  time!,
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            address,
            style: const TextStyle(
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Color(0xFF1F2937),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
}

class _StatsGrid extends StatelessWidget {
  final double distanceKm;
  final int estMin;
  final String departureTime;
  const _StatsGrid({
    required this.distanceKm,
    required this.estMin,
    required this.departureTime,
  });

  String _addMin(String t, int m) {
    try {
      final p  = t.split(':');
      final h  = int.parse(p[0]);
      final mi = int.parse(p[1]);
      final total = h * 60 + mi + m;
      final nh = (total ~/ 60) % 24;
      final nm = total % 60;
      return '${nh.toString().padLeft(2, '0')}:${nm.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--:--';
    }
  }

  @override
  Widget build(BuildContext context) {
    final arrival = _addMin(departureTime, estMin);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: _StatBox(
              icon: Icons.route_rounded,
              value: '${distanceKm.toStringAsFixed(1)} km',
              label: 'Jarak',
              gradColors: const [_kPurple, AppColors.primaryColor],
            ),
          ),
          _VertDivider(),
          Expanded(
            child: _StatBox(
              icon: Icons.timer_rounded,
              value: '~$estMin mnt',
              label: 'Durasi',
              gradColors: const [_kGreen, _kTeal],
            ),
          ),
          _VertDivider(),
          Expanded(
            child: _StatBox(
              icon: Icons.departure_board_rounded,
              value: departureTime,
              label: 'Berangkat',
              gradColors: const [_kOrange, _kGold],
            ),
          ),
          _VertDivider(),
          Expanded(
            child: _StatBox(
              icon: Icons.flag_rounded,
              value: arrival,
              label: 'Est. Tiba',
              gradColors: const [_kRed, _kPink],
            ),
          ),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 44, color: const Color(0xFFF3F4F6));
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final List<Color> gradColors;
  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.gradColors,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: Color(0xFF1F2937),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 9,
              color: Color(0xFF9CA3AF),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
}

class _FareCard extends StatelessWidget {
  final double fare, distanceKm;
  static const double _base  = 14500;
  static const double _perKm = 2100;

  const _FareCard({required this.fare, required this.distanceKm});

  String _fmt(double v) {
    final s = v.toInt().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp $buf';
  }

  @override
  Widget build(BuildContext context) {
    final kmCost  = distanceKm * _perKm;
    final baseApplied = fare <= _base;

    return _CardShell(
      title: 'Rincian Biaya',
      titleIcon: Icons.receipt_rounded,
      titleIconColor: _kGreen,
      trailing: _PayMethodBadge(),
      child: Column(
        children: [

          _FareRow(
            icon: Icons.home_rounded,
            iconColor: AppColors.primaryColor,
            label: 'Tarif Dasar',
            sub: 'Biaya minimum per perjalanan',
            amount: _fmt(_base),
            amountColor: AppColors.primaryColor,
          ),
          const SizedBox(height: 10),

          _FareRow(
            icon: Icons.route_rounded,
            iconColor: _kPurple,
            label: 'Biaya Jarak',
            sub:
                '${distanceKm.toStringAsFixed(1)} km × Rp ${_perKm.toInt()}',
            amount: _fmt(kmCost),
            amountColor: _kPurple,
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                  child: Divider(color: Colors.grey.shade200, thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: baseApplied
                        ? _kGold.withValues(alpha: 0.12)
                        : _kGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    baseApplied ? 'Tarif min. berlaku' : 'Total',
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: baseApplied ? _kGold : _kGreen,
                    ),
                  ),
                ),
              ),
              Expanded(
                  child: Divider(color: Colors.grey.shade200, thickness: 1)),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kGreen, Color(0xFF0540F2)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _kGreen.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Pembayaran',
                        style: TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Sudah termasuk semua biaya',
                        style: TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 10,
                          color: Color(0xBBFFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Rp ${fare.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}',
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FareRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor, amountColor;
  final String label, sub, amount;
  const _FareRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sub,
    required this.amount,
    required this.amountColor,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF1F2937),
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 10,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: amountColor,
            ),
          ),
        ],
      );
}

class _PayMethodBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _kGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: _kGreen.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payments_rounded, size: 11, color: _kGreen),
            SizedBox(width: 4),
            Text(
              'TUNAI',
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _kGreen,
              ),
            ),
          ],
        ),
      );
}

class _RatingCard extends StatelessWidget {
  final String? driverName;
  final double? existingRating;
  final int selected;
  final bool submitted;
  final ValueChanged<int> onRate;
  final VoidCallback onSubmit;

  const _RatingCard({
    required this.driverName,
    required this.existingRating,
    required this.selected,
    required this.submitted,
    required this.onRate,
    required this.onSubmit,
  });

  static const _labels = [
    '',
    'Sangat Kurang',
    'Kurang Baik',
    'Cukup Baik',
    'Bagus!',
    'Luar Biasa!'
  ];

  @override
  Widget build(BuildContext context) {

    if (existingRating != null) {
      return _CardShell(
        title: 'Rating Perjalanan',
        titleIcon: Icons.star_rounded,
        titleIconColor: _kGold,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(
                    i < existingRating! ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: i < existingRating! ? _kGold : Colors.grey.shade300,
                    size: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${existingRating!.toStringAsFixed(1)} dari 5.0',
              style: const TextStyle(
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: _kGold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Kamu sudah memberi rating untuk perjalanan ini',
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    if (submitted) {
      return _CardShell(
        title: 'Rating Perjalanan',
        titleIcon: Icons.star_rounded,
        titleIconColor: _kGold,
        child: Column(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: _kGreen, size: 28),
            ),
            const SizedBox(height: 12),
            const Text(
              'Terima kasih!',
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Rating kamu membantu driver untuk\nterus meningkatkan pelayanan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return _CardShell(
      title: 'Beri Rating',
      titleIcon: Icons.star_outline_rounded,
      titleIconColor: _kGold,
      child: Column(
        children: [
          Text(
            driverName != null
                ? 'Bagaimana pengalamanmu\nbersama ${driverName!.split(' ').first}?'
                : 'Bagaimana pengalaman perjalananmu?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF374151),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => GestureDetector(
                onTap: () => onRate(i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: AnimatedScale(
                    scale: selected >= i + 1 ? 1.22 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.elasticOut,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        selected >= i + 1
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        key: ValueKey(selected >= i + 1),
                        color: selected >= i + 1
                            ? _kGold
                            : Colors.grey.shade300,
                        size: 38,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: selected > 0
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _labels[selected],
                      key: ValueKey(selected),
                      style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _kGold,
                      ),
                    ),
                  )
                : const SizedBox(height: 8),
          ),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: selected > 0
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_kGold, _kOrange],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: _kGold.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: onSubmit,
                            borderRadius: BorderRadius.circular(12),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send_rounded,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    'Kirim Rating',
                                    style: TextStyle(
                                      fontFamily: 'Satoshi',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _CancelledCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFE4E6), Color(0xFFFFF0F0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kRed.withValues(alpha: 0.2)),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kRed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.info_outline_rounded,
                  color: _kRed, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Perjalanan Dibatalkan',
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: _kRed,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tidak ada biaya yang dikenakan untuk perjalanan yang dibatalkan.',
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 12,
                      color: Color(0xFF9B1C1C),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ActionButtons extends StatelessWidget {
  final bool isDone, isCancelled;
  final VoidCallback onReorder, onReceipt, onReport;

  const _ActionButtons({
    required this.isDone,
    required this.isCancelled,
    required this.onReorder,
    required this.onReceipt,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [

          SizedBox(
            width: double.infinity,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryColor, _kPurple],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryColor.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: onReorder,
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.electric_moped_rounded,
                            color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Pesan Lagi',
                          style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              if (isDone)
                Expanded(
                  child: _SecondaryBtn(
                    icon: Icons.receipt_long_rounded,
                    label: 'Kwitansi',
                    color: _kGreen,
                    onTap: onReceipt,
                  ),
                ),
              if (isDone) const SizedBox(width: 10),
              Expanded(
                child: _SecondaryBtn(
                  icon: Icons.flag_outlined,
                  label: 'Laporkan',
                  color: _kRed,
                  onTap: onReport,
                ),
              ),
            ],
          ),
        ],
      );
}

class _SecondaryBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SecondaryBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
