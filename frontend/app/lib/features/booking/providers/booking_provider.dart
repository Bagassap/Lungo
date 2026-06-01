import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/ride_model.dart';
import '../services/booking_service.dart';

enum BookingStatus { idle, searching, active, completed, cancelled, error }

class BookingState {
  final BookingStatus status;
  final RideModel? ride;
  final String? errorMessage;

  const BookingState({
    this.status = BookingStatus.idle,
    this.ride,
    this.errorMessage,
  });

  BookingState copyWith({
    BookingStatus? status,
    RideModel? ride,
    String? errorMessage,
  }) =>
      BookingState(
        status: status ?? this.status,
        ride: ride ?? this.ride,
        errorMessage: errorMessage,
      );
}

class BookingNotifier extends StateNotifier<BookingState> {
  final BookingService _service;

  BookingNotifier(this._service) : super(const BookingState());

  Future<bool> createRide({
    required String passengerId,
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    state = state.copyWith(status: BookingStatus.searching);
    try {
      final ride = await _service.createRide(
        passengerId: passengerId,
        originLat: originLat,
        originLng: originLng,
        destinationLat: destinationLat,
        destinationLng: destinationLng,
      );
      state = state.copyWith(status: BookingStatus.searching, ride: ride);
      unawaited(SecureStorage.savePassengerRideId(ride.id));
      return true;
    } catch (e) {
      state = state.copyWith(
        status: BookingStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<void> refreshRide() async {
    final rideId = state.ride?.id;
    if (rideId == null) return;
    try {
      final ride = await _service.getRide(rideId);
      final newStatus = _mapStatus(ride.status);
      state = state.copyWith(status: newStatus, ride: ride);
    } catch (_) {}
  }

  Future<bool> completeRide() async {
    final rideId = state.ride?.id;
    if (rideId == null) return false;
    try {
      final ride = await _service.completeRide(rideId);
      state = state.copyWith(status: BookingStatus.completed, ride: ride);
      unawaited(SecureStorage.clearPassengerRideId());
      return true;
    } catch (e) {
      state = state.copyWith(
        status: BookingStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> cancelRide() async {
    final rideId = state.ride?.id;
    if (rideId == null) return false;
    try {
      final ride = await _service.cancelRide(rideId);
      state = state.copyWith(status: BookingStatus.cancelled, ride: ride);
      unawaited(SecureStorage.clearPassengerRideId());
      return true;
    } catch (e) {
      state = state.copyWith(
        status: BookingStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  void startSearching({
    required String rideId,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) {
    final ride = RideModel(
      id: rideId,
      passengerId: '',
      originLat: originLat,
      originLng: originLng,
      destinationLat: destLat,
      destinationLng: destLng,
      status: 'SEARCHING',
      createdAt: DateTime.now(),
    );
    state = state.copyWith(status: BookingStatus.searching, ride: ride);
    unawaited(SecureStorage.savePassengerRideId(rideId));
  }

  void setActive({String rideStatus = 'ONGOING'}) {
    if (state.ride != null) {
      debugPrint('[Booking] setActive: rideStatus=$rideStatus');
      state = state.copyWith(
        status: BookingStatus.active,
        ride: state.ride!.copyWith(status: rideStatus),
      );
    }
  }

  void reset() {
    state = const BookingState();
    unawaited(SecureStorage.clearPassengerRideId());
  }

  Future<void> restoreFromStorage() async {
    final rideId = await SecureStorage.getPassengerRideId();
    if (rideId == null || rideId.isEmpty) return;
    try {
      final ride = await _service.getRide(rideId);
      debugPrint('[Booking] restore: status=${ride.status} driverId=${ride.driverId}');
      final newStatus = _mapStatus(ride.status);
      if (newStatus == BookingStatus.completed ||
          newStatus == BookingStatus.cancelled ||
          newStatus == BookingStatus.idle) {
        debugPrint('[Booking] restore: SKIP — status terminal (${ride.status}), clearing storage');
        await SecureStorage.clearPassengerRideId();
        return;
      }
      // ACCEPTED/PICKUP/ONGOING tanpa driverId = state korup, jangan restore
      final isValidToRestore = newStatus != BookingStatus.active ||
          (ride.driverId != null && ride.driverId!.isNotEmpty);
      debugPrint('[Booking] restore: valid=$isValidToRestore');
      if (!isValidToRestore) {
        debugPrint('[Booking] restore: SKIP — status active tapi driverId null, clearing storage');
        await SecureStorage.clearPassengerRideId();
        return;
      }
      state = state.copyWith(status: newStatus, ride: ride);
    } catch (e) {
      debugPrint('[Booking] restore: ERROR — $e, clearing storage');
      await SecureStorage.clearPassengerRideId();
    }
  }

  BookingStatus _mapStatus(String s) => switch (s) {
        'SEARCHING' => BookingStatus.searching,
        'ACCEPTED' || 'PICKUP' || 'ONGOING' => BookingStatus.active,
        'DONE' => BookingStatus.completed,
        'CANCELLED' => BookingStatus.cancelled,
        _ => BookingStatus.idle,
      };
}

final bookingServiceProvider = Provider<BookingService>((_) => BookingService());

final bookingProvider = StateNotifierProvider<BookingNotifier, BookingState>(
  (ref) => BookingNotifier(ref.watch(bookingServiceProvider)),
);
