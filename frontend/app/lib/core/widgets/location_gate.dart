import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/auth/providers/auth_provider.dart';

enum _LocState { checking, granted, serviceOff, denied, permanent }

class LocationGate extends ConsumerStatefulWidget {
  final Widget child;
  const LocationGate({super.key, required this.child});

  @override
  ConsumerState<LocationGate> createState() => _LocationGateState();
}

class _LocationGateState extends ConsumerState<LocationGate>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  _LocState _state = _LocState.checking;
  bool _loading = false;
  bool _hasRequested = false;

  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {

    if (state == AppLifecycleState.resumed &&
        _state != _LocState.granted &&
        _state != _LocState.checking) {
      _check();
    }
  }

  Future<void> _check() async {
    if (!mounted || _loading) return;
    setState(() => _loading = true);

    final svcOn = await Geolocator.isLocationServiceEnabled();
    if (!svcOn) {
      if (!mounted) return;
      setState(() {
        _state = _LocState.serviceOff;
        _loading = false;
      });
      _ctrl.forward(from: 0);
      return;
    }

    var perm = await Geolocator.checkPermission();

    if (perm == LocationPermission.denied && !_hasRequested) {
      _hasRequested = true;
      perm = await Geolocator.requestPermission();
    }
    if (!mounted) return;

    if (perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse) {
      setState(() {
        _state = _LocState.granted;
        _loading = false;
      });
    } else if (perm == LocationPermission.deniedForever) {
      setState(() {
        _state = _LocState.permanent;
        _loading = false;
      });
      _ctrl.forward(from: 0);
    } else {
      setState(() {
        _state = _LocState.denied;
        _loading = false;
      });
      _ctrl.forward(from: 0);
    }
  }

  Future<void> _openSettings() async {
    if (_state == _LocState.serviceOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }

  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?.role ?? 'PASSENGER';

    if (role == 'ADMIN' || _state == _LocState.granted) {
      return widget.child;
    }

    if (_state == _LocState.checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0540F2),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFF2CB05),
            strokeWidth: 3,
          ),
        ),
      );
    }

    final isServiceOff = _state == _LocState.serviceOff;
    final isPermanent = _state == _LocState.permanent;

    final String cardTitle;
    final String cardDesc;
    final String btnLabel;

    if (isServiceOff) {
      cardTitle = 'GPS Mati';
      cardDesc =
          'Lungo membutuhkan GPS untuk menampilkan posisimu di peta dan mencari driver terdekat. Aktifkan layanan lokasi di perangkat kamu.';
      btnLabel = 'Aktifkan GPS';
    } else if (isPermanent) {
      cardTitle = 'Izin Ditolak';
      cardDesc =
          'Kamu telah menolak izin lokasi secara permanen. Buka pengaturan aplikasi untuk mengaktifkan izin lokasi agar bisa menggunakan Lungo.';
      btnLabel = 'Buka Pengaturan';
    } else {

      cardTitle = 'Izin Lokasi Diperlukan';
      cardDesc =
          'Lungo membutuhkan akses lokasi untuk menampilkan posisimu di peta dan menghubungkan kamu dengan driver terdekat.';
      btnLabel = 'Buka Pengaturan';
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: false,
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0540F2),
                  Color(0xFF04198C),
                  Color(0xFF056CF2),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const Spacer(),

                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2CB05),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF2CB05).withValues(alpha: 0.45),
                          blurRadius: 36,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      isServiceOff
                          ? Icons.gps_off_rounded
                          : Icons.location_on_rounded,
                      color: const Color(0xFF0540F2),
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Lungo',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 36,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ojek Online',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFFF2CB05),
                      letterSpacing: 2.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const Spacer(),

                  FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 40,
                              offset: const Offset(0, -6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [

                            Text(
                              cardTitle,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: const Color(0xFF0540F2),
                              ),
                            ),
                            const SizedBox(height: 8),

                            Text(
                              cardDesc,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: Colors.grey[600],
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 16),

                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: const [
                                _Chip(
                                  icon: Icons.map_rounded,
                                  label: 'Tampilkan peta',
                                ),
                                _Chip(
                                  icon: Icons.electric_moped_rounded,
                                  label: 'Temukan driver',
                                ),
                                _Chip(
                                  icon: Icons.route_rounded,
                                  label: 'Navigasi real-time',
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _openSettings,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0540F2),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      const Color(0xFF0540F2)
                                          .withValues(alpha: 0.45),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        btnLabel,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 44),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF0FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF0540F2)),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: const Color(0xFF0540F2),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
