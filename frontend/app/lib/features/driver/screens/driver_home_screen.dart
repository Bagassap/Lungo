import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lungo_snackbar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/providers/nav_tab_provider.dart';
import '../providers/driver_provider.dart';
import '../providers/driver_chat_provider.dart';

final _idrFmt =
    NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeState();
}

class _DriverHomeState extends ConsumerState<DriverHomeScreen>
    with TickerProviderStateMixin {
  final _map = MapController();
  static const _bandung = LatLng(-6.9175, 107.6191);
  LatLng _pos = _bandung;

  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _requestCtrl;
  late Animation<double> _topFade;
  late Animation<Offset> _topSlide;
  late Animation<double> _bottomFade;
  late Animation<Offset> _bottomSlide;
  late Animation<double> _pulse;

  Timer? _requestTimer;
  int _requestSecs = 30;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _requestCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));

    _topFade = CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut));
    _topSlide =
        Tween<Offset>(begin: const Offset(0, -0.06), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _entryCtrl,
                curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic)));

    _bottomFade = CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.2, 0.9, curve: Curves.easeOut));
    _bottomSlide =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _entryCtrl,
                curve: const Interval(0.2, 0.9, curve: Curves.easeOutCubic)));

    _pulse = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _pulseCtrl.repeat(reverse: true);
    _entryCtrl.forward();
    _initGps();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(driverProvider.notifier).checkStaleState();
      _checkSubscription();
      final pendingAccept = FcmService.consumePendingDriverAccept();
      if (pendingAccept != null) {
        ref.read(driverProvider.notifier).acceptRideFromNotification(pendingAccept);
      }
    });
  }

  Future<void> _checkSubscription() async {
    final active = await SecureStorage.isSubscriptionActive();
    if (!active && mounted) {
      Navigator.pushNamed(context, '/driver/subscription');
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _requestCtrl.dispose();
    _requestTimer?.cancel();
    super.dispose();
  }

  Future<void> _initGps() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        if (mounted) {
          setState(() => _pos = LatLng(p.latitude, p.longitude));
          try { _map.move(_pos, 16); } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> _showCancelApprovalDialog(BuildContext ctx, DriverNotifier notifier) async {
    final approved = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
          const SizedBox(width: 8),
          Text('Permintaan Pembatalan',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        content: Text(
          'Penumpang ingin membatalkan pesanan ini.\nApakah kamu menyetujui pembatalan?',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: Text('Tolak', style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600, color: AppColors.primaryColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dlgCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('Setuju, Batalkan',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (approved == true) {
      await notifier.approveCancel();
    } else {
      notifier.rejectCancel();
    }
  }

  void _startRequestTimer() {
    _requestSecs = 30;
    _requestTimer?.cancel();
    _requestTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _requestSecs--);
      if (_requestSecs <= 0) {
        t.cancel();
        ref.read(driverProvider.notifier).rejectRide();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user     = ref.watch(authProvider).user;
    final name     = user?.name ?? 'Driver';
    final ds       = ref.watch(driverProvider);
    final notifier = ref.read(driverProvider.notifier);
    final isOnline = ds.isOnline;

    ref.listen<DriverState>(driverProvider, (prev, next) {
      if (next.phase == DriverRidePhase.request &&
          prev?.phase != DriverRidePhase.request) {
        _requestCtrl.forward(from: 0);
        _startRequestTimer();
      } else if (prev?.phase == DriverRidePhase.request &&
          next.phase != DriverRidePhase.request) {
        _requestCtrl.reverse();
        _requestTimer?.cancel();
      }
      if (next.phase == DriverRidePhase.navigating &&
          prev?.phase != DriverRidePhase.navigating &&
          next.activeTrip != null) {
        final rideId = next.activeTrip!.rideId;
        final passengerName = next.activeTrip!.passengerName;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(driverChatProvider.notifier).connect(
              rideId,
              passengerName: passengerName,
            );
          }
        });
      }

      if (prev != null && !prev.cancelRequested && next.cancelRequested) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showCancelApprovalDialog(context, ref.read(driverProvider.notifier));
        });
      }
      if (next.position != null && next.position != prev?.position) {
        if (mounted) {
          setState(() => _pos = next.position!);
          _map.move(next.position!, 16);
        }
      }
      if (prev != null && prev.isOnline != next.isOnline && mounted) {
        if (next.isOnline) {
          LungoSnackbar.success(context, 'Kamu sekarang online');
        } else {
          LungoSnackbar.warning(context, 'Kamu offline');
        }
      }
    });

    return Scaffold(
      body: Stack(
        children: [

          RepaintBoundary(
            child: _DriverMap(
              pos: _pos,
              isOnline: isOnline,
              phase: ds.phase,
              pendingReq: ds.pendingRequest,
              activeTrip: ds.activeTrip,
              routePoints: ds.routePoints,
              mapCtrl: _map,
              passengerPosition: ds.passengerPosition,
            ),
          ),

          Positioned(
            top: 0, left: 0, right: 0,
            child: FadeTransition(
              opacity: _topFade,
              child: SlideTransition(
                position: _topSlide,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(
                      name: name,
                      isOnline: isOnline,
                      onAvatarTap: () =>
                          ref.read(navTabProvider.notifier).state = 3,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _StatusBar(
                        isOnline: isOnline,
                        todayEarnings: ds.todayEarnings,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (ds.phase == DriverRidePhase.idle)
            Positioned(
              bottom: 368, left: 0, right: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: isOnline ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, child) =>
                        Transform.scale(scale: _pulse.value, child: child),
                    child: _OnlineBadge(todayTrips: ds.todayTrips),
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 0, left: 0, right: 0,
            child: FadeTransition(
              opacity: _bottomFade,
              child: SlideTransition(
                position: _bottomSlide,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, anim) => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.12),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: (ds.phase == DriverRidePhase.navigating ||
                          ds.phase == DriverRidePhase.atPickup ||
                          ds.phase == DriverRidePhase.onTrip)
                      ? _ActiveTripBar(
                          key: const ValueKey('active'),
                          ds: ds,
                          onArrivedAtPickup: notifier.arrivedAtPickup,
                          onStartTrip: notifier.startTrip,
                          onEndTrip: notifier.endTrip,
                          onCancelRide: notifier.cancelRide,
                        )
                      : _DriverBottomSheet(
                          key: const ValueKey('idle'),
                          ds: ds,
                          onToggle: () => isOnline
                              ? notifier.goOffline()
                              : notifier.goOnline(),
                        ),
                ),
              ),
            ),
          ),

          if (ds.phase == DriverRidePhase.request)
            Positioned.fill(
              child: _RequestNotificationCard(
                key: const ValueKey('request'),
                req: ds.pendingRequest!,
                secs: _requestSecs,
                onAccept: notifier.acceptRide,
                onReject: notifier.rejectRide,
              ),
            ),

          if (ds.phase == DriverRidePhase.completed)
            Positioned.fill(
              child: _CompletedOverlay(
                ds: ds,
                onClose: notifier.clearCompleted,
              ),
            ),
        ],
      ),
    );
  }
}

