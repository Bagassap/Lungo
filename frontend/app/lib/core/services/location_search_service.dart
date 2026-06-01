import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'here_service.dart';

class SearchResult {
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String type;
  final String category;
  final String source;

  const SearchResult({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.type,
    required this.category,
    required this.source,
  });

  factory SearchResult.fromJson(Map<String, dynamic> j) => SearchResult(
        name:     j['name']     as String? ?? '',
        address:  j['address']  as String? ?? '',
        lat:      (j['lat']     as num).toDouble(),
        lng:      (j['lng']     as num).toDouble(),
        type:     j['type']     as String? ?? 'place',
        category: j['category'] as String? ?? 'place',
        source:   j['source']   as String? ?? 'saved',
      );

  Map<String, dynamic> toJson() => {
        'name':     name,
        'address':  address,
        'lat':      lat,
        'lng':      lng,
        'type':     type,
        'category': category,
        'source':   source,
      };

  double distanceTo(double userLat, double userLng) {
    const r = 6371.0;
    final lat1 = userLat * (math.pi / 180);
    final lat2 = lat    * (math.pi / 180);
    final dLat = (lat   - userLat) * (math.pi / 180);
    final dLng = (lng   - userLng) * (math.pi / 180);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  String get coordKey =>
      '${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
}

class LocationSearchService {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'User-Agent': 'LungoApp/1.0 (flutter; android)'},
  ));

  // ── Public entry point ───────────────────────────────────────────────────────

  static Future<List<SearchResult>> search(
    String query,
    double userLat,
    double userLng,
  ) async {
    final all = <SearchResult>[];

    // Stage 0: HERE Discover — most accurate, uses real POI database
    final here = await HereService.searchPlaces(query, userLat, userLng);
    all.addAll(here);

    // Stage 1: Photon (fast, bias toward user location)
    final photon = await _photon(query, userLat, userLng);
    for (final r in photon) {
      if (!all.any((x) => x.coordKey == r.coordKey)) all.add(r);
    }

    // Stage 2: Overpass 2 km — very local POIs
    final local = await _overpass(query, userLat, userLng, 2000);
    for (final r in local) {
      if (!all.any((x) => x.coordKey == r.coordKey)) all.add(r);
    }

    // Stage 3: Overpass 10 km if still sparse
    if (all.length < 3) {
      final wider = await _overpass(query, userLat, userLng, 10000);
      for (final r in wider) {
        if (!all.any((x) => x.coordKey == r.coordKey)) all.add(r);
      }
    }

    // Stage 4: Province-scoped Nominatim fallback if still empty
    if (all.isEmpty) {
      final fallback = await _nominatimBounded(
          '$query Jawa Tengah', userLat, userLng, 2.0);
      all.addAll(fallback);
    }

    return _process(all, userLat, userLng);
  }

  // ── Photon ───────────────────────────────────────────────────────────────────

  static Future<List<SearchResult>> _photon(
    String query,
    double lat,
    double lng,
  ) async {
    try {
      final res = await _dio.get(
        'https://photon.komoot.io/api/',
        queryParameters: {
          'q':                   query,
          'lat':                 lat,
          'lon':                 lng,
          'limit':               15,
          'lang':                'id',
          'location_bias_scale': 0.8,
        },
      );

      final features = (res.data['features'] as List?) ?? [];
      final results  = <SearchResult>[];

      for (final f in features) {
        final props = Map<String, dynamic>.from(f['properties'] as Map? ?? {});
        final coords = (f['geometry']?['coordinates'] as List?);
        if (coords == null || coords.length < 2) continue;

        final flng = (coords[0] as num).toDouble();
        final flat = (coords[1] as num).toDouble();
        final name = (props['name'] as String?) ?? '';
        if (name.isEmpty) continue;

        final addrParts = <String?>[
          props['street']  as String?,
          props['district'] as String?,
          props['city']    as String?,
        ].whereType<String>().where((s) => s.isNotEmpty).toList();

        results.add(SearchResult(
          name:     name,
          address:  addrParts.join(', '),
          lat:      flat,
          lng:      flng,
          type:     (props['type'] ?? props['osm_value'] ?? 'place').toString(),
          category: (props['osm_key'] ?? 'place').toString(),
          source:   'photon',
        ));
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  // ── Overpass ─────────────────────────────────────────────────────────────────

  static Future<List<SearchResult>> _overpass(
    String query,
    double lat,
    double lng,
    int radiusMeters,
  ) async {
    try {
      final esc = query
          .replaceAll('"', '')
          .replaceAll("'", '')
          .replaceAll('(', '')
          .replaceAll(')', '');

      final oq = '''
[out:json][timeout:20];
(
  node["name"~"$esc",i](around:$radiusMeters,$lat,$lng);
  way["name"~"$esc",i](around:$radiusMeters,$lat,$lng);
  node["amenity"](around:$radiusMeters,$lat,$lng)["name"~"$esc",i];
  node["shop"](around:$radiusMeters,$lat,$lng)["name"~"$esc",i];
  node["office"](around:$radiusMeters,$lat,$lng)["name"~"$esc",i];
  node["building"="school"](around:$radiusMeters,$lat,$lng)["name"~"$esc",i];
);
out center 25;''';

      final res = await _dio.post(
        'https://overpass-api.de/api/interpreter',
        data: 'data=${Uri.encodeComponent(oq)}',
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      );

      final elements = (res.data['elements'] as List?) ?? [];
      final results  = <SearchResult>[];

      for (final e in elements) {
        final tags = Map<String, dynamic>.from(e['tags'] as Map? ?? {});
        final name = tags['name'] as String?;
        if (name == null || name.isEmpty) continue;

        final elat =
            ((e['lat'] ?? (e['center'] as Map?)?['lat']) as num?)?.toDouble();
        final elng =
            ((e['lon'] ?? (e['center'] as Map?)?['lon']) as num?)?.toDouble();
        if (elat == null || elng == null) continue;

        final addrParts = <String>[];
        for (final k in [
          'addr:street', 'addr:hamlet', 'addr:village',
          'addr:subdistrict', 'addr:city',
        ]) {
          final v = tags[k] as String?;
          if (v != null && v.isNotEmpty) addrParts.add(v);
        }
        if (addrParts.isEmpty && tags['is_in'] != null) {
          addrParts.add(tags['is_in'].toString().split(',').first.trim());
        }

        results.add(SearchResult(
          name:     name,
          address:  addrParts.join(', '),
          lat:      elat,
          lng:      elng,
          type:     _typeFromTags(tags),
          category: _categoryFromTags(tags),
          source:   'overpass',
        ));
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  // ── Nominatim bounded ────────────────────────────────────────────────────────

  static Future<List<SearchResult>> _nominatimBounded(
    String query,
    double lat,
    double lng,
    double radius,
  ) async {
    try {
      final res = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q':               query,
          'format':          'json',
          'limit':           20,
          'countrycodes':    'id',
          'accept-language': 'id',
          'addressdetails':  1,
          'namedetails':     1,
          'viewbox':
              '${lng - radius},${lat - radius},${lng + radius},${lat + radius}',
          'bounded': 1,
        },
      );

      return ((res.data as List?) ?? []).map((item) {
        final m    = Map<String, dynamic>.from(item as Map);
        final rlat = double.tryParse(m['lat'] as String? ?? '0') ?? 0;
        final rlng = double.tryParse(m['lon'] as String? ?? '0') ?? 0;
        if (rlat == 0 || rlng == 0) return null;

        final addr = m['address'] as Map? ?? {};
        final addrParts = <String?>[
          addr['road']    as String?,
          addr['hamlet']  as String?,
          addr['village'] as String?,
          (addr['town'] ?? addr['city']) as String?,
        ].whereType<String>().where((s) => s.isNotEmpty).toList();

        final nd      = m['namedetails'];
        final name    = nd is Map
            ? ((nd['name'] ?? nd['name:id']) as String? ?? '')
            : '';
        final display = m['display_name'] as String? ?? '';

        return SearchResult(
          name:     name.isNotEmpty ? name : display.split(',').first.trim(),
          address:  addrParts.join(', '),
          lat:      rlat,
          lng:      rlng,
          type:     (m['type'] ?? m['class'] ?? 'place').toString(),
          category: (m['class'] ?? 'place').toString(),
          source:   'nominatim',
        );
      }).whereType<SearchResult>().toList();
    } catch (_) {
      return [];
    }
  }

  // ── Sort + dedup ─────────────────────────────────────────────────────────────

  static List<SearchResult> _process(
    List<SearchResult> results,
    double userLat,
    double userLng,
  ) {
    final seen   = <String>{};
    final unique = results
        .where((r) => r.name.isNotEmpty && seen.add(r.coordKey))
        .toList();
    unique.sort((a, b) => a
        .distanceTo(userLat, userLng)
        .compareTo(b.distanceTo(userLat, userLng)));
    return unique.take(20).toList();
  }

  // ── Tag helpers ───────────────────────────────────────────────────────────────

  static String _typeFromTags(Map<String, dynamic> tags) {
    if (tags['amenity'] != null) return tags['amenity'] as String;
    if (tags['shop']    != null) return tags['shop']    as String;
    if (tags['tourism'] != null) return tags['tourism'] as String;
    if (tags['office']  != null) return tags['office']  as String;
    return 'place';
  }

  static String _categoryFromTags(Map<String, dynamic> tags) {
    if (tags['amenity'] != null) return 'amenity';
    if (tags['shop']    != null) return 'shop';
    if (tags['tourism'] != null) return 'tourism';
    return 'place';
  }
}
