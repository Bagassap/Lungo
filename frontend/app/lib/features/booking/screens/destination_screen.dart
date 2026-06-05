import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/services/here_service.dart';
import '../../../core/services/location_search_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lungo_snackbar.dart';
import '../providers/booking_provider.dart';

final _idrFmt = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

IconData _typeIcon(String type) => switch (type) {
      'restaurant' || 'food_court' => Icons.restaurant_rounded,
      'fast_food'                   => Icons.fastfood_rounded,
      'cafe'                        => Icons.coffee_rounded,
      'school'                      => Icons.school_rounded,
      'university' || 'college'     => Icons.account_balance_rounded,
      'hospital'                    => Icons.local_hospital_rounded,
      'clinic' || 'doctors'         => Icons.medical_services_rounded,
      'pharmacy'                    => Icons.medication_rounded,
      'bank'                        => Icons.account_balance_wallet_rounded,
      'atm'                         => Icons.atm_rounded,
      'fuel'                        => Icons.local_gas_station_rounded,
      'supermarket'                 => Icons.shopping_cart_rounded,
      'convenience' || 'minimarket' => Icons.store_rounded,
      'place_of_worship' || 'mosque' => Icons.mosque_rounded,
      'hotel' || 'guest_house'      => Icons.hotel_rounded,
      'mall'                        => Icons.local_mall_rounded,
      'park'                        => Icons.park_rounded,
      'parking'                     => Icons.local_parking_rounded,
      'police'                      => Icons.local_police_rounded,
      'bus_station' || 'bus_stop'   => Icons.directions_bus_rounded,
      'residential' || 'house' || 'apartments' => Icons.home_rounded,
      _                             => Icons.location_on_rounded,
    };

Color _typeColor(String type) => switch (type) {
      'restaurant' || 'fast_food' || 'food_court' => const Color(0xFFFF6B35),
      'cafe'                        => const Color(0xFF8B4513),
      'school' || 'university' || 'college' => const Color(0xFF0540F2),
      'hospital' || 'clinic' || 'doctors'   => const Color(0xFFE53935),
      'pharmacy'                    => const Color(0xFFE53935),
      'bank' || 'atm'               => const Color(0xFF00C896),
      'fuel'                        => const Color(0xFFFF8C00),
      'supermarket' || 'convenience' || 'minimarket' => const Color(0xFF4CAF50),
      'place_of_worship' || 'mosque' => const Color(0xFF009688),
      'hotel' || 'guest_house'      => const Color(0xFF9C27B0),
      'park'                        => const Color(0xFF43A047),
      _                             => const Color(0xFF0540F2),
    };

Color _typeBg(String type) => _typeColor(type).withValues(alpha: 0.12);

const _kCategories = [
  ('Makan',      Icons.restaurant_rounded,       'warung'),
  ('Sekolah',    Icons.school_rounded,            'sekolah'),
  ('Masjid',     Icons.mosque_rounded,            'masjid'),
  ('Pasar',      Icons.store_rounded,             'pasar'),
  ('Puskesmas',  Icons.local_hospital_rounded,    'puskesmas'),
  ('Minimarket', Icons.shopping_cart_rounded,     'indomaret'),
  ('SPBU',       Icons.local_gas_station_rounded, 'pertamina'),
  ('Bank/ATM',   Icons.atm_rounded,               'bank'),
  ('Kantor',     Icons.business_rounded,          'kantor desa'),
  ('Hotel',      Icons.hotel_rounded,             'hotel'),
];

const _kRecentKey    = 'lungo_recent_searches';
const _kFavoritesKey = 'lungo_favorites';

class DestinationScreen extends ConsumerStatefulWidget {
  const DestinationScreen({super.key});

  @override
  ConsumerState<DestinationScreen> createState() => _DestinationScreenState();
}

class _DestinationScreenState extends ConsumerState<DestinationScreen> {
  final _ctrl    = TextEditingController();
  final _mapCtrl = MapController();
  final _focus   = FocusNode();

  Timer? _debounce;
  bool   _searching    = false;
  bool   _isBooking    = false;
  bool   _loadingRoute = false;
  bool   _mapTapMode   = false;
  bool   _sheetIsOpen  = false;
  String? _activeCategory;

  final Map<String, List<SearchResult>> _cache = {};
  List<SearchResult> _results         = [];
  SearchResult?      _selected;
  List<LatLng>       _routePoints     = [];