class _DriverMap extends StatelessWidget {
  final LatLng pos;
  final bool isOnline;
  final DriverRidePhase phase;
  final DriverRideRequest? pendingReq;
  final DriverTrip? activeTrip;
  final List<LatLng> routePoints;
  final MapController mapCtrl;
  final LatLng? passengerPosition;
  const _DriverMap({
    required this.pos,
    required this.isOnline,
    required this.phase,
    required this.routePoints,
    required this.mapCtrl,
    this.pendingReq,
    this.activeTrip,
    this.passengerPosition,
  });

  @override
  Widget build(BuildContext context) {
    final isNavigating = phase == DriverRidePhase.navigating;
    final isAtPickup   = phase == DriverRidePhase.atPickup;
    final isOnTrip     = phase == DriverRidePhase.onTrip;
    final hasRoute     = routePoints.length >= 2;

    int closestIdx = 0;
    if (hasRoute && isOnTrip) {
      double minDist = double.infinity;
      for (int i = 0; i < routePoints.length; i++) {
        final d = Geolocator.distanceBetween(
            pos.latitude, pos.longitude,
            routePoints[i].latitude, routePoints[i].longitude);
        if (d < minDist) {
          minDist = d;
          closestIdx = i;
        }
      }
    }
    final traveledPts = (isOnTrip && closestIdx > 0)
        ? routePoints.sublist(0, closestIdx + 1)
        : <LatLng>[];
    final remainingPts = (isOnTrip && hasRoute)
        ? routePoints.sublist(closestIdx)
        : routePoints;

    return FlutterMap(
      mapController: mapCtrl,
      options: MapOptions(
        initialCenter: pos,
        initialZoom: 16,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: ApiConstants.hereTileUrl,
          userAgentPackageName: 'com.lungo.lungo_app',
          maxNativeZoom: 19,
          maxZoom: 19,
        ),

        PolylineLayer(polylines: [

          if (isNavigating && activeTrip != null)
            Polyline(
              points: hasRoute
                  ? routePoints
                  : [pos, LatLng(activeTrip!.originLat, activeTrip!.originLng)],
              strokeWidth: 5,
              color: AppColors.primaryColor.withValues(alpha: 0.75),
            ),

          if (isAtPickup && activeTrip != null && activeTrip!.hasDestination)
            Polyline(
              points: hasRoute
                  ? routePoints
                  : [pos, LatLng(activeTrip!.destinationLat, activeTrip!.destinationLng)],
              strokeWidth: 5,
              color: AppColors.online.withValues(alpha: 0.6),
            ),

          if (isOnTrip && activeTrip != null && activeTrip!.hasDestination) ...[
            if (traveledPts.length >= 2)
              Polyline(
                points: traveledPts,
                strokeWidth: 5,
                color: Colors.grey.withValues(alpha: 0.55),
              ),
            Polyline(
              points: hasRoute
                  ? (remainingPts.length >= 2 ? remainingPts : routePoints)
                  : [pos, LatLng(activeTrip!.destinationLat, activeTrip!.destinationLng)],
              strokeWidth: 5,
              color: AppColors.primaryColor.withValues(alpha: 0.85),
            ),
          ],

          if (pendingReq != null)
            Polyline(
              points: [pos, LatLng(pendingReq!.originLat, pendingReq!.originLng)],
              strokeWidth: 4,
              color: AppColors.primaryColor.withValues(alpha: 0.5),
            ),
        ]),

        MarkerLayer(markers: [

          Marker(
            point: pos, width: 56, height: 56,
            child: Container(
              decoration: BoxDecoration(
                color: isOnline ? AppColors.online : AppColors.offline,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: (isOnline ? AppColors.online : AppColors.offline)
                        .withValues(alpha: 0.5),
                    blurRadius: 14, spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.electric_moped_rounded,
                  color: Colors.white, size: 26),
            ),
          ),

          if (pendingReq != null)
            Marker(
              point: LatLng(pendingReq!.originLat, pendingReq!.originLng),
              width: 42, height: 42,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.person_pin_circle_rounded,
                    color: Colors.white, size: 20),
              ),
            ),

          if ((isNavigating || isAtPickup) && activeTrip != null)
            Marker(
              point: passengerPosition ?? LatLng(activeTrip!.originLat, activeTrip!.originLng),
              width: 44, height: 44,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryColor.withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.person_pin_circle_rounded,
                    color: Colors.white, size: 22),
              ),
            ),

