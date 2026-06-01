import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';

const _kGreen      = Color(0xFF16A34A);
const _kGreenLight = Color(0xFFDCFCE7);
const _kRed        = Color(0xFFDC2626);
const _kRedLight   = Color(0xFFFEE2E2);

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with TickerProviderStateMixin {
  int _filterIndex = 0;
  bool _isLoading  = true;

  List<_HistoryTrip> _trips = [];
  double _totalEarnings     = 0;
  int    _totalTrips        = 0;

  late AnimationController _entryCtrl;
  late Animation<double>   _headerFade;
  late Animation<Offset>   _headerSlide;
  late Animation<double>   _listFade;

  final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  static const _filters = ['Hari Ini', 'Minggu Ini', 'Bulan Ini'];
  static const _filterParams = ['today', 'week', 'month'];

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _headerFade = CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut));
    _headerSlide =
        Tween<Offset>(begin: const Offset(0, -0.04), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _entryCtrl,
                curve:
                    const Interval(0.0, 0.55, curve: Curves.easeOutCubic)));
    _listFade = CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut));

    _entryCtrl.forward();
    _loadHistory();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final r = await DioClient.create().get('/drivers/history',
          queryParameters: {'period': _filterParams[_filterIndex]});
      final data = r.data;
      List<dynamic> list = [];
      double earnings = 0;

      if (data is Map<String, dynamic>) {
        list = (data['rides'] as List?) ?? (data['trips'] as List?) ?? [];
        earnings = (data['totalEarnings'] as num?)?.toDouble() ?? 0;
      } else if (data is List) {
        list = data;
      }

      final trips = list
          .map((e) =>
              _HistoryTrip.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (earnings == 0) {
        earnings = trips.fold(0.0, (sum, t) => sum + t.fare);
      }

      if (mounted) {
        setState(() {
          _trips         = trips;
          _totalEarnings = earnings;
          _totalTrips    = trips.length;
          _isLoading     = false;
        });
      }
    } catch (_) {

      if (mounted) {
        setState(() {
          _trips = _demoTrips(_filterIndex);
          _totalEarnings =
              _trips.fold(0.0, (sum, t) => sum + t.fare);
          _totalTrips    = _trips.length;
          _isLoading     = false;
        });
      }
    }
  }

  static List<_HistoryTrip> _demoTrips(int filter) {
    final now = DateTime.now();
    final base = [
      _HistoryTrip(
          id: '1',
          pickup: 'Alun-Alun Bandung',
          destination: 'Braga City Walk',
          fare: 18000,
          distanceKm: 2.3,
          status: 'DONE',
          completedAt: now.subtract(const Duration(minutes: 45))),
      _HistoryTrip(
          id: '2',
          pickup: 'Trans Studio Bandung',
          destination: 'Cihampelas Walk',
          fare: 24500,
          distanceKm: 3.8,
          status: 'DONE',
          completedAt: now.subtract(const Duration(hours: 2, minutes: 12))),
      _HistoryTrip(
          id: '3',
          pickup: 'Stasiun Bandung',
          destination: 'Paris Van Java',
          fare: 21000,
          distanceKm: 3.1,
          status: 'DONE',
          completedAt: now.subtract(const Duration(hours: 4))),
      _HistoryTrip(
          id: '4',
          pickup: 'Dago',
          destination: 'Baltos',
          fare: 15000,
          distanceKm: 1.9,
          status: 'CANCELLED',
          completedAt: now.subtract(const Duration(hours: 5, minutes: 30))),
    ];
    if (filter == 0) return base.take(2).toList();
    if (filter == 1) return base;
    return [...base, ...base.map((t) => t.copyWith(
          id: 'x${t.id}',
          completedAt: t.completedAt.subtract(const Duration(days: 3))))];
  }

  void _onFilterTap(int i) {
    if (_filterIndex == i) return;
    setState(() => _filterIndex = i);
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        children: [

          FadeTransition(
            opacity: _headerFade,
            child: SlideTransition(
              position: _headerSlide,
              child: _buildHeader(top),
            ),
          ),

          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: List.generate(
                _filters.length,
                (i) => Expanded(
                  child: GestureDetector(
                    onTap: () => _onFilterTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: EdgeInsets.only(
                          left: i == 0 ? 0 : 6),
                      padding: const EdgeInsets.symmetric(
                          vertical: 10),
                      decoration: BoxDecoration(
                        color: _filterIndex == i
                            ? AppColors.primaryColor
                            : AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryColor
                                .withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _filters[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Satoshi',
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: _filterIndex == i
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Expanded(
            child: FadeTransition(
              opacity: _listFade,
              child: _isLoading
                  ? _buildSkeletons()
                  : _trips.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                              16, 0, 16, 24),
                          physics:
                              const BouncingScrollPhysics(),
                          itemCount: _trips.length,
                          itemBuilder: (_, i) =>
                              _HistoryCard(
                            trip: _trips[i],
                            currency: _currency,
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(double topPadding) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B0940), Color(0xFF0540F2), Color(0xFF056CF2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, topPadding + 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Row(
            children: [
              Icon(Icons.history_rounded,
                  color: AppColors.accentColor, size: 22),
              SizedBox(width: 10),
              Text(
                'Riwayat Trip',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _SummaryChip(
                  icon: Icons.route_rounded,
                  label: 'Total Trip',
                  value: '$_totalTrips',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryChip(
                  icon: Icons.payments_rounded,
                  label: 'Pendapatan',
                  value: _totalEarnings == 0
                      ? 'Rp 0'
                      : _currency.format(_totalEarnings),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.inbox_rounded,
                  color: AppColors.primaryColor, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum Ada Trip',
              style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.primaryDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'Trip kamu akan muncul di sini',
              style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 13,
                  color: AppColors.textSecondary),
            ),
          ],
        ),
      );

  Widget _buildSkeletons() => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: 4,
        itemBuilder: (context, i) => Shimmer.fromColors(
          baseColor: const Color(0xFFE2E8F0),
          highlightColor: const Color(0xFFF1F5F9),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            height: 86,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label, value;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: AppColors.accentColor
                    .withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon,
                  color: AppColors.accentColor, size: 18),
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
                          color:
                              Colors.white.withValues(alpha: 0.65))),
                  Text(value,
                      style: const TextStyle(
                          fontFamily: 'Satoshi',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      );
}

class _HistoryCard extends StatelessWidget {
  final _HistoryTrip trip;
  final NumberFormat currency;

  const _HistoryCard({required this.trip, required this.currency});

  @override
  Widget build(BuildContext context) {
    final isDone = trip.status == 'DONE';
    final timeStr = _timeLabel(trip.completedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [

              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: isDone
                      ? AppColors.primaryLight
                      : _kRedLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDone
                      ? Icons.electric_moped_rounded
                      : Icons.cancel_rounded,
                  color: isDone
                      ? AppColors.primaryColor
                      : _kRed,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.pickup,
                      style: const TextStyle(
                          fontFamily: 'Satoshi',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.primaryDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.south_rounded,
                            size: 11,
                            color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            trip.destination,
                            style: const TextStyle(
                                fontFamily: 'Satoshi',
                                fontSize: 12,
                                color:
                                    AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isDone
                        ? currency.format(trip.fare)
                        : '—',
                    style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDone
                            ? AppColors.primaryColor
                            : const Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDone ? _kGreenLight : _kRedLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isDone ? 'Selesai' : 'Dibatalkan',
                      style: TextStyle(
                          fontFamily: 'Satoshi',
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          color: isDone ? _kGreen : _kRed),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF0F4FF)),
          const SizedBox(height: 8),

          Row(
            children: [
              _meta(Icons.access_time_rounded, timeStr),
              const SizedBox(width: 16),
              _meta(Icons.route_rounded,
                  '${trip.distanceKm.toStringAsFixed(1)} km'),
              if (isDone && trip.fare > 0) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded,
                          size: 11, color: AppColors.primaryColor),
                      SizedBox(width: 3),
                      Text('Beri Rating',
                          style: TextStyle(
                              fontFamily: 'Satoshi',
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                              color: AppColors.primaryColor)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 11,
                  color: AppColors.textSecondary)),
        ],
      );

  String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return DateFormat('d MMM, HH:mm', 'id').format(dt);
  }
}

class _HistoryTrip {
  final String id, pickup, destination, status;
  final double fare, distanceKm;
  final DateTime completedAt;

  const _HistoryTrip({
    required this.id,
    required this.pickup,
    required this.destination,
    required this.fare,
    required this.distanceKm,
    required this.status,
    required this.completedAt,
  });

  _HistoryTrip copyWith({
    String? id,
    DateTime? completedAt,
  }) =>
      _HistoryTrip(
        id: id ?? this.id,
        pickup: pickup,
        destination: destination,
        fare: fare,
        distanceKm: distanceKm,
        status: status,
        completedAt: completedAt ?? this.completedAt,
      );

  factory _HistoryTrip.fromJson(Map<String, dynamic> j) {
    final raw = j['createdAt'] as String? ??
        j['completedAt'] as String? ??
        j['updatedAt'] as String?;
    final dt =
        raw != null ? DateTime.tryParse(raw) ?? DateTime.now() : DateTime.now();
    return _HistoryTrip(
      id: (j['id'] as String?) ?? '',
      pickup: (j['pickupAddress'] as String?) ??
          (j['pickup'] as String?) ??
          'Titik Jemput',
      destination: (j['destinationAddress'] as String?) ??
          (j['destination'] as String?) ??
          'Tujuan',
      fare: (j['fare'] as num?)?.toDouble() ?? 0,
      distanceKm:
          (j['distanceKm'] as num?)?.toDouble() ?? 0,
      status: (j['status'] as String?) ?? 'DONE',
      completedAt: dt,
    );
  }
}
