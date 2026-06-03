import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../constants/api_constants.dart';
import 'location_search_service.dart';

class HereService {
  static final _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8);

  static Future<List<LatLng>> getRoute(LatLng from, LatLng to) async {
    final here = await _hereRoute(from, to);
    if (here.length >= 2) return here;
    return _osrmRoute(from, to);
  }

  static Future<List<LatLng>> _hereRoute(LatLng from, LatLng to) async {
    try {
      final uri = Uri.parse(ApiConstants.hereRoutingUrl).replace(
        queryParameters: {
          'transportMode': 'car',
          'origin': '${from.latitude},${from.longitude}',
          'destination': '${to.latitude},${to.longitude}',
          'return': 'polyline',
          'apiKey': ApiConstants.hereApiKey,
        },
      );
      final req = await _http.getUrl(uri);
      final res = await req.close();
      if (res.statusCode != 200) return [];
      final body = await res.transform(const Utf8Decoder()).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return [];
      final sections = routes[0]['sections'] as List<dynamic>?;
      if (sections == null || sections.isEmpty) return [];
      final polyline = sections[0]['polyline'] as String?;
      if (polyline == null || polyline.isEmpty) return [];
      return _decodeFlexPoly(polyline);
    } catch (_) {
      return [];
    }
  }

  static Future<List<LatLng>> _osrmRoute(LatLng from, LatLng to) async {
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson',
      );
      final req = await _http.getUrl(uri);
      final res = await req.close();
      if (res.statusCode == 200) {
        final body   = await res.transform(const Utf8Decoder()).join();
        final data   = jsonDecode(body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final coords = routes[0]['geometry']['coordinates'] as List<dynamic>;
          return coords.map((c) => LatLng(
            (c[1] as num).toDouble(), (c[0] as num).toDouble(),
          )).toList();
        }
      }
    } catch (_) {}

    return List.generate(12, (i) {
      final f = i / 11;
      return LatLng(
        from.latitude  + (to.latitude  - from.latitude)  * f,
        from.longitude + (to.longitude - from.longitude) * f,
      );
    });
  }

  static int _charVal(int ascii) {
    if (ascii >= 65 && ascii <= 90) return ascii - 65;
    if (ascii >= 97 && ascii <= 122) return ascii - 71;
    if (ascii >= 48 && ascii <= 57) return ascii + 4;
    if (ascii == 45) return 62;
    if (ascii == 95) return 63;
    return 0;
  }

  static List<LatLng> _decodeFlexPoly(String encoded) {
    if (encoded.length < 3) return [];
    int idx = 0;

    int readUnsigned() {
      int value = 0, shift = 0;
      while (idx < encoded.length) {
        final b = _charVal(encoded.codeUnitAt(idx++));
        value |= (b & 0x1F) << shift;
        shift += 5;
        if ((b & 0x20) == 0) break;
      }
      return value;
    }

    int readSigned() {
      final v = readUnsigned();
      return (v & 1) != 0 ? -(v >> 1) - 1 : (v >> 1);
    }

    readUnsigned();
    final header    = readUnsigned();
    final precision = header & 0x0F;
    final thirdDim  = (header >> 4) & 0x07;
    final factor    = math.pow(10, precision).toDouble();

    final result = <LatLng>[];
    int lat = 0, lng = 0;
    while (idx < encoded.length) {
      lat += readSigned();
      lng += readSigned();
      if (thirdDim != 0) readSigned();
      result.add(LatLng(lat / factor, lng / factor));
    }
    return result;
  }

  static Future<List<SearchResult>> searchPlaces(
    String query,
    double lat,
    double lng,
  ) async {
    try {
      final uri = Uri.parse(ApiConstants.hereDiscoverUrl).replace(
        queryParameters: {
          'q':     query,
          'in':    'circle:$lat,$lng;r=10000',
          'lang':  'id',
          'limit': '15',
          'apiKey': ApiConstants.hereApiKey,
        },
      );
      final req = await _http.getUrl(uri);
      final res = await req.close();
      if (res.statusCode != 200) return [];
      final body  = await res.transform(const Utf8Decoder()).join();
      final data  = jsonDecode(body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? [];

      return items.map((item) {
        final m       = item as Map<String, dynamic>;
        final pos     = m['position'] as Map<String, dynamic>?;
        if (pos == null) return null;
        final iLat    = (pos['lat'] as num?)?.toDouble();
        final iLng    = (pos['lng'] as num?)?.toDouble();
        if (iLat == null || iLng == null) return null;

        final addrMap = m['address'] as Map<String, dynamic>? ?? {};
        final label   = addrMap['label'] as String? ?? '';
        final title   = m['title'] as String? ?? '';

        final cats    = m['categories'] as List<dynamic>? ?? [];
        final catName = cats.isNotEmpty
            ? ((cats[0] as Map)['name'] as String? ?? 'place')
            : 'place';

        return SearchResult(
          name:     title,
          address:  label,
          lat:      iLat,
          lng:      iLng,
          type:     _mapCatType(catName),
          category: catName,
          source:   'here',
        );
      }).whereType<SearchResult>().toList();
    } catch (_) {
      return [];
    }
  }

  static String _mapCatType(String catName) {
    final c = catName.toLowerCase();
    if (c.contains('restaurant') || c.contains('food')) return 'restaurant';
    if (c.contains('cafe') || c.contains('coffee')) return 'cafe';
    if (c.contains('school') || c.contains('university')) return 'school';
    if (c.contains('hospital') || c.contains('health')) return 'hospital';
    if (c.contains('bank') || c.contains('atm')) return 'bank';
    if (c.contains('mosque') || c.contains('worship')) return 'place_of_worship';
    if (c.contains('hotel') || c.contains('accommodation')) return 'hotel';
    if (c.contains('shop') || c.contains('mall')) return 'supermarket';
    if (c.contains('fuel') || c.contains('gas')) return 'fuel';
    return 'place';
  }
}