          if (activeTrip != null && activeTrip!.hasDestination)
            Marker(
              point: LatLng(activeTrip!.destinationLat, activeTrip!.destinationLng),
              width: 44, height: 44,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.accentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryDark, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentColor.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.location_on_rounded,
                    color: AppColors.primaryDark, size: 22),
              ),
            ),
        ]),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final String name;
  final bool isOnline;
  final VoidCallback onAvatarTap;
  const _TopBar({
    required this.name,
    required this.isOnline,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0540F2), Color(0xFF04198C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x440540F2),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(
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
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isOnline ? 'ONLINE' : 'OFFLINE',
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 0.5,
                        color: isOnline ? AppColors.online : Colors.white60,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onAvatarTap,
                    child: CircleAvatar(
                      radius: 19,
                      backgroundColor: Colors.white.withValues(alpha: 0.22),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontFamily: 'Satoshi',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: isOnline ? AppColors.online : Colors.white38,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isOnline ? Colors.white : Colors.white60,
                    ),
                    child: Text(
                      isOnline
                          ? 'Online — Siap menerima pesanan'
                          : 'Offline — Tidak menerima pesanan',
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

class _StatusBar extends StatelessWidget {
  final bool isOnline;
  final double todayEarnings;
  const _StatusBar({required this.isOnline, required this.todayEarnings});

  @override
  Widget build(BuildContext context) => Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryColor.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: isOnline ? AppColors.online : AppColors.offline,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isOnline
                    ? 'Menunggu pesanan masuk...'
                    : 'Aktifkan ojek untuk mulai',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 14,
                  color: isOnline
                      ? AppColors.textPrimary
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ),
            if (todayEarnings > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.online.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _idrFmt.format(todayEarnings),
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: AppColors.online,
                  ),
                ),
              ),
          ],
        ),
      );
}

class _OnlineBadge extends StatelessWidget {
  final int todayTrips;
  const _OnlineBadge({required this.todayTrips});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.accentColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentColor.withValues(alpha: 0.55),
              blurRadius: 14, spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.electric_moped_rounded,
                color: AppColors.primaryDark, size: 15),
            const SizedBox(width: 6),
            Text(
              todayTrips > 0
                  ? '$todayTrips Trip Hari Ini'
                  : 'Kamu Sedang Online',
              style: const TextStyle(
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      );
}