  List<SearchResult> _recentSearches  = [];
  List<SearchResult> _favoritePlaces  = [];
  Set<String>        _favoriteKeys    = {};

  double _originLat = -6.9175;
  double _originLng = 107.6191;

  @override
  void initState() {
    super.initState();
    _initGps();
    _loadPrefs();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _initGps() async {
    final locState = ref.read(locationProvider);
    if (locState.loaded && locState.lat != null) {
      setState(() { _originLat = locState.lat!; _originLng = locState.lng!; });
      return;
    }
    try {
      final svc = await Geolocator.isLocationServiceEnabled();
      if (!svc) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm != LocationPermission.always && perm != LocationPermission.whileInUse) return;
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (mounted) {
        setState(() { _originLat = pos.latitude; _originLng = pos.longitude; });
        ref.read(locationProvider.notifier).update(pos.latitude, pos.longitude);
      }
    } catch (_) {}
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final recentRaw = prefs.getStringList(_kRecentKey)    ?? [];
    final favRaw    = prefs.getStringList(_kFavoritesKey) ?? [];

    final recent = recentRaw.map((s) {
      try { return SearchResult.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map)); }
      catch (_) { return null; }
    }).whereType<SearchResult>().toList();

    final favs = favRaw.map((s) {
      try { return SearchResult.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map)); }
      catch (_) { return null; }
    }).whereType<SearchResult>().toList();

    if (mounted) {
      setState(() {
        _recentSearches = recent;
        _favoritePlaces = favs;
        _favoriteKeys   = {for (final f in favs) f.coordKey};
      });
    }
  }

  Future<void> _addToRecent(SearchResult r) async {
    final updated = [r, ..._recentSearches.where((x) => x.coordKey != r.coordKey)].take(5).toList();
    setState(() => _recentSearches = updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRecentKey, updated.map((x) => jsonEncode(x.toJson())).toList());
  }

  Future<void> _toggleFavorite(SearchResult r) async {
    final key   = r.coordKey;
    final isFav = _favoriteKeys.contains(key);
    final updated = isFav
        ? _favoritePlaces.where((x) => x.coordKey != key).toList()
        : [r, ..._favoritePlaces];
    setState(() {
      _favoritePlaces = updated;
      _favoriteKeys   = {for (final f in updated) f.coordKey};
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kFavoritesKey, updated.map((x) => jsonEncode(x.toJson())).toList());
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _activeCategory = null;
    final trimmed = q.trim();
    if (trimmed.length < 2) {
      setState(() { _results = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(trimmed));
  }

  Future<void> _search(String q) async {
    if (_cache.containsKey(q)) {
      if (mounted) setState(() { _results = _cache[q]!; _searching = false; });
      return;
    }
    final results = await LocationSearchService.search(q, _originLat, _originLng);
    _cache[q] = results;
    if (mounted) setState(() { _results = results; _searching = false; });
  }

  void _searchCategory(String keyword, String label) {
    _ctrl.text = keyword;
    setState(() { _activeCategory = label; _searching = true; _results = []; _selected = null; });
    _focus.unfocus();
    _debounce?.cancel();
    _search(keyword);
  }

  void _select(SearchResult place) {
    _focus.unfocus();
    setState(() {
      _selected    = place;
      _results     = [];
      _ctrl.text   = place.name;
      _searching   = false;
      _routePoints = [];
      _mapTapMode  = false;
    });
    _addToRecent(place);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        try { _mapCtrl.move(LatLng(place.lat, place.lng), 15); } catch (_) {}
        _showConfirmationCard(place);
      }
    });

    _fetchRoute();
  }

  void _clearSearch() {
    _ctrl.clear();
    setState(() {
      _results     = [];
      _selected    = null;
      _searching   = false;
      _activeCategory = null;
      _routePoints = [];
      _mapTapMode  = false;
    });
    _focus.requestFocus();
  }

  int _localFare(double distKm) => math.max(14000, (distKm * 2100).round());

  Future<Map<String, dynamic>?> _fetchFareApi(double km) async {
    try {
      final res = await DioClient.create().get('/tariff/estimate', queryParameters: {
        'lat': _originLat,
        'lng': _originLng,
        'km': km,
      });
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchRoute() async {
    final dest = _selected;
    if (dest == null) return;
    setState(() => _loadingRoute = true);
    final route = await HereService.getRoute(
      LatLng(_originLat, _originLng),
      LatLng(dest.lat, dest.lng),
    );
    if (mounted) setState(() { _routePoints = route; _loadingRoute = false; });
  }

  void _enterMapTapMode() {
    setState(() {
      _mapTapMode  = true;
      _selected    = null;
      _routePoints = [];
      _ctrl.clear();
      _results = [];
      _searching = false;
    });
    _focus.unfocus();
  }

  Future<void> _onMapTap(TapPosition _, LatLng pos) async {
    if (!_mapTapMode) return;

    if (_sheetIsOpen && mounted) {
      Navigator.of(context).pop();
      _sheetIsOpen = false;
      await Future.delayed(const Duration(milliseconds: 150));
    }
    final place = SearchResult(
      name:     'Lokasi di Peta',
      address:  '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
      lat:      pos.latitude,
      lng:      pos.longitude,
      type:     'location',
      category: 'location',
      source:   'tap',
    );
    setState(() {
      _selected    = place;
      _ctrl.text   = 'Lokasi di Peta';
      _routePoints = [];

    });
    if (mounted) _showConfirmationCard(place);
    _fetchRoute();
  }

  void _showConfirmationCard(SearchResult place) {
    final isMapTap = _mapTapMode;
    _sheetIsOpen = true;
    final dist      = place.distanceTo(_originLat, _originLng);
    var   fare      = _localFare(dist);
    var   zonaLabel = '';
    var   tarifKm   = 0;
    var   feeLungoAmt = 0;
    var   fareLoaded  = false;

    showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          if (!fareLoaded) {
            fareLoaded = true;
            _fetchFareApi(dist).then((data) {
              if (data != null && ctx.mounted) {
                setModal(() {
                  fare        = (data['farePassenger'] as num).toInt();
                  zonaLabel   = data['namaZona'] as String? ?? '';
                  tarifKm     = (data['tarifPerKm'] as num).toInt();
                  feeLungoAmt = (data['feeLungo']   as num).toInt();
                });
              }
            });
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: _typeBg(place.type),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_typeIcon(place.type), color: _typeColor(place.type), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            style: const TextStyle(
                              fontFamily: 'Satoshi', fontWeight: FontWeight.w700,
                              fontSize: 16, color: Color(0xFF0D1240),
                            ),
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                          ),
                          if (place.address.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              place.address,
                              style: const TextStyle(
                                fontFamily: 'Satoshi', fontSize: 12, color: Color(0xFF6B7280),
                              ),
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _FareChip(
                        icon: Icons.route_rounded,
                        label: '${dist.toStringAsFixed(1)} km',
                        color: AppColors.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      _FareChip(
                        icon: Icons.payments_rounded,
                        label: _idrFmt.format(fare),
                        color: AppColors.online,
                      ),
                      const SizedBox(width: 8),
                      _FareChip(
                        icon: Icons.access_time_rounded,
                        label: '~${(dist * 3).round().clamp(1, 60)} menit',
                        color: AppColors.secondaryColor,
                      ),
                    ],
                  ),
                ),

                if (zonaLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          const Icon(Icons.map_outlined, size: 13, color: Color(0xFF6B7280)),
                          const SizedBox(width: 4),
                          Text(zonaLabel, style: const TextStyle(fontFamily: 'Satoshi', fontSize: 11, color: Color(0xFF6B7280))),
                        ]),
                        Text(
                          'Rp ${NumberFormat('#,###', 'id_ID').format(tarifKm)}/km  +  Rp ${NumberFormat('#,###', 'id_ID').format(feeLungoAmt)} fee',
                          style: const TextStyle(fontFamily: 'Satoshi', fontSize: 11, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 4),
                Text(
                  'Tarif estimasi Kemenhub — bisa berubah sesuai jarak aktual',
                  style: const TextStyle(
                    fontFamily: 'Satoshi', fontSize: 10, color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _bookRide();
                    },
                    icon: const Icon(Icons.electric_moped_rounded, size: 18),
                    label: const Text(
                      'Pesan Ojek ke Sini',
                      style: TextStyle(fontFamily: 'Satoshi', fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentColor,
                      foregroundColor: AppColors.primaryDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (isMapTap) {
                      setState(() { _selected = null; _routePoints = []; });
                    } else {
                      setState(() { _selected = null; _ctrl.clear(); _activeCategory = null; _routePoints = []; });
                      _focus.requestFocus();
                    }
                  },
                  child: const Text(
                    'Pilih Lokasi Lain',
                    style: TextStyle(fontFamily: 'Satoshi', fontSize: 14, color: Color(0xFF9CA3AF)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() { _sheetIsOpen = false; });
  }

  Future<void> _bookRide() async {
    final dest = _selected;
    if (dest == null || _isBooking) return;
    setState(() => _isBooking = true);
    try {
      final response = await DioClient.create().post('/booking/rides', data: {
        'originLat':          _originLat,
        'originLng':          _originLng,
        'destinationLat':     dest.lat,
        'destinationLng':     dest.lng,
        'originAddress':      'Lokasi Saya',
        'destinationAddress': dest.name,
      });
      final rideId = response.data['id'] as String?;
      if (!mounted) return;
      if (rideId != null) {
        ref.read(bookingProvider.notifier).startSearching(
          rideId: rideId,
          originLat: _originLat,
          originLng: _originLng,
          destLat: dest.lat,
          destLng: dest.lng,
        );
        Navigator.pushReplacementNamed(context, '/waiting', arguments: {
          'rideId':       rideId,
          'passengerLat': _originLat,
          'passengerLng': _originLng,
          'destLat':      dest.lat,
          'destLng':      dest.lng,
          'destAddress':  dest.name,
        });
      }
    } catch (_) {
      if (!mounted) return;
      LungoSnackbar.error(context, 'Gagal membuat pesanan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText     = _ctrl.text.trim().length >= 2;
    final showResults = hasText && (_results.isNotEmpty || _searching);
    final showMap     = (_selected != null || _mapTapMode) && !showResults;

    if (_mapTapMode) {
      return _buildFullMapTapMode();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pilih Tujuan',
          style: TextStyle(
            fontFamily: 'Satoshi', fontWeight: FontWeight.w700,
            fontSize: 17, color: AppColors.primaryColor,
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: AppColors.primaryColor, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          autofocus: true,
                          onChanged: _onChanged,
                          style: const TextStyle(
                            fontFamily: 'Satoshi', fontSize: 14, color: Color(0xFF0D1240),
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Cari tujuan, tempat, atau alamat...',
                            hintStyle: TextStyle(
                              fontFamily: 'Satoshi', fontSize: 14, color: Color(0xFF9CA3AF),
                            ),
                            border: InputBorder.none,
                            filled: false,
                            counterText: '',
                          ),
                        ),
                      ),
                      if (_ctrl.text.isNotEmpty)
                        GestureDetector(
                          onTap: _clearSearch,
                          child: const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.close_rounded, color: Color(0xFF9CA3AF), size: 18),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              SizedBox(
                height: 40,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _kCategories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final (label, icon, keyword) = _kCategories[i];
                    final active = _activeCategory == label;
                    return GestureDetector(
                      onTap: () => _searchCategory(keyword, label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: active ? AppColors.primaryColor : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active ? AppColors.primaryColor : const Color(0xFFDDE3F5),
                            width: 1.2,
                          ),
                          boxShadow: active
                              ? [const BoxShadow(color: Color(0x300540F2), blurRadius: 6, offset: Offset(0, 2))]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 13, color: active ? Colors.white : AppColors.primaryColor),
                            const SizedBox(width: 5),
                            Text(
                              label,
                              style: TextStyle(
                                fontFamily: 'Satoshi', fontSize: 12, fontWeight: FontWeight.w600,
                                color: active ? Colors.white : const Color(0xFF374151),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 6),
              const Divider(height: 1, color: Color(0xFFEEF1FF)),
              if (_searching)
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.primaryColor,
                  backgroundColor: AppColors.primaryLight,
                ),

              Expanded(
                child: showResults
                    ? _buildResults()
                    : showMap
                        ? _buildMapView()
                        : _buildHomeState(),
              ),
            ],
          ),

          if (showMap && _selected != null && !_mapTapMode)
            Positioned(
              left: 16, right: 16, bottom: 24,
              child: _ConfirmButton(
                place: _selected!,
                originLat: _originLat,
                originLng: _originLng,
                isFavorite: _favoriteKeys.contains(_selected!.coordKey),
                isLoading: _isBooking || _loadingRoute,
                onConfirm: _bookRide,
                fetchFareApi: _fetchFareApi,
                onFavorite: () => _toggleFavorite(_selected!),
              ),
            ),

          if (_isBooking && !showMap)
            Container(
              color: Colors.black.withValues(alpha: 0.25),
              child: const Center(child: CircularProgressIndicator(color: AppColors.primaryColor)),
            ),
        ],
      ),
    );
  }

  Widget _buildFullMapTapMode() {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: LatLng(_originLat, _originLng),
              initialZoom: 15,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: ApiConstants.hereTileUrl,
                userAgentPackageName: 'com.lungo.app',
                maxNativeZoom: 19, maxZoom: 19,
              ),
              MarkerLayer(markers: [
                Marker(
                  point: LatLng(_originLat, _originLng),
                  width: 44, height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [BoxShadow(color: AppColors.primaryColor.withValues(alpha: 0.4), blurRadius: 10)],
                    ),
                    child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ]),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _mapTapMode = false),
                          child: const Icon(Icons.arrow_back_rounded, color: AppColors.primaryColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Tap peta untuk pilih tujuan',
                            style: TextStyle(
                              fontFamily: 'Satoshi', fontWeight: FontWeight.w600,
                              fontSize: 14, color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'TAP PETA',
                            style: TextStyle(
                              fontFamily: 'Satoshi', fontWeight: FontWeight.w700,
                              fontSize: 10, color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Center(
            child: Icon(Icons.add_rounded, color: AppColors.primaryColor, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeState() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [

        GestureDetector(
          onTap: _enterMapTapMode,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.map_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pilih di Peta',
                        style: TextStyle(
                          fontFamily: 'Satoshi', fontWeight: FontWeight.w700,
                          fontSize: 14, color: AppColors.primaryDark,
                        ),
                      ),
                      Text(
                        'Tap langsung di peta untuk menandai tujuan',
                        style: TextStyle(
                          fontFamily: 'Satoshi', fontSize: 11, color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.primaryColor, size: 20),
              ],
            ),
          ),
        ),

        if (_favoritePlaces.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionHeader(title: 'Favorit', icon: Icons.star_rounded, color: const Color(0xFFD97706)),
          const SizedBox(height: 8),
          ..._favoritePlaces.take(5).map((r) => _ResultTile(
                result: r, isFavorite: true,
                originLat: _originLat, originLng: _originLng,
                onTap: () => _select(r), onFavorite: () => _toggleFavorite(r),
              )),
        ],

        if (_recentSearches.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionHeader(title: 'Pencarian Terakhir', icon: Icons.history_rounded, color: AppColors.primaryColor),
          const SizedBox(height: 8),
          ..._recentSearches.map((r) => _ResultTile(
                result: r, isFavorite: _favoriteKeys.contains(r.coordKey),
                originLat: _originLat, originLng: _originLng,
                onTap: () => _select(r), onFavorite: () => _toggleFavorite(r),
              )),
        ],

        if (_recentSearches.isEmpty && _favoritePlaces.isEmpty) ...[
          const SizedBox(height: 48),
          Center(
            child: Column(
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                  child: const Icon(Icons.place_outlined, size: 36, color: AppColors.primaryColor),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cari tujuan kamu',
                  style: TextStyle(fontFamily: 'Satoshi', fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0D1240)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ketik nama tempat, pilih kategori, atau tap "Pilih di Peta"',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Satoshi', fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResults() {
    if (_searching) {
      return const Column(
        children: [
          SizedBox(height: 32),
          CircularProgressIndicator(color: AppColors.primaryColor, strokeWidth: 3),
          SizedBox(height: 16),
          Text('Mencari lokasi...', style: TextStyle(fontFamily: 'Satoshi', fontSize: 13, color: Color(0xFF9CA3AF))),
        ],
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Color(0xFFD1D5DB)),
            SizedBox(height: 12),
            Text('Tempat tidak ditemukan', style: TextStyle(fontFamily: 'Satoshi', fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF374151))),
            SizedBox(height: 6),
            Text('Coba kata kunci lain atau lebih spesifik', style: TextStyle(fontFamily: 'Satoshi', fontSize: 12, color: Color(0xFF9CA3AF))),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
      itemBuilder: (_, i) {
        final r = _results[i];
        return _ResultTile(
          result: r, isFavorite: _favoriteKeys.contains(r.coordKey),
          originLat: _originLat, originLng: _originLng,
          onTap: () => _select(r), onFavorite: () => _toggleFavorite(r),
        );
      },
    );
  }

  Widget _buildMapView() {
    final dest = _selected!;
    final hasRoute = _routePoints.length >= 2;

    final centerLat = (_originLat + dest.lat) / 2;
    final centerLng = (_originLng + dest.lng) / 2;

    return FlutterMap(
      mapController: _mapCtrl,
      options: MapOptions(
        initialCenter: LatLng(centerLat, centerLng),
        initialZoom: 14,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onTap: (tp, pt) {

          final newPlace = SearchResult(
            name:     'Lokasi di Peta',
            address:  '${pt.latitude.toStringAsFixed(5)}, ${pt.longitude.toStringAsFixed(5)}',
            lat:      pt.latitude,
            lng:      pt.longitude,
            type:     'location',
            category: 'location',
            source:   'tap',
          );
          setState(() { _selected = newPlace; _ctrl.text = 'Lokasi di Peta'; _routePoints = []; });
          _fetchRoute();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: ApiConstants.hereTileUrl,
          userAgentPackageName: 'com.lungo.app',
          maxNativeZoom: 19, maxZoom: 19,
        ),

        PolylineLayer(polylines: [
          if (hasRoute)
            Polyline(
              points: _routePoints,
              strokeWidth: 5,
              color: AppColors.primaryColor.withValues(alpha: 0.75),
              borderStrokeWidth: 2,
              borderColor: Colors.white.withValues(alpha: 0.6),
            )
          else
            Polyline(
              points: [LatLng(_originLat, _originLng), LatLng(dest.lat, dest.lng)],
              strokeWidth: 4,
              color: AppColors.primaryColor.withValues(alpha: 0.4),
              isDotted: true,
            ),
        ]),

        MarkerLayer(markers: [

          Marker(
            point: LatLng(_originLat, _originLng),
            width: 44, height: 44,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [BoxShadow(color: AppColors.primaryColor.withValues(alpha: 0.4), blurRadius: 10)],
              ),
              child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
            ),
          ),

          Marker(
            point: LatLng(dest.lat, dest.lng),
            width: 52, height: 64,
            alignment: const Alignment(0, -1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _typeColor(dest.type),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [BoxShadow(color: _typeColor(dest.type).withValues(alpha: 0.45), blurRadius: 12)],
                  ),
                  child: Icon(_typeIcon(dest.type), color: Colors.white, size: 24),
                ),
                Container(width: 2, height: 10, color: _typeColor(dest.type)),
              ],
            ),
          ),
        ]),
      ],
    );
  }
}

