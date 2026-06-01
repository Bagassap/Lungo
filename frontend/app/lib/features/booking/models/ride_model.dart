class RideModel {
  final String id;
  final String passengerId;
  final String? driverId;
  final double originLat;
  final double originLng;
  final double destinationLat;
  final double destinationLng;
  final String status;
  final double? fare;
  final double? distanceKm;
  final DateTime createdAt;
  final String? driverName;
  final String? driverPhone;
  final String? driverPlate;
  final double? driverRating;

  const RideModel({
    required this.id,
    required this.passengerId,
    this.driverId,
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.status,
    this.fare,
    this.distanceKm,
    required this.createdAt,
    this.driverName,
    this.driverPhone,
    this.driverPlate,
    this.driverRating,
  });

  static double _d(dynamic v, [double fallback = 0.0]) =>
      num.tryParse(v?.toString() ?? '')?.toDouble() ?? fallback;

  factory RideModel.fromJson(Map<String, dynamic> json) {
    final driver = json['driver'] as Map<String, dynamic>?;
    return RideModel(
      id: json['id'] as String,
      passengerId: json['passengerId'] as String,
      driverId: json['driverId'] as String?,
      originLat: _d(json['originLat']),
      originLng: _d(json['originLng']),
      destinationLat: _d(json['destinationLat']),
      destinationLng: _d(json['destinationLng']),
      status: json['status'] as String,
      fare: json['fare'] != null ? _d(json['fare']) : null,
      distanceKm: json['distanceKm'] != null ? _d(json['distanceKm']) : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      driverName: driver?['name'] as String?,
      driverPhone: driver?['phone'] as String?,
      driverPlate: driver?['vehiclePlate'] as String?,
      driverRating: driver != null
          ? num.tryParse(driver['rating']?.toString() ?? '')?.toDouble()
          : null,
    );
  }

  RideModel copyWith({
    String? status,
    String? driverId,
    double? fare,
    String? driverName,
    String? driverPhone,
    String? driverPlate,
    double? driverRating,
  }) =>
      RideModel(
        id: id,
        passengerId: passengerId,
        driverId: driverId ?? this.driverId,
        originLat: originLat,
        originLng: originLng,
        destinationLat: destinationLat,
        destinationLng: destinationLng,
        status: status ?? this.status,
        fare: fare ?? this.fare,
        distanceKm: distanceKm,
        createdAt: createdAt,
        driverName: driverName ?? this.driverName,
        driverPhone: driverPhone ?? this.driverPhone,
        driverPlate: driverPlate ?? this.driverPlate,
        driverRating: driverRating ?? this.driverRating,
      );
}