class _DriverBottomSheet extends StatelessWidget {
  final DriverState ds;
  final VoidCallback onToggle;
  const _DriverBottomSheet(
      {super.key, required this.ds, required this.onToggle});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A0540F2),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              _ToggleButton(
                isOnline: ds.isOnline,
                isLoading: ds.isLoading,
                onTap: onToggle,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  _StatCard(
                    label: 'Perjalanan',
                    value: '${ds.todayTrips}',
                    icon: Icons.route_rounded,
                    color: AppColors.primaryColor,
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    label: 'Pendapatan',
                    value: _idrFmt.format(ds.todayEarnings),
                    icon: Icons.payments_rounded,
                    color: AppColors.online,
                    flex: 2,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _StatCard(
                    label: 'Kilometer',
                    value: '${ds.todayKm.toStringAsFixed(1)} km',
                    icon: Icons.speed_rounded,
                    color: AppColors.secondaryColor,
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    label: 'Rating',
                    value: ds.rating.toStringAsFixed(1),
                    icon: Icons.star_rounded,
                    color: const Color(0xFFF59E0B),
                  ),
                ],
              ),

              if (ds.todayTarget > 0) ...[
                const SizedBox(height: 14),
                _TargetBar(
                    earned: ds.todayEarnings, target: ds.todayTarget),
              ],

            ],
          ),
        ),
      );
}

