import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  static String get baseUrl => kReleaseMode
      ? 'http://36.68.55.206'
      : (Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000');

  static String get wsUrl => baseUrl;

  static const trackingNamespace = '/tracking';

  static const hereApiKey = 'zuwRqY7cqc-7QJqI3m3tnhbc5gccEW95oqbxLYqTSa8';

  static const hereTileUrl =
      'https://maps.hereapi.com/v3/base/mc/{z}/{x}/{y}/png8'
      '?apiKey=$hereApiKey';

  static const hereRoutingUrl = 'https://router.hereapi.com/v8/routes';

  static const hereDiscoverUrl =
      'https://discover.search.hereapi.com/v1/discover';
}