class _FareChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _FareChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontFamily: 'Satoshi', fontWeight: FontWeight.w700, fontSize: 12, color: color),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

class _ResultTile extends StatelessWidget {
  final SearchResult result;
  final bool         isFavorite;
  final double       originLat;
  final double       originLng;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  const _ResultTile({
    required this.result, required this.isFavorite,
    required this.originLat, required this.originLng,
    required this.onTap, required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final dist = result.distanceTo(originLat, originLng);
    final distLabel = dist < 0.1 ? '${(dist * 1000).round()}m'
        : dist < 10 ? '${dist.toStringAsFixed(1)}km' : '${dist.round()}km';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: AppColors.primaryColor.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: _typeBg(result.type), borderRadius: BorderRadius.circular(12)),
              child: Icon(_typeIcon(result.type), color: _typeColor(result.type), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.name,
                    style: const TextStyle(fontFamily: 'Satoshi', fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0D1240)),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _typeLabel(result.type),
                    style: const TextStyle(fontFamily: 'Satoshi', fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                  if (result.address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _shortAddress(result.address),
                      style: const TextStyle(fontFamily: 'Satoshi', fontSize: 11, color: Color(0xFF6B7280)),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: onFavorite,
                  child: Icon(
                    isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 20,
                    color: isFavorite ? const Color(0xFFD97706) : const Color(0xFFD1D5DB),
                  ),
                ),
                const SizedBox(height: 4),
                Text(distLabel, style: const TextStyle(fontFamily: 'Satoshi', fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) => switch (type) {
    'restaurant' => 'Restoran',
    'fast_food'  => 'Makanan Cepat Saji',
    'food_court' => 'Food Court',
    'cafe'       => 'Kafe',
    'school'     => 'Sekolah',
    'university' => 'Universitas',
    'college'    => 'Kampus',
    'hospital'   => 'Rumah Sakit',
    'clinic' || 'doctors' => 'Klinik',
    'pharmacy'   => 'Apotek',
    'bank'       => 'Bank',
    'atm'        => 'ATM',
    'fuel'       => 'SPBU',
    'supermarket' => 'Supermarket',
    'convenience' || 'minimarket' => 'Minimarket',
    'place_of_worship' || 'mosque' => 'Masjid / Tempat Ibadah',
    'hotel'      => 'Hotel',
    'guest_house' => 'Penginapan',
    'residential' => 'Perumahan',
    'house'      => 'Rumah',
    _            => type.replaceAll('_', ' '),
  };

  String _shortAddress(String address) =>
      address.split(',').take(3).map((s) => s.trim()).join(', ');
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionHeader({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(title, style: TextStyle(fontFamily: 'Satoshi', fontWeight: FontWeight.w700, fontSize: 12, color: color, letterSpacing: 0.3)),
    ],
  );
}

class _ConfirmButton extends StatefulWidget {
  final SearchResult place;
  final double       originLat;
  final double       originLng;
  final bool         isFavorite;
  final VoidCallback onConfirm;
  final VoidCallback onFavorite;
  final bool         isLoading;
  final Future<Map<String, dynamic>?> Function(double km) fetchFareApi;

  const _ConfirmButton({
    required this.place,
    required this.originLat,
    required this.originLng,
    required this.isFavorite,
    required this.onConfirm,
    required this.onFavorite,
    required this.isLoading,
    required this.fetchFareApi,
  });

  @override
  State<_ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<_ConfirmButton> {
  int?    _apiFare;
  String  _apiZona = '';
  int     _tarifKm = 0;

  @override
  void initState() {
    super.initState();
    _loadFare();
  }

  @override
  void didUpdateWidget(_ConfirmButton old) {
    super.didUpdateWidget(old);
    if (old.place.coordKey != widget.place.coordKey) _loadFare();
  }

  Future<void> _loadFare() async {
    final dist = widget.place.distanceTo(widget.originLat, widget.originLng);
    final data = await widget.fetchFareApi(dist);
    if (data != null && mounted) {
      setState(() {
        _apiFare = (data['farePassenger'] as num).toInt();
        _apiZona = data['namaZona']  as String? ?? '';
        _tarifKm = (data['tarifPerKm'] as num).toInt();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dist      = widget.place.distanceTo(widget.originLat, widget.originLng);
    final localFare = math.max(14000, (dist * 2100).round());
    final fare      = _apiFare ?? localFare;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: _typeBg(widget.place.type), borderRadius: BorderRadius.circular(11)),
                child: Icon(_typeIcon(widget.place.type), color: _typeColor(widget.place.type), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.place.name,
                      style: const TextStyle(fontFamily: 'Satoshi', fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0D1240)),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.place.address.isNotEmpty)
                      Text(
                        widget.place.address.split(',').first.trim(),
                        style: const TextStyle(fontFamily: 'Satoshi', fontSize: 11, color: Color(0xFF9CA3AF)),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: widget.onFavorite,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    widget.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 24,
                    color: widget.isFavorite ? const Color(0xFFD97706) : const Color(0xFFD1D5DB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              _FareChip(icon: Icons.route_rounded, label: '${dist.toStringAsFixed(1)} km', color: AppColors.primaryColor),
              const SizedBox(width: 8),
              _FareChip(icon: Icons.payments_rounded, label: NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(fare), color: AppColors.online),
            ],
          ),

          if (_apiZona.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.map_outlined, size: 12, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 4),
                  Text(_apiZona, style: const TextStyle(fontFamily: 'Satoshi', fontSize: 11, color: Color(0xFF6B7280))),
                ]),
                Text(
                  'Rp ${NumberFormat('#,###', 'id_ID').format(_tarifKm)}/km',
                  style: const TextStyle(fontFamily: 'Satoshi', fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.isLoading ? null : widget.onConfirm,
              icon: widget.isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.electric_moped_rounded, size: 18),
              label: Text(
                widget.isLoading ? 'Memproses...' : 'Pesan Ojek ke Sini',
                style: const TextStyle(fontFamily: 'Satoshi', fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