class _ToggleButton extends StatefulWidget {
  final bool isOnline;
  final bool isLoading;
  final VoidCallback onTap;
  const _ToggleButton({
    required this.isOnline,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends State<_ToggleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.isOnline ? 'Sedang Online' : 'Aktifkan Ojek';
    final sublabel = widget.isOnline
        ? 'Ketuk untuk berhenti menerima pesanan'
        : 'Mulai terima pesanan penumpang';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (!widget.isLoading) widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: Duration(milliseconds: _pressed ? 80 : 350),
        curve: _pressed ? Curves.easeIn : Curves.elasticOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: widget.isOnline
                ? LinearGradient(
                    colors: [
                      AppColors.online,
                      AppColors.online.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF0540F2), Color(0xFF04198C)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (widget.isOnline
                        ? AppColors.online
                        : const Color(0xFF0540F2))
                    .withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: widget.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Icon(Icons.electric_moped_rounded,
                        color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sublabel,
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2CB05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.isOnline
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: const Color(0xFF04198C),
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final int flex;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.flex = 1,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _TargetBar extends StatelessWidget {
  final double earned, target;
  const _TargetBar({required this.earned, required this.target});

  @override
  Widget build(BuildContext context) {
    final pct = (earned / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Target Harian',
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '${(pct * 100).toInt()}% · ${_idrFmt.format(target)}',
              style: const TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: AppColors.primaryLight,
            valueColor: AlwaysStoppedAnimation<Color>(
              pct >= 1.0 ? AppColors.online : AppColors.primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _RequestNotificationCard extends StatefulWidget {
  final DriverRideRequest req;
  final int secs;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const _RequestNotificationCard({
    super.key,
    required this.req,
    required this.secs,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_RequestNotificationCard> createState() =>
      _RequestNotificationCardState();
}

class _RequestNotificationCardState
    extends State<_RequestNotificationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final passengerName = widget.req.passengerName?.isNotEmpty == true
        ? widget.req.passengerName!
        : 'Penumpang';

    final initial = passengerName.isNotEmpty ? passengerName[0].toUpperCase() : 'P';
    final isUrgent = widget.secs <= 10;

    return Stack(
      children: [

        Positioned.fill(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: const Color(0xFF0A1628).withValues(alpha: 0.72),
              ),
            ),
          ),
        ),

        Positioned.fill(
          child: Center(
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1A237E).withValues(alpha: 0.35),
                        blurRadius: 40,
                        spreadRadius: 2,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(isUrgent),
                        _buildBody(passengerName, initial, isUrgent),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isUrgent) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1B4B), Color(0xFF1565C0)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(right: -8, top: -16, child: _circle(80, 0.06)),
          Positioned(right: 30, bottom: -24, child: _circle(45, 0.05)),
          Positioned(left: 100, top: -10, child: _circle(30, 0.04)),
          Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.6),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.directions_bike_rounded,
                    color: Color(0xFF0D1B4B), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pesanan Masuk!',
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      'Terima dalam waktu terbatas',
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 48, height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUrgent
                      ? Colors.red.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.1),
                  border: Border.all(
                    color: isUrgent ? Colors.red.shade300 : const Color(0xFFFFB300),
                    width: 2.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${widget.secs}',
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      color: isUrgent ? Colors.red.shade200 : Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(String passengerName, String initial, bool isUrgent) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildPassengerInfo(passengerName, initial),
          const SizedBox(height: 10),
          _buildRoute(),
          const SizedBox(height: 10),
          _buildStats(),
          const SizedBox(height: 14),
          _buildButtons(),
        ],
      ),
    );
  }

  Widget _buildPassengerInfo(String passengerName, String initial) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFB300), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF1A237E),
              child: Text(
                initial,
                style: const TextStyle(
                  fontFamily: 'Satoshi',
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passengerName,
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF0D1B4B),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFFFB300), size: 13),
                    const SizedBox(width: 3),
                    Text(
                      widget.req.passengerRating.toStringAsFixed(1),
                      style: TextStyle(
                          fontFamily: 'Satoshi',
                          color: Colors.grey[600],
                          fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF2979FF)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A237E).withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              _idrFmt.format(widget.req.estimatedFare),
              style: const TextStyle(
                fontFamily: 'Satoshi',
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoute() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE8EAF6), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 9, height: 9,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A237E),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A237E).withValues(alpha: 0.5),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.req.originAddress ?? 'Titik penjemputan',
                  style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 12,
                      color: Colors.grey[700]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 3, top: 2, bottom: 2),
            child: Container(
              width: 3, height: 16,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1A237E).withValues(alpha: 0.3),
                    const Color(0xFFFFB300).withValues(alpha: 0.3),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  color: Color(0xFFFFB300), size: 13),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.req.destinationAddress?.isNotEmpty == true
                      ? widget.req.destinationAddress!
                      : 'Tujuan tidak diset',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem(Icons.route_rounded,
              '${widget.req.distanceKm.toStringAsFixed(1)} km', 'jarak'),
          Container(width: 1, height: 40, color: const Color(0xFFE8EAF6)),
          _statItem(Icons.account_balance_wallet_rounded,
              _idrFmt.format(widget.req.estimatedFare), 'estimasi'),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF1A237E).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF2979FF), size: 18),
        ),
        const SizedBox(height: 5),
        Text(value,
            style: const TextStyle(
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D1B4B),
                fontSize: 12)),
        Text(label,
            style: TextStyle(
                fontFamily: 'Satoshi',
                color: Colors.grey[500],
                fontSize: 10)),
      ],
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: OutlinedButton(
            onPressed: widget.onReject,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red, width: 1.5),
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13)),
            ),
            child: const Text('Tolak',
                style: TextStyle(
                    fontFamily: 'Satoshi', fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 5,
          child: ElevatedButton(
            onPressed: widget.onAccept,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 6,
              shadowColor: const Color(0xFF1A237E).withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_bike_rounded, size: 17),
                SizedBox(width: 7),
                Text('Mulai Penjemputan',
                    style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _circle(double size, double opacity) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class _TripPhaseSteps extends StatelessWidget {
  final bool isNavigating, isAtPickup, isOnTrip;
  const _TripPhaseSteps({
    required this.isNavigating,
    required this.isAtPickup,
    required this.isOnTrip,
  });

  @override
  Widget build(BuildContext context) {
    final steps = [
      (label: 'Jemput', icon: Icons.electric_moped_rounded, done: true),
      (label: 'Tiba',   icon: Icons.location_on_rounded,    done: isAtPickup || isOnTrip),
      (label: 'Jalan',  icon: Icons.navigation_rounded,     done: isOnTrip),
    ];
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final done = steps[(i - 1) ~/ 2].done;
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: done ? AppColors.primaryColor : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          );
        }
        final step   = steps[i ~/ 2];
        final isCurr = (i == 0 && isNavigating) ||
                       (i == 2 && isAtPickup)    ||
                       (i == 4 && isOnTrip);
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: step.done ? AppColors.primaryColor : AppColors.primaryLight,
              shape: BoxShape.circle,
              boxShadow: isCurr
                  ? [BoxShadow(
                      color: AppColors.primaryColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                    )]
                  : null,
            ),
            child: Icon(step.icon,
                color: step.done ? Colors.white : AppColors.textSecondary, size: 16),
          ),
          const SizedBox(height: 4),
          Text(step.label, style: TextStyle(
            fontFamily: 'Satoshi', fontSize: 10, fontWeight: FontWeight.w600,
            color: step.done ? AppColors.primaryColor : AppColors.textSecondary,
          )),
        ]);
      }),
    );
  }
}

