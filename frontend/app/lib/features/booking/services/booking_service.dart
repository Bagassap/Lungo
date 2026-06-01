import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../models/ride_model.dart';

class BookingService {
  final Dio _dio = ApiClient.create();

  Future<RideModel> createRide({
    required String passengerId,
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    final resp = await _dio.post('/booking/rides', data: {
      'passengerId': passengerId,
      'originLat': originLat,
      'originLng': originLng,
      'destinationLat': destinationLat,
      'destinationLng': destinationLng,
    });
    return RideModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<RideModel> getRide(String rideId) async {
    final resp = await _dio.get('/booking/rides/$rideId');
    return RideModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<RideModel> completeRide(String rideId) async {
    final resp = await _dio.post('/booking/rides/$rideId/complete');
    return RideModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<RideModel> cancelRide(String rideId) async {
    final resp = await _dio.post('/booking/rides/$rideId/cancel');
    return RideModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<TariffInfo> getTariffInfo() async {
    final resp = await _dio.get('/tariff/info');
    final d = resp.data as Map<String, dynamic>;
    return TariffInfo(
      baseFare: (d['baseFare'] as num).toDouble(),
      perKm: (d['perKm'] as num).toDouble(),
      minimumFare: (d['minimumFare'] as num).toDouble(),
    );
  }

  Future<double> calculateFare(double distanceKm) async {
    final resp =
        await _dio.get('/tariff/calculate', queryParameters: {'distance': distanceKm});
    return (resp.data['fare'] as num).toDouble();
  }
}

class TariffInfo {
  final double baseFare;
  final double perKm;
  final double minimumFare;

  const TariffInfo({
    required this.baseFare,
    required this.perKm,
    required this.minimumFare,
  });
}
