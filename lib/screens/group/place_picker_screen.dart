import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../locator.dart';
import '../../models/meetup_place.dart';
import '../../models/place_map_center.dart';
import '../../repositories/place_search_repository.dart';
import '../../services/maps/current_map_location.dart';
import '../../utils/ui_utils.dart';
import '../../widgets/common/common_button.dart';
import '../../widgets/common/common_widgets.dart';
import '../../widgets/maps/places_map.dart';

class PlacePickerScreen extends StatefulWidget {
  final String groupId;
  final String initialQuery;
  final MeetupPlace? initialPlace;
  final PlaceSearchRepository? repository;
  final bool fullScreen;
  final PlaceMapCenter? initialCenter;
  final List<MeetupPlace> initialResults;
  final String initialMode;
  final Future<PlaceMapCenter?> Function()? locationLoader;
  const PlacePickerScreen({
    super.key,
    required this.groupId,
    this.initialQuery = '',
    this.initialPlace,
    this.repository,
    this.fullScreen = true,
    this.initialCenter,
    this.initialResults = const [],
    this.initialMode = 'auto',
    this.locationLoader,
  });
  @override
  State<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends State<PlacePickerScreen> {
  late final TextEditingController _query;
  late final TextEditingController _placeName;
  late final PlaceSearchRepository _repository;
  late String _lastQuery;
  Timer? _debounce;
  MeetupPlace? _selected;
  PlaceMapCenter? _center;
  PlaceMapCenter? _initialMapCenter;
  Future<PlaceMapCenter?> Function()? _readCenter;
  bool _locating = false;
  String? _locationNotice;
  bool _hasSearch = false;
  int _viewRevision = 0;
  int _searchRevision = 0;
  bool _resolvingAddress = false;
  String? _addressError;
  List<MeetupPlace> _results = [];
  bool _loading = false;
  String? _error;
  bool _searched = false;
  String _mode = 'auto';
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? locator<PlaceSearchRepository>();
    _selected = widget.initialPlace;
    _mode = widget.initialMode;
    _results = List.of(widget.initialResults);
    _searched = _results.isNotEmpty;
    _center =
        widget.initialCenter ??
        (_selected == null
            ? null
            : PlaceMapCenter(_selected!.latitude, _selected!.longitude));
    _initialMapCenter = _center;
    _placeName = TextEditingController(text: _selected?.name ?? '');
    _hasSearch = _searched;
    _lastQuery = widget.initialQuery;
    _query = TextEditingController(text: widget.initialQuery)
      ..addListener(_queryChanged);
    if (_center == null) {
      _locating = true;
      _initializeLocation();
    }
  }

