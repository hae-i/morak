import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../locator.dart';
import '../../models/meetup_place.dart';
import '../../models/place_map_center.dart';
import '../../repositories/place_search_repository.dart';
import '../../utils/ui_utils.dart';
import '../../widgets/common/common_button.dart';
import '../../widgets/common/common_widgets.dart';
import '../../widgets/maps/expandable_places_map.dart';
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
  final bool nearbySearch;
  const PlacePickerScreen({
    super.key,
    required this.groupId,
    this.initialQuery = '',
    this.initialPlace,
    this.repository,
    this.fullScreen = false,
    this.initialCenter,
    this.initialResults = const [],
    this.initialMode = 'place',
    this.nearbySearch = true,
  });
  @override
  State<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends State<PlacePickerScreen> {
  late final TextEditingController _query;
  late final PlaceSearchRepository _repository;
  late String _lastQuery;
  Timer? _debounce;
  MeetupPlace? _selected;
  PlaceMapCenter? _center;
  List<MeetupPlace> _results = [];
  bool _loading = false;
  String? _error;
  bool _searched = false;
  bool _nearby = true;
  String _mode = 'place';
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? locator<PlaceSearchRepository>();
    _selected = widget.initialPlace;
    _mode = widget.initialMode;
    _nearby = widget.nearbySearch;
    _results = List.of(widget.initialResults);
    _searched = _results.isNotEmpty;
    _center = widget.initialCenter;
    _lastQuery = widget.initialQuery;
    _query = TextEditingController(text: widget.initialQuery)
      ..addListener(_queryChanged);
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
    super.dispose();
  }

  Future<void> _search({bool automatic = false}) async {
    _debounce?.cancel();
    if (_loading) return;
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
      _error = null;
    });
    try {
      final places = await _repository.search(
        groupId: widget.groupId,
        query: query,
        mode: _mode,
        center: _nearby ? _center : null,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = places;
        _searched = true;
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
      _loading = false;
      _error = null;
      _results = [];
      _searched = false;
    });
  }

  void _changeMode(String mode) {
    _debounce?.cancel();
    _generation++;
    setState(() {
      _mode = mode;
      _loading = false;
      _results = [];
      _error = null;
      _searched = false;
    });
    if (_query.text.trim().isNotEmpty) _search();
  }

  Future<void> _expand() async {
    _debounce?.cancel();
    _generation++;
    setState(() => _loading = false);
    FocusScope.of(context).unfocus();
    final place = await Navigator.push<MeetupPlace>(
      context,
      MaterialPageRoute(
        builder: (_) => PlacePickerScreen(
          groupId: widget.groupId,
          initialQuery: _query.text,
          initialPlace: _selected,
          repository: _repository,
          initialCenter: _center,
          initialResults: _results,
          initialMode: _mode,
          nearbySearch: _nearby,
          fullScreen: true,
        ),
      ),
    );
    if (mounted && place != null) Navigator.pop(context, place);
  }

  List<PlacePin> get _pins => (_results.isNotEmpty ? _results : [?_selected])
      .map((p) => PlacePin(place: p, visits: []))
      .toList();

  void _manualPin(double latitude, double longitude) => _select(
    MeetupPlace(
      name: _query.text.trim().isEmpty
          ? '직접 선택한 장소'
          : _query.text.trim().substring(
              0,
              _query.text.trim().length.clamp(0, 200),
            ),
      address: '',
      latitude: latitude,
      longitude: longitude,
      source: 'manual_pin',
    ),
  );

  Widget _map({required bool expandable}) => expandable
      ? ExpandablePlacesMap(
          pins: _pins,
          initialCenter: _center,
          onExpand: _expand,
          onCameraIdle: (center) => _center = center,
          onPinTap: (pin) => _select(pin.place),
          onLongPress: _manualPin,
        )
      : PlacesMap(
          pins: _pins,
          initialCenter: _center,
          onCameraIdle: (center) => _center = center,
          onPinTap: (pin) => _select(pin.place),
          onLongPress: _manualPin,
        );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _query,
                hint: _mode == 'address' ? '도로명 또는 지번 주소' : '장소 이름을 입력하세요',
              ),
            ),
            const SizedBox(width: 10),
            Button(
              text: '검색',
              width: 76,
              onPressed: _loading ? null : () => _search(),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            ChoiceChip(
              label: const Text('장소'),
              selected: _mode == 'place',
              onSelected: (_) => _changeMode('place'),
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              label: const Text('주소'),
              selected: _mode == 'address',
              onSelected: (_) => _changeMode('address'),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                _generation++;
                setState(() {
                  _nearby = !_nearby;
                  _loading = false;
                });
                if (_query.text.trim().isNotEmpty) _search();
              },
              child: Text(_nearby ? '지도 주변' : '전체 지역'),
            ),
          ],
        ),
      ],
    ),
  );

  List<Widget> _searchContent() => [
    if (_loading) const LinearProgressIndicator(),
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
      const Text('검색 결과가 없어요. 지역 이름을 함께 입력하거나 장소·주소 검색을 바꿔 보세요.'),
    for (final place in _results)
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.place_rounded, color: Color(0xFFE8474F)),
        title: Text(place.name),
        subtitle: Text(place.address),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _select(place),
      ),
    if (_selected != null)
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.place_rounded, color: Color(0xFFE8474F)),
        title: Text(_selected!.name),
        subtitle: Text(
          _selected!.address.isEmpty
              ? '직접 선택한 위치 · 지역 순위에서 제외'
              : _selected!.address,
        ),
      ),
  ];

  Widget _confirm() => Button(
    text: '이 장소 선택하기',
    onPressed: _selected == null
        ? null
        : () => Navigator.pop(context, _selected),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppConstants.scaffoldBackground,
    appBar: AppBar(
      title: const Text('만난 장소 찾기'),
      backgroundColor: AppConstants.scaffoldBackground,
      scrolledUnderElevation: 0,
    ),
    body: SafeArea(
      child: Column(
        children: [
          _header(),
          Expanded(
            child: widget.fullScreen
                ? LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      children: [
                        Positioned.fill(child: _map(expandable: false)),
                        Positioned(
                          top: 8,
                          left: 16,
                          right: 16,
                          child: Center(
                            child: Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              elevation: 2,
                              child: TextButton(
                                onPressed: _loading ? null : () => _search(),
                                child: const Text('이 지도 위치에서 다시 검색'),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: Material(
                            color: AppConstants.cardBackground,
                            elevation: 4,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_loading ||
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
                                      padding: EdgeInsets.only(bottom: 12),
                                      child: Text(
                                        '검색 결과를 선택하거나 지도를 길게 눌러 핀을 찍어 주세요.',
                                      ),
                                    ),
                                  _confirm(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: SizedBox(
                          height: 320,
                          child: _map(expandable: true),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          '두 글자 이상 입력하면 검색 결과를 보여드려요.\n검색되지 않는 곳은 지도를 길게 눌러 선택할 수 있어요.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppConstants.textBody,
                          ),
                        ),
                      ),
                      ..._searchContent(),
                    ],
                  ),
          ),
          if (!widget.fullScreen)
            Padding(padding: const EdgeInsets.all(16), child: _confirm()),
        ],
      ),
    ),
  );
}
