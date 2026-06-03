import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../chat/screens/chat_history_screen.dart';

const _kGreen  = Color(0xFF00C896);
const _kOrange = Color(0xFFFF6B35);
const _kGold   = Color(0xFFFFB800);
const _kRed    = Color(0xFFFF4757);
const _kPurple = Color(0xFF6C5CE7);
const _kTeal   = Color(0xFF00CEC9);

class DriverActivityScreen extends ConsumerStatefulWidget {
  const DriverActivityScreen({super.key});

  @override
  ConsumerState<DriverActivityScreen> createState() => _ActivityState();
}

class _ActivityState extends ConsumerState<DriverActivityScreen>
    with TickerProviderStateMixin {
  late TabController       _tabCtrl;
  late AnimationController _entryCtrl;
  late AnimationController _statsCtrl;
  late Animation<double>   _entryFade;
  late Animation<Offset>   _entrySlide;

  final _dio = ApiClient.create();

  _ActivityStats? _stats;
  List<_TripItem> _trips   = [];
  bool            _loading = true;

  static const _emptyStats = _ActivityStats(
    totalRides: 0, completedRides: 0, cancelledRides: 0,
    totalEarnings: 0, totalDistanceKm: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _statsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));

    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _entryCtrl, curve: Curves.easeOutCubic));

    _entryCtrl.forward();
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _entryCtrl.dispose();
    _statsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([_fetchStats(), _fetchHistory()]);
    if (mounted) {
      setState(() => _loading = false);
      _statsCtrl.forward(from: 0);
    }
  }

  Future<void> _fetchStats() async {
    try {
      final r = await _dio.get('/drivers/activity-stats');
      if (!mounted || r.data is! Map) return;
      final d = Map<String, dynamic>.from(r.data as Map);
      setState(() => _stats = _ActivityStats(
        totalRides:       (d['totalRides']       as num?)?.toInt()    ?? 0,
        completedRides:   (d['completedRides']   as num?)?.toInt()    ?? 0,
        cancelledRides:   (d['cancelledRides']   as num?)?.toInt()    ?? 0,
        totalEarnings:    (d['totalEarnings']    as num?)?.toDouble() ?? 0,
        totalDistanceKm:  (d['totalDistanceKm']  as num?)?.toDouble() ?? 0,
      ));
    } catch (_) {
      if (mounted) setState(() => _stats = _emptyStats);
    }
  }

  Future<void> _fetchHistory() async {
    try {
      final r = await _dio.get('/drivers/history');
      final list = r.data is List ? r.data as List : <dynamic>[];
      if (!mounted) return;
      setState(() => _trips = list
          .map((d) => _TripItem.fromJson(Map<String, dynamic>.from(d as Map)))
          .toList());
    } catch (_) {
      if (mounted) setState(() => _trips = []);
    }
  }

  Future<void> _onRefresh() async {
    _statsCtrl.reset();
    setState(() => _loading = true);
    await _loadData();
  }

  void _showFilterSheet() {
    final sorts = ['Terbaru', 'Terlama', 'Penghasilan Tertinggi', 'Penghasilan Terendah'];
    String selected = sorts[0];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const Text('Urutkan',
                    style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Color(0xFF1F2937))),
                const SizedBox(height: 14),
                ...sorts.map((s) => GestureDetector(
                      onTap: () => setLocal(() => selected = s),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: selected == s
                              ? AppColors.primaryColor.withValues(alpha: 0.08)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: selected == s
                                  ? AppColors.primaryColor.withValues(alpha: 0.35)
                                  : Colors.grey.shade200),
                        ),
                        child: Row(children: [
                          Text(s,
                              style: TextStyle(
                                  fontFamily: 'Satoshi',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: selected == s
                                      ? AppColors.primaryColor
                                      : const Color(0xFF374151))),
                          const Spacer(),
                          if (selected == s)
                            const Icon(Icons.check_rounded,
                                color: AppColors.primaryColor, size: 18),
                        ]),
                      ),
                    )),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        if (selected == 'Terbaru') {
                          _trips.sort((a, b) => b.date.compareTo(a.date));
                        } else if (selected == 'Terlama') {
                          _trips.sort((a, b) => a.date.compareTo(b.date));
                        } else if (selected == 'Penghasilan Tertinggi') {
                          _trips.sort((a, b) => b.fare.compareTo(a.fare));
                        } else {
                          _trips.sort((a, b) => a.fare.compareTo(b.fare));
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Terapkan',
                        style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_TripItem> _filtered(String f) {
    if (f == 'DONE')      return _trips.where((t) => t.status == 'DONE').toList();
    if (f == 'CANCELLED') return _trips.where((t) => t.status == 'CANCELLED').toList();
    return _trips;
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats ?? _emptyStats;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2FF),
      body: FadeTransition(
        opacity: _entryFade,
        child: SlideTransition(
          position: _entrySlide,
          child: Column(
            children: [
              _GradientHeader(
                stats: stats,
                statsAnim: _statsCtrl,
                loading: _loading,
                onNotificationTap: () =>
                    Navigator.pushNamed(context, '/driver/notifications'),
                onFilterTap: _showFilterSheet,
              ),
              _ActivityTabBar(controller: _tabCtrl),
              Expanded(
                child: _loading
                    ? const _ShimmerList()
                    : TabBarView(
                        controller: _tabCtrl,
                        children: [
                          _TripListView(
                              trips: _filtered('ALL'), onRefresh: _onRefresh),
                          _TripListView(
                              trips: _filtered('DONE'), onRefresh: _onRefresh),
                          _TripListView(
                              trips: _filtered('CANCELLED'),
                              onRefresh: _onRefresh),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientHeader extends StatelessWidget {
  final _ActivityStats stats;
  final AnimationController statsAnim;
  final bool loading;
  final VoidCallback onNotificationTap;
  final VoidCallback? onFilterTap;

  const _GradientHeader({
    required this.stats,
    required this.statsAnim,
    required this.loading,
    required this.onNotificationTap,
    this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Row(
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.electric_moped_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Lungo',
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  _HeaderIconBtn(
                    icon: Icons.notifications_outlined,
                    onTap: onNotificationTap,
                  ),
                  const SizedBox(width: 8),
                  _HeaderIconBtn(icon: Icons.filter_list_rounded, onTap: onFilterTap),
                ],
              ),
              const SizedBox(height: 18),

              const Text(
                'Aktivitas Saya',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Rekap perjalanan & riwayat penghasilan',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 20),

              loading
                  ? _StatsShimmer()
                  : Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Perjalanan',
                            value: stats.totalRides.toDouble(),
                            suffix: 'x',
                            icon: Icons.electric_moped_rounded,
                            gradColors: const [
                              Color(0xFF0540F2),
                              Color(0xFF056CF2),
                            ],
                            anim: statsAnim,
                            isInt: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            label: 'Total Jarak',
                            value: stats.totalDistanceKm,
                            suffix: ' km',
                            icon: Icons.route_rounded,
                            gradColors: const [
                              Color(0xFF00C896),
                              Color(0xFF00BCD4),
                            ],
                            anim: statsAnim,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            label: 'Total Penghasilan',
                            value: stats.totalEarnings,
                            prefix: 'Rp ',
                            icon: Icons.payments_rounded,
                            gradColors: const [
                              Color(0xFFFF6B35),
                              Color(0xFFFFB800),
                            ],
                            anim: statsAnim,
                            isShortMoney: true,
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _HeaderIconBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      );
}

class _StatCard extends StatelessWidget {
  final String label;
  final double value;
  final String? prefix;
  final String? suffix;
  final IconData icon;
  final List<Color> gradColors;
  final AnimationController anim;
  final bool isInt;
  final bool isShortMoney;

  const _StatCard({
    required this.label,
    required this.value,
    this.prefix,
    this.suffix,
    required this.icon,
    required this.gradColors,
    required this.anim,
    this.isInt = false,
    this.isShortMoney = false,
  });

  String _format(double v) {
    if (isInt) return v.toInt().toString();
    if (isShortMoney) {
      if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}jt';
      if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}rb';
      return v.toStringAsFixed(0);
    }
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: anim,
        builder: (_, _) {
          final animated = anim.value * value;
          return Container(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: gradColors.first.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 18),
                const SizedBox(height: 6),
                Text(
                  '${prefix ?? ''}${_format(animated)}${suffix ?? ''}',
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _StatsShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: Colors.white.withValues(alpha: 0.15),
        highlightColor: Colors.white.withValues(alpha: 0.35),
        child: Row(
          children: List.generate(
            3,
            (i) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      );
}

class _ActivityTabBar extends StatelessWidget {
  final TabController controller;
  const _ActivityTabBar({required this.controller});

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F2FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: controller,
            indicator: BoxDecoration(
              color: AppColors.primaryColor,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryColor.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            tabs: const [
              Tab(text: 'Semua'),
              Tab(text: 'Selesai'),
              Tab(text: 'Dibatalkan'),
            ],
          ),
        ),
      );
}

class _TripListView extends StatelessWidget {
  final List<_TripItem> trips;
  final Future<void> Function() onRefresh;
  const _TripListView({required this.trips, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) return const _EmptyState();
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: trips.length,
        itemBuilder: (_, i) => _AnimatedTripCard(trip: trips[i], index: i),
      ),
    );
  }
}

class _AnimatedTripCard extends StatelessWidget {
  final _TripItem trip;
  final int index;
  const _AnimatedTripCard({required this.trip, required this.index});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 260 + index * 50),
        curve: Curves.easeOut,
        builder: (_, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - t)),
            child: child,
          ),
        ),
        child: _TripCard(trip: trip),
      );
}

class _TripCard extends StatelessWidget {
  final _TripItem trip;
  const _TripCard({required this.trip});

  static const _statusCfg = {
    'DONE':      (_kGreen,   Color(0xFFDCFCE7), Color(0xFF16A34A), 'Selesai'),
    'CANCELLED': (_kRed,     Color(0xFFFFE4E6), Color(0xFFDC2626), 'Dibatalkan'),
    'SEARCHING': (_kOrange,  Color(0xFFFFFBEB), Color(0xFFD97706), 'Mencari'),
    'ACCEPTED':  (_kPurple,  Color(0xFFEFF6FF), Color(0xFF2563EB), 'Diterima'),
    'PICKUP':    (_kTeal,    Color(0xFFEFF6FF), Color(0xFF0891B2), 'Jemput'),
    'ONGOING':   (_kGold,    Color(0xFFFFF7ED), Color(0xFFEA580C), 'Berjalan'),
  };

  void _showTripDetail(BuildContext context, _TripItem trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReceiptSheet(trip: trip),
    );
  }

  String _formatFare(double fare) {
    if (fare <= 0) return '-';
    final s = fare.toInt().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp $buf';
  }

  @override
  Widget build(BuildContext context) {
    final isDone      = trip.status == 'DONE';
    final isCancelled = trip.status == 'CANCELLED';
    final cfg = _statusCfg[trip.status] ?? _statusCfg['DONE']!;
    final accentGrad = isDone
        ? [_kGreen, _kTeal]
        : isCancelled
            ? [_kRed, _kOrange]
            : [AppColors.primaryColor, _kPurple];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cfg.$1.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              Container(
                width: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: accentGrad,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: accentGrad,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.person_rounded,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 10),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${trip.date}  •  ${trip.time}',
                                  style: const TextStyle(
                                    fontFamily: 'Satoshi',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                if (trip.passengerName != null) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.person_pin_circle_rounded,
                                          size: 11,
                                          color: Colors.grey.shade400),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          trip.passengerName!,
                                          style: const TextStyle(
                                            fontFamily: 'Satoshi',
                                            fontSize: 11,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: cfg.$2,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              cfg.$4,
                              style: TextStyle(
                                fontFamily: 'Satoshi',
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: cfg.$3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _RouteSection(from: trip.from, to: trip.to),
                      const SizedBox(height: 12),

                      const Divider(height: 1, color: Color(0xFFE5E7EB)),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          _InfoChip(
                            icon: Icons.route_rounded,
                            text: '${trip.distanceKm.toStringAsFixed(1)} km',
                            color: _kPurple,
                          ),
                          const SizedBox(width: 10),
                          _InfoChip(
                            icon: Icons.payments_rounded,
                            text: _formatFare(trip.fare),
                            color: isDone ? _kGreen : const Color(0xFF9CA3AF),
                          ),
                          const Spacer(),
                          if (isDone) ...[
                            _ActionBtn(
                              label: 'Chat',
                              icon: Icons.chat_bubble_outline_rounded,
                              primary: false,
                              gradColors: accentGrad,
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/chat-history',
                                arguments: ChatHistoryArgs(
                                  rideId: trip.id,
                                  title: trip.passengerName ?? 'Penumpang',
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _ActionBtn(
                              label: 'Detail',
                              icon: Icons.info_outline_rounded,
                              primary: false,
                              gradColors: accentGrad,
                              onTap: () => _showTripDetail(context, trip),
                            ),
                          ],
                        ],
                      ),

                      if (isCancelled) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE4E6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cancel_outlined,
                                  size: 13, color: _kRed),
                              SizedBox(width: 5),
                              Text(
                                'Perjalanan dibatalkan',
                                style: TextStyle(
                                  fontFamily: 'Satoshi',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _kRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteSection extends StatelessWidget {
  final String from;
  final String to;
  const _RouteSection({required this.from, required this.to});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                ...List.generate(
                  4,
                  (_) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    width: 2, height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                Container(
                  width: 10, height: 10,
                  decoration: const BoxDecoration(
                    color: _kOrange,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  from,
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 18),
                Text(
                  to,
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final List<Color> gradColors;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.primary,
    required this.gradColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              gradient: primary ? LinearGradient(colors: gradColors) : null,
              color: primary ? null : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 13,
                      color: primary ? Colors.white : AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: primary ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 110, height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0540F2), Color(0xFF6C5CE7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0540F2)
                                .withValues(alpha: 0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.route_outlined,
                          color: Colors.white, size: 44),
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: _kGold,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: _kGold.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.electric_moped_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Belum Ada Perjalanan',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Riwayat trip kamu akan\ntampil di sini setelah selesai bertugas',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 13,
                  height: 1.5,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
}

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: 4,
        itemBuilder: (_, _) => Shimmer.fromColors(
          baseColor: const Color(0xFFE5E7EB),
          highlightColor: const Color(0xFFF9FAFB),
          child: Container(
            height: 165,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(20)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                    width: 120, height: 10,
                                    color: Colors.grey.shade200),
                                const SizedBox(height: 6),
                                Container(
                                    width: 80, height: 10,
                                    color: Colors.grey.shade200),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                            width: double.infinity, height: 10,
                            color: Colors.grey.shade200),
                        const SizedBox(height: 8),
                        Container(
                            width: 160, height: 10,
                            color: Colors.grey.shade200),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ActivityStats {
  final int totalRides, completedRides, cancelledRides;
  final double totalEarnings, totalDistanceKm;

  const _ActivityStats({
    required this.totalRides,
    required this.completedRides,
    required this.cancelledRides,
    required this.totalEarnings,
    required this.totalDistanceKm,
  });
}

class _TripItem {
  final String id, date, time, from, to, status;
  final double fare, distanceKm;
  final String? passengerName;

  const _TripItem({
    required this.id,
    required this.date,
    required this.time,
    required this.from,
    required this.to,
    required this.status,
    required this.fare,
    required this.distanceKm,
    this.passengerName,
  });

  factory _TripItem.fromJson(Map<String, dynamic> j) => _TripItem(
        id:            j['id']            as String? ?? '',
        date:          j['date']          as String? ?? '',
        time:          j['time']          as String? ?? '',
        from:          j['from']          as String? ?? 'Asal',
        to:            j['to']            as String? ?? 'Tujuan',
        status:        j['status']        as String? ?? 'DONE',
        fare:          (j['fare']         as num?)?.toDouble() ?? 0,
        distanceKm:    (j['distanceKm']   as num?)?.toDouble() ?? 0,
        passengerName: j['passengerName'] as String?,
      );
}

String _fmtFare(double fare) {
  if (fare <= 0) return '-';
  final s = fare.toInt().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return 'Rp $buf';
}

class _ReceiptSheet extends StatefulWidget {
  final _TripItem trip;
  const _ReceiptSheet({required this.trip});

  @override
  State<_ReceiptSheet> createState() => _ReceiptSheetState();
}

class _ReceiptSheetState extends State<_ReceiptSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _scale = CurvedAnimation(parent: _anim, curve: Curves.elasticOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final shortId = trip.id.length > 8
        ? trip.id.substring(0, 8).toUpperCase()
        : trip.id.toUpperCase();
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0B0940), Color(0xFF04198C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: 70, height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.13),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35), width: 2),
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: Color(0xFF4ADE80), size: 34),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Kwitansi Perjalanan',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: #$shortId  •  ${trip.date}  ${trip.time}',
                  style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.65)),
                ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + bottom),
            child: Column(
              children: [

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF0FFF4), Color(0xFFDCFCE7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: _kGreen.withValues(alpha: 0.3), width: 1.2),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Total Penghasilan',
                        style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 12,
                            color: Color(0xFF16A34A)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _fmtFare(trip.fare),
                        style: const TextStyle(
                          fontFamily: 'Satoshi',
                          fontWeight: FontWeight.w900,
                          fontSize: 30,
                          color: Color(0xFF15803D),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                Row(children: [
                  _ReceiptStat(
                    icon: Icons.route_rounded,
                    label: 'Jarak',
                    value: '${trip.distanceKm.toStringAsFixed(1)} km',
                    color: _kTeal,
                  ),
                  const SizedBox(width: 10),
                  _ReceiptStat(
                    icon: Icons.person_rounded,
                    label: 'Penumpang',
                    value: trip.passengerName ?? 'Penumpang',
                    color: _kPurple,
                  ),
                ]),

                const SizedBox(height: 14),

                Row(
                  children: List.generate(
                    30,
                    (i) => Expanded(
                      child: Container(
                        height: 1.5,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        color: i.isEven
                            ? const Color(0xFFD1D5DB)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                _ReceiptRouteRow(
                  icon: Icons.my_location_rounded,
                  label: 'Asal',
                  text: trip.from,
                  color: AppColors.primaryColor,
                  isTop: true,
                ),
                Container(
                    width: 2, height: 14,
                    margin: const EdgeInsets.only(left: 12),
                    color: const Color(0xFFE5E7EB)),
                _ReceiptRouteRow(
                  icon: Icons.location_on_rounded,
                  label: 'Tujuan',
                  text: trip.to,
                  color: _kOrange,
                  isTop: false,
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(
                          fontFamily: 'Satoshi',
                          fontWeight: FontWeight.w800,
                          fontSize: 15),
                    ),
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

class _ReceiptStat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _ReceiptStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 10,
                            color: color.withValues(alpha: 0.7))),
                    Text(value,
                        style: const TextStyle(
                            fontFamily: 'Satoshi',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Color(0xFF1F2937)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _ReceiptRouteRow extends StatelessWidget {
  final IconData icon;
  final String label, text;
  final Color color;
  final bool isTop;
  const _ReceiptRouteRow({
    required this.icon,
    required this.label,
    required this.text,
    required this.color,
    required this.isTop,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isTop ? 12 : 0),
            topRight: Radius.circular(isTop ? 12 : 0),
            bottomLeft: Radius.circular(isTop ? 0 : 12),
            bottomRight: Radius.circular(isTop ? 0 : 12),
          ),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 13),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 10,
                          color: color.withValues(alpha: 0.7))),
                  Text(text,
                      style: const TextStyle(
                          fontFamily: 'Satoshi',
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Color(0xFF1F2937)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      );
}