class _TripRouteCard extends StatelessWidget {
  final String originAddress, destinationAddress;
  const _TripRouteCard({required this.originAddress, required this.destinationAddress});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.primaryLight.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(children: [
      Row(children: [
        Container(
          width: 8, height: 8,
          decoration: const BoxDecoration(
              color: AppColors.primaryColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(originAddress, maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Satoshi', fontSize: 12,
                fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
      ]),
      Padding(
        padding: const EdgeInsets.only(left: 3),
        child: SizedBox(
          height: 12,
          child: VerticalDivider(
              color: AppColors.primaryColor.withValues(alpha: 0.3), thickness: 1.5),
        ),
      ),
      Row(children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: AppColors.accentColor,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primaryDark, width: 1.5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(destinationAddress, maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Satoshi', fontSize: 12,
                fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
      ]),
    ]),
  );
}

Future<void> _launchGoogleMaps(double lat, double lng) async {
  final navUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
  try {
    await launchUrl(navUri, mode: LaunchMode.externalApplication);
  } catch (_) {
    await launchUrl(
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving'),
      mode: LaunchMode.externalApplication,
    );
  }
}

class _ActiveTripBar extends StatefulWidget {
  final DriverState ds;
  final Future<void> Function() onArrivedAtPickup;
  final Future<void> Function() onStartTrip;
  final Future<void> Function() onEndTrip;
  final Future<void> Function() onCancelRide;
  const _ActiveTripBar({
    super.key,
    required this.ds,
    required this.onArrivedAtPickup,
    required this.onStartTrip,
    required this.onEndTrip,
    required this.onCancelRide,
  });
  @override
  State<_ActiveTripBar> createState() => _ActiveTripBarState();
}

class _ActiveTripBarState extends State<_ActiveTripBar> {
  bool _expanded = true;

  Future<void> _showCancelConfirm(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Batalkan Perjalanan?',
            style: TextStyle(fontFamily: 'Satoshi', fontWeight: FontWeight.w800)),
        content: const Text(
          'Apakah kamu yakin ingin membatalkan perjalanan ini?\nPenumpang akan mendapat notifikasi pembatalan.',
          style: TextStyle(fontFamily: 'Satoshi', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak', style: TextStyle(fontFamily: 'Satoshi',
                fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Ya, Batalkan',
                style: TextStyle(fontFamily: 'Satoshi', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.onCancelRide();
  }

  @override
  Widget build(BuildContext context) {
    final ds           = widget.ds;
    final isNavigating = ds.phase == DriverRidePhase.navigating;
    final isAtPickup   = ds.phase == DriverRidePhase.atPickup;
    final isOnTrip     = ds.phase == DriverRidePhase.onTrip;

    double? distToDestM;
    bool canEndTrip = true;
    if (isOnTrip && ds.activeTrip != null && ds.position != null && ds.activeTrip!.hasDestination) {
      distToDestM = Geolocator.distanceBetween(
        ds.position!.latitude, ds.position!.longitude,
        ds.activeTrip!.destinationLat, ds.activeTrip!.destinationLng,
      );
      canEndTrip = distToDestM <= 500;
    }

    final String phaseLabel, phaseSub, btnLabel;
    final Color  btnColor;
    final IconData phaseIcon, btnIcon;
    final VoidCallback onPressed;

    if (isNavigating) {
      phaseLabel = 'Menuju Penjemputan';
      phaseSub   = ds.activeTrip?.originAddress ?? 'Titik penjemputan';
      btnLabel   = 'Saya Sudah Tiba';
      btnColor   = AppColors.primaryColor;
      phaseIcon  = Icons.electric_moped_rounded;
      btnIcon    = Icons.location_on_rounded;
      onPressed  = () => widget.onArrivedAtPickup();
    } else if (isAtPickup) {
      phaseLabel = 'Tiba di Lokasi';
      phaseSub   = '${ds.activeTrip?.displayPassengerName ?? 'Penumpang'} sedang menunggu';
      btnLabel   = 'Mulai Perjalanan';
      btnColor   = AppColors.online;
      phaseIcon  = Icons.person_pin_circle_rounded;
      btnIcon    = Icons.play_circle_rounded;
      onPressed  = () => widget.onStartTrip();
    } else {
      phaseLabel = 'Dalam Perjalanan';
      phaseSub   = ds.activeTrip?.displayDestinationAddress ?? 'Menuju tujuan';
      btnLabel   = canEndTrip ? 'Selesai Perjalanan' : 'Mendekati Tujuan...';
      btnColor   = canEndTrip ? const Color(0xFFEF4444) : const Color(0xFF94A3B8);
      phaseIcon  = Icons.navigation_rounded;
      btnIcon    = canEndTrip ? Icons.flag_rounded : Icons.location_searching_rounded;
      onPressed  = () => widget.onEndTrip();
    }

    final passengerName = ds.activeTrip?.passengerName ?? 'Penumpang';
    final initial       = passengerName.isNotEmpty ? passengerName[0].toUpperCase() : 'P';
    final bottomPad     = MediaQuery.of(context).padding.bottom;

    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(color: Color(0x330540F2), blurRadius: 32, offset: Offset(0, -8)),
          ],
        ),
        child: _expanded
            ? _buildExpanded(ds, isNavigating, isAtPickup, isOnTrip,
                phaseLabel, phaseSub, phaseIcon,
                btnLabel, btnIcon, btnColor,
                distToDestM, canEndTrip, onPressed,
                passengerName, initial)
            : _buildCollapsed(ds, phaseLabel, phaseSub, phaseIcon,
                btnIcon, btnColor,
                isNavigating, isAtPickup, isOnTrip,
                canEndTrip, onPressed, bottomPad),
      ),
    );
  }