  Future<void> _initializeLocation() async {
    PlaceMapCenter? center;
    try {
      center = await (widget.locationLoader ?? currentMapLocation)();
    } catch (_) {
      center = null;
    }
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (_viewRevision == 0 &&
          !_hasSearch &&
          _selected == null &&
          center != null) {
        _center = center;
        _initialMapCenter = center;
      }
      if (center == null && _viewRevision == 0) {
        _locationNotice = '현재 위치를 확인하지 못했어요. 지도를 이동해 검색해 주세요.';
      }
    });
    if (_query.text.trim().length >= 2 &&
        _query.text != widget.initialQuery &&
        !_hasSearch &&
        _selected == null) {
      _debounce?.cancel();
      _debounce = Timer(
        const Duration(milliseconds: 700),
        () => _search(automatic: true),
      );
    }
  }

  void _queryChanged() {
    if (_lastQuery == _query.text) return;
    _lastQuery = _query.text;
    _debounce?.cancel();
    _generation++;
    setState(() {
      _loading = false;
      _error = null;
      _searched = false;
      _hasSearch = false;
      _selected = null;
      _placeName.clear();
      _resolvingAddress = false;
      _addressError = null;
      _results = [];
    });
    if (_query.text.trim().length >= 2 && _query.text.trim().length <= 100) {
      _debounce = Timer(
        const Duration(milliseconds: 700),
        () => _search(automatic: true),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _generation++;
    _query.dispose();
    _placeName.dispose();
    super.dispose();
  }

  Future<void> _search({bool automatic = false}) async {
    _debounce?.cancel();
    if (_loading || _locating) return;
    final query = _query.text.trim();
    if (query.isEmpty || query.length > 100) {
      if (!automatic) {
        UiUtils.showWarningDialog(
          context: context,
          title: '검색어를 확인해 주세요',
          message: '지역과 장소 이름을 100자 이내로 입력해 주세요.',
        );
      }
      return;
    }
    if (!automatic) FocusScope.of(context).unfocus();
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _selected = null;
      _placeName.clear();
      _resolvingAddress = false;
      _addressError = null;
      _error = null;
    });
    try {
      final currentCenter = await _readCenter?.call();
      if (!mounted || generation != _generation) return;
      final center = currentCenter ?? _center;
      if (center == null) {
        throw const PlaceSearchException(
          '지도 위치를 확인하지 못했어요. 지도가 열린 후 다시 검색해 주세요.',
        );
      }
      final revision = _viewRevision;
      final places = await _repository.search(
        groupId: widget.groupId,
        query: query,
        mode: _mode,
        center: center,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _center = center;
        _results = places;
        _selected = null;
        _placeName.clear();
        _resolvingAddress = false;
        _addressError = null;
        _searched = true;
        _hasSearch = true;
        _searchRevision = revision;
        _locationNotice = null;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = error is PlaceSearchException
              ? error.message
              : '장소를 검색하지 못했습니다. 잠시 후 다시 시도해 주세요.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _select(MeetupPlace place) {
    _debounce?.cancel();
    _generation++;
    FocusScope.of(context).unfocus();
    setState(() {
      _selected = place;
      _placeName.text = place.name;
      _resolvingAddress = false;
      _addressError = null;
      _loading = false;
      _error = null;
      _results = [];
      _searched = false;
    });
  }

  List<PlacePin> get _pins => (_results.isNotEmpty ? _results : [?_selected])
      .map((p) => PlacePin(place: p, visits: []))
      .toList();

  void _manualPin(double latitude, double longitude) {
    _select(
      MeetupPlace(
        name: '직접 선택한 장소',
        address: '',
        latitude: latitude,
        longitude: longitude,
        source: 'manual_pin',
      ),
    );
    _resolvePinAddress();
  }

  Future<void> _resolvePinAddress() async {
    final pin = _selected;
    if (pin == null || pin.source != 'manual_pin' || _resolvingAddress) return;
    final generation = _generation;
    setState(() {
      _resolvingAddress = true;
      _addressError = null;
    });
    try {
      final place = await _repository.reverseGeocode(
        groupId: widget.groupId,
        center: PlaceMapCenter(pin.latitude, pin.longitude),
      );
      if (!mounted ||
          generation != _generation ||
          _selected?.coordinateKey != pin.coordinateKey) {
        return;
      }
      setState(() {
        // Use the name currently being edited; a late address must not replace it.
        final name = _placeName.text.trim();
        _selected = place.withName(
          name.isNotEmpty && name.length <= 200 ? name : pin.name,
        );
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () => _addressError = error is PlaceSearchException
              ? error.message
              : '주소를 가져오지 못했어요. 이름을 정해 핀 위치만 저장하거나 다시 시도해 주세요.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _resolvingAddress = false);
      }
    }
  }

  void _onUserMove() {
    if (!mounted) return;
    setState(() {
      _viewRevision++;
      _locationNotice = null;
    });
    _clearManualPinOnMove();
  }

  void _clearManualPinOnMove() {
    if (_selected?.source != 'manual_pin') return;
    _debounce?.cancel();
    _generation++;
    setState(() {
      _selected = null;
      _placeName.clear();
      _resolvingAddress = false;
      _addressError = null;
      _results = [];
      _searched = false;
      _error = null;
      _loading = false;
    });
  }

  Widget _map() => PlacesMap(
    pins: _pins,
    initialCenter: _initialMapCenter,
    fitPins: false,
    onCenterReaderReady: (reader) => _readCenter = reader,
    onCameraIdle: (center) => _center = center,
    onUserMove: _onUserMove,
    onPinTap: (pin) => _select(pin.place),
    onLongPress: _manualPin,
  );

  Widget _header() => Row(
    children: [
      SizedBox(
        width: 32,
        height: 40,
        child: IconButton(
          tooltip: '뒤로',
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      const SizedBox(width: 2),
      Expanded(
        child: CustomTextField(
          controller: _query,
          hint: '장소 검색하기',
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          onSubmitted: (_) => _search(),
        ),
      ),
      const SizedBox(width: 8),
      Tooltip(
        message: '검색',
        child: Button(
          text: '',
          width: 48,
          height: 48,
          icon: const Icon(Icons.turn_right_rounded, size: 26),
          onPressed: _loading || _locating ? null : () => _search(),
        ),
      ),
    ],
  );

  List<Widget> _searchContent() => [
    if (_loading || _locating) const LinearProgressIndicator(),
    if (_locationNotice != null)
      Text(_locationNotice!, style: const TextStyle(fontSize: 12)),
    if (_error != null) ...[
      Text(_error!, style: const TextStyle(color: AppConstants.textBody)),
      const SizedBox(height: 8),
      Button(
        text: '검색 다시 시도',
        type: ButtonType.outlined,
        onPressed: () => _search(),
      ),
    ],
    if (_searched && _results.isEmpty)
      const Text('일치하는 가게 이름이나 주소가 없어요. 정확한 상호명이나 지역을 함께 입력해 보세요.'),
    for (final place in _results)
      ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        minVerticalPadding: 2,
        leading: const Icon(Icons.place_rounded, color: Color(0xFFE8474F)),
        title: Text(place.name),
        subtitle: Text(place.address),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _select(place),
      ),
    if (_selected != null) ...[
      ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        minVerticalPadding: 2,
        leading: const Icon(Icons.place_rounded, color: Color(0xFFE8474F)),
        title: const Text('선택한 장소'),
        subtitle: Text(
          _selected!.address.isEmpty
              ? (_resolvingAddress ? '주소 확인 중…' : '주소 없이 핀 위치로 저장할 수 있어요')
              : _selected!.address,
        ),
      ),
      CustomTextField(
        controller: _placeName,
        hint: '장소 이름',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      if (_resolvingAddress) const LinearProgressIndicator(),
      if (_addressError != null) ...[
        Text(_addressError!, style: const TextStyle(fontSize: 12)),
        Button(
          text: '주소 다시 가져오기',
          height: 40,
          type: ButtonType.outlined,
          onPressed: _resolvePinAddress,
        ),
      ],
    ],
  ];

  void _confirmSelection() {
    final place = _selected;
    if (place == null) return;
    final name = _placeName.text.trim();
    if (name.isEmpty || name.length > 200) {
      UiUtils.showWarningDialog(
        context: context,
        title: '장소 이름을 확인해 주세요',
        message: '장소 이름을 1~200자 이내로 입력해 주세요.',
      );
      return;
    }
    Navigator.pop(context, name == place.name ? place : place.withName(name));
  }

  Widget _confirm() => Button(
    text: '이 장소 선택하기',
    onPressed: _selected == null || _loading || _locating
        ? null
        : _confirmSelection,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppConstants.scaffoldBackground,
    body: LayoutBuilder(
      builder: (context, constraints) {
        final inset = MediaQuery.paddingOf(context);
        return Stack(
          children: [
            Positioned.fill(child: _map()),
            Positioned(
              top: inset.top + 8,
              left: 12,
              right: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _header(),
                  if (_hasSearch && _viewRevision != _searchRevision) ...[
                    const SizedBox(height: 8),
                    Button(
                      text: '현재 위치에서 다시 검색',
                      width: 220,
                      height: 40,
                      onPressed: _loading ? null : () => _search(),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: inset.bottom + 8,
              child: Material(
                color: AppConstants.cardBackground,
                elevation: 4,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_locating ||
                          _locationNotice != null ||
                          _loading ||
                          _error != null ||
                          _searched ||
                          _selected != null ||
                          _results.isNotEmpty)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: constraints.maxHeight * 0.35,
                          ),
                          child: ListView(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            children: _searchContent(),
                          ),
                        ),
                      if (_selected == null &&
                          _results.isEmpty &&
                          !_loading &&
                          _error == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '검색하거나 지도를 길게 눌러 장소를 선택해 주세요',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppConstants.textBody,
                            ),
                          ),
                        ),
                      _confirm(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
