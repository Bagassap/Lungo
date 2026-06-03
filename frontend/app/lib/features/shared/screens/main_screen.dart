import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/nav_tab_provider.dart';
import '../widgets/lungo_bottom_nav.dart';
import '../../passenger/screens/passenger_home_screen.dart';
import '../../passenger/screens/passenger_activity_screen.dart';
import '../../passenger/screens/passenger_chat_screen.dart';
import '../../passenger/screens/passenger_profile_screen.dart';
import '../../driver/screens/driver_home_screen.dart';
import '../../driver/screens/driver_activity_screen.dart';
import '../../driver/screens/driver_chat_screen.dart';
import '../../driver/screens/driver_profile_screen.dart';
import '../../admin/screens/admin_home_screen.dart';
import '../../admin/screens/admin_activity_screen.dart';
import '../../admin/screens/admin_chat_screen.dart';
import '../../admin/screens/admin_profile_screen.dart';
import '../../booking/providers/booking_provider.dart';
import '../../booking/screens/trip_screen.dart';
import '../../driver/providers/driver_provider.dart';
import '../../../core/services/fcm_service.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  @override
  void initState() {
    super.initState();
    final tab = FcmService.consumePendingTabIndex();
    if (tab >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(navTabProvider.notifier).state = tab;
      });
    }
    final rideNav = FcmService.consumePendingRideNav();
    if (rideNav != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final route = rideNav['route']!;
        final rideId = rideNav['rideId']!;
        Navigator.pushNamed(context, route, arguments: {'rideId': rideId});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeRole = ModalRoute.of(context)?.settings.arguments as String?;
    final role = routeRole ?? ref.watch(authProvider).user?.role ?? 'PASSENGER';
    final currentIndex = ref.watch(navTabProvider);
    final booking = ref.watch(bookingProvider);

    final List<Widget> screens = switch (role) {
      'DRIVER' => const [
          DriverHomeScreen(),
          DriverActivityScreen(),
          DriverChatScreen(),
          DriverProfileScreen(),
        ],
      'ADMIN' => const [
          AdminHomeScreen(),
          AdminActivityScreen(),
          AdminChatScreen(),
          AdminProfileScreen(),
        ],
      _ => const [
          PassengerHomeScreen(),
          PassengerActivityScreen(),
          PassengerChatScreen(),
          PassengerProfileScreen(),
        ],
    };

    final bool showTripChip = role == 'PASSENGER' &&
        currentIndex != 0 &&
        (booking.status == BookingStatus.searching ||
            booking.status == BookingStatus.active);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
      },
      child: Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                IndexedStack(
                  index: currentIndex,
                  children: screens,
                ),
                if (showTripChip)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 8,
                    child: _TripChip(
                      booking: booking,
                      onTap: () async {
                        if (ref.read(bookingProvider).ride != null) {
                          await ref.read(bookingProvider.notifier).refreshRide();
                        } else {
                          await ref.read(bookingProvider.notifier).restoreFromStorage();
                        }
                        final ride = ref.read(bookingProvider).ride;
                        if (ride == null || !context.mounted) return;
                        final status = ride.status.toUpperCase();
                        if (status == 'ONGOING') {
                          Navigator.pushNamed(context, '/trip', arguments: TripArgs(
                            rideId: ride.id,
                            initialStatus: 'ONGOING',
                            driverName: ride.driverName ?? 'Driver',
                            driverPlate: ride.driverPlate ?? '-',
                            driverPhone: ride.driverPhone ?? '',
                            driverLat: ride.originLat,
                            driverLng: ride.originLng,
                            destLat: ride.destinationLat,
                            destLng: ride.destinationLng,
                          ));
                        } else if (status == 'ACCEPTED' || status == 'PICKUP') {
                          Navigator.pushNamed(context, '/waiting', arguments: {
                            'rideId': ride.id,
                            'restore': true,
                          });
                        } else if (status == 'SEARCHING') {
                          Navigator.pushNamed(context, '/waiting', arguments: {
                            'rideId': ride.id,
                            'restore': false,
                          });
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          Consumer(
            builder: (context, ref, _) {
              final phase = ref.watch(
                  driverProvider.select((s) => s.phase));
              final isActive = [
                DriverRidePhase.navigating,
                DriverRidePhase.atPickup,
                DriverRidePhase.onTrip,
              ].contains(phase);
              if (!isActive) return const SizedBox.shrink();
              final idx = ref.watch(navTabProvider);
              if (idx == 0) return const SizedBox.shrink();
              return GestureDetector(
                onTap: () => ref.read(navTabProvider.notifier).state = 0,
                child: Container(
                  width: double.infinity,
                  color: Colors.green[700],
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_bike,
                          color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Trip sedang berjalan — Ketuk untuk kembali',
                        style: TextStyle(
                            color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: LungoBottomNav(
        currentIndex: currentIndex,
        onTap: (i) => ref.read(navTabProvider.notifier).state = i,
      ),
      ),
    );
  }
}

class _TripChip extends StatelessWidget {
  final BookingState booking;
  final VoidCallback onTap;

  const _TripChip({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSearching = booking.status == BookingStatus.searching;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0540F2),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x440540F2),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              if (isSearching)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                const Icon(Icons.electric_moped_rounded,
                    color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isSearching ? 'Mencari driver...' : 'Perjalanan sedang berjalan',
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white70, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
