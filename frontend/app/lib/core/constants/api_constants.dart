import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  static String get baseUrl => kReleaseMode
      ? 'http://187.77.116.121'
      : (Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000');

  static String get wsUrl => baseUrl;

  static const trackingNamespace = '/tracking';

  // HERE Maps
  static const hereApiKey = 'sqOFooLPLFLG3fpz9nVO5CU0gCssEoNhoETE2o-jAq4';

  // HERE Raster Tile API v3 — drop-in replacement for OSM TileLayer urlTemplate
  static const hereTileUrl =
      'https://maps.hereapi.com/v3/base/mc/{z}/{x}/{y}/png8'
      '?apiKey=$hereApiKey';

  // HERE Routing v8
  static const hereRoutingUrl = 'https://router.hereapi.com/v8/routes';

  // HERE Discover (place search)
  static const hereDiscoverUrl =
      'https://discover.search.hereapi.com/v1/discover';
}