  Widget _buildCollapsed(
    DriverState ds,
    String phaseLabel, String phaseSub, IconData phaseIcon,
    IconData btnIcon, Color btnColor,
    bool isNavigating, bool isAtPickup, bool isOnTrip,
    bool canEndTrip, VoidCallback onPressed, double bottomPad,
  ) {
    final shortLabel = isNavigating ? 'Sudah Tiba' :
                       isAtPickup   ? 'Mulai'      :
                       canEndTrip   ? 'Selesai'    : 'Mendekati...';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0B0940), btnColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 14 + bottomPad),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(phaseIcon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(phaseLabel, style: const TextStyle(fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
              Text(
                ds.argo != null ? _idrFmt.format(ds.argo!.fare) : phaseSub,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Satoshi', fontSize: 11,
                    color: ds.argo != null
                        ? const Color(0xFF4ADE80)
                        : Colors.white.withValues(alpha: 0.65)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: (isOnTrip && !canEndTrip) ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: btnColor,
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.25),
            disabledForegroundColor: Colors.white54,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(btnIcon, size: 14),
            const SizedBox(width: 4),
            Text(shortLabel, style: const TextStyle(fontFamily: 'Satoshi',
                fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => setState(() => _expanded = true),
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.keyboard_arrow_up_rounded,
                color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }

  Widget _buildExpanded(
    DriverState ds,
    bool isNavigating, bool isAtPickup, bool isOnTrip,
    String phaseLabel, String phaseSub, IconData phaseIcon,
    String btnLabel, IconData btnIcon, Color btnColor,
    double? distToDestM, bool canEndTrip,
    VoidCallback onPressed, String passengerName, String initial,
  ) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [

        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF0B0940), btnColor.withValues(alpha: 0.85)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                GestureDetector(
                  onTap: () => setState(() => _expanded = false),
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(phaseIcon, size: 12, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(phaseLabel, style: const TextStyle(
                      fontFamily: 'Satoshi', fontWeight: FontWeight.w700,
                      fontSize: 11, color: Colors.white,
                    )),
                  ]),
                ),
              ]),

              const SizedBox(height: 14),

              Row(children: [

                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                  ),
                  child: Center(child: Text(initial, style: const TextStyle(
                      fontFamily: 'Satoshi', fontWeight: FontWeight.w800,
                      fontSize: 20, color: Colors.white))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(passengerName, style: const TextStyle(
                        fontFamily: 'Satoshi', fontWeight: FontWeight.w800,
                        fontSize: 16, color: Colors.white)),
                    const SizedBox(height: 3),
                    Text(phaseSub, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Satoshi', fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7))),
                  ],
                )),
                if (ds.argo != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.4)),
                    ),
                    child: Text(_idrFmt.format(ds.argo!.fare),
                        style: const TextStyle(fontFamily: 'Satoshi',
                            fontWeight: FontWeight.w800, fontSize: 13,
                            color: Color(0xFF4ADE80))),
                  ),
                ],
              ]),
            ],
          ),
        ),

        Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 16 + bottomPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              _TripPhaseSteps(isNavigating: isNavigating, isAtPickup: isAtPickup, isOnTrip: isOnTrip),
              const SizedBox(height: 12),

              if (ds.activeTrip != null) ...[
                _TripRouteCard(
                  originAddress: ds.activeTrip!.originAddress ?? 'Titik penjemputan',
                  destinationAddress: ds.activeTrip!.destinationAddress ?? 'Tujuan',
                ),
                const SizedBox(height: 10),
              ],

              if (isOnTrip && ds.argo != null) ...[
                _DigitalMeter(argo: ds.argo!),
                const SizedBox(height: 10),
              ],

              if (isOnTrip && distToDestM != null && !canEndTrip) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFB923C).withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.location_searching_rounded,
                        size: 16, color: Color(0xFFEA580C)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Sisa ${distToDestM.round()} m — tombol aktif dalam 500 m',
                      style: const TextStyle(fontFamily: 'Satoshi', fontSize: 12,
                          fontWeight: FontWeight.w600, color: Color(0xFFEA580C)),
                    )),
                  ]),
                ),
                const SizedBox(height: 10),
              ],

              GestureDetector(
                onTap: (isOnTrip && !canEndTrip) ? null : onPressed,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: (isOnTrip && !canEndTrip)
                        ? const LinearGradient(colors: [Color(0xFFCBD5E1), Color(0xFFCBD5E1)])
                        : LinearGradient(
                            colors: [const Color(0xFF0B0940), btnColor],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: (isOnTrip && !canEndTrip) ? [] : [
                      BoxShadow(
                        color: btnColor.withValues(alpha: 0.45),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(btnIcon, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(btnLabel, style: const TextStyle(
                          fontFamily: 'Satoshi', fontWeight: FontWeight.w800,
                          fontSize: 15, color: Colors.white)),
                    ],
                  ),
                ),
              ),

              if ((isNavigating || isAtPickup || isOnTrip) && ds.activeTrip != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final trip   = ds.activeTrip!;
                      final dLat   = isNavigating ? trip.originLat : trip.destinationLat;
                      final dLng   = isNavigating ? trip.originLng : trip.destinationLng;
                      _launchGoogleMaps(dLat, dLng);
                    },
                    icon: const Icon(Icons.map_rounded, size: 16),
                    label: Text(
                      isNavigating ? 'Navigasi ke Penjemputan' : 'Navigasi ke Tujuan',
                      style: const TextStyle(fontFamily: 'Satoshi',
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryColor,
                      side: const BorderSide(color: AppColors.primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],

              if ((isNavigating || isAtPickup) && ds.activeTrip != null)
                Center(
                  child: TextButton.icon(
                    onPressed: () => _showCancelConfirm(context),
                    icon: const Icon(Icons.cancel_outlined, size: 15),
                    label: const Text('Batalkan Perjalanan',
                        style: TextStyle(fontFamily: 'Satoshi',
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DigitalMeter extends StatelessWidget {
  final DriverArgo argo;
  const _DigitalMeter({required this.argo});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF0D1117),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
          color: const Color(0xFF22C55E).withValues(alpha: 0.25)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _DigitalCell(
          icon: Icons.route_rounded,
          value: '${argo.distanceKm.toStringAsFixed(2)} km',
          label: 'JARAK',
        ),
        Container(width: 1, height: 36,
            color: const Color(0xFF22C55E).withValues(alpha: 0.2)),
        _DigitalCell(
          icon: Icons.payments_rounded,
          value: _idrFmt.format(argo.fare),
          label: 'ARGO',
          highlight: true,
        ),
        Container(width: 1, height: 36,
            color: const Color(0xFF22C55E).withValues(alpha: 0.2)),
        _DigitalCell(
          icon: Icons.timer_rounded,
          value: '${argo.durationMinutes.toInt()} mnt',
          label: 'DURASI',
        ),
      ],
    ),
  );
}

class _DigitalCell extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final bool highlight;
  const _DigitalCell({
    required this.icon,
    required this.value,
    required this.label,
    this.highlight = false,
  });

  static const _dim   = Color(0xFF4ADE80);
  static const _green = Color(0xFF22C55E);

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14,
          color: highlight ? _green : _dim.withValues(alpha: 0.55)),
      const SizedBox(height: 4),
      Text(
        value,
        style: GoogleFonts.robotoMono(
          fontSize: highlight ? 15 : 12,
          fontWeight: FontWeight.w700,
          color: highlight ? _green : _dim.withValues(alpha: 0.8),
          letterSpacing: 0.5,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: const TextStyle(
          fontFamily: 'Satoshi',
          fontSize: 8,
          letterSpacing: 1.2,
          color: Color(0xFF4B5563),
        ),
      ),
    ],
  );
}

class _CompletedOverlay extends StatelessWidget {
  final DriverState ds;
  final VoidCallback onClose;
  const _CompletedOverlay({required this.ds, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final argo = ds.argo;
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 36,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.online.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.online, size: 42),
            ),
            const SizedBox(height: 14),

            const Text(
              'Perjalanan Selesai!',
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 16),

            if (argo != null) ...[
              _SummaryRow(
                icon: Icons.route_rounded,
                label: 'Jarak',
                value: '${argo.distanceKm.toStringAsFixed(1)} km',
              ),
              const SizedBox(height: 8),
              _SummaryRow(
                icon: Icons.timer_rounded,
                label: 'Durasi',
                value: '${argo.durationMinutes.toInt()} menit',
              ),
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Total Tarif',
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _idrFmt.format(argo.fare),
                      style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w800,
                        fontSize: 30,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.online.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.online.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payments_rounded,
                        color: AppColors.online, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Terima ${_idrFmt.format(argo.fare)} — Tunai atau Dana',
                        style: const TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.online,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Penumpang membayar langsung (tunai / Dana)',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onClose,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text(
                  'Cari Pesanan Berikutnya',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _SummaryRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: AppColors.primaryColor, size: 17),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      );
}
