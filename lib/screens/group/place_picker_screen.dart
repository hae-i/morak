import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../locator.dart';
import '../../models/meetup_place.dart';
import '../../repositories/place_search_repository.dart';
import '../../utils/ui_utils.dart';
import '../../widgets/common/common_button.dart';
import '../../widgets/common/common_widgets.dart';
import '../../widgets/maps/places_map.dart';

class PlacePickerScreen extends StatefulWidget {
  final String groupId;
  final String initialQuery;
  final MeetupPlace? initialPlace;
  final PlaceSearchRepository? repository;
  const PlacePickerScreen({
    super.key,
    required this.groupId,
    this.initialQuery = '',
    this.initialPlace,
    this.repository,
  });
  @override
  State<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends State<PlacePickerScreen> {
  late final TextEditingController _query;
  late final PlaceSearchRepository _repository;
  MeetupPlace? _selected;
  List<MeetupPlace> _results = [];
  bool _loading = false;
  bool _failed = false;
  bool _searched = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? locator<PlaceSearchRepository>();
    _selected = widget.initialPlace;
    _query = TextEditingController(text: widget.initialQuery)
      ..addListener(_queryChanged);
  }

  void _queryChanged() {
    _generation++;
    setState(() {
      _loading = false;
      _failed = false;
      _searched = false;
      _results = [];
    });
  }

  @override
  void dispose() {
    _generation++;
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_loading) return;
    final query = _query.text.trim();
    if (query.isEmpty || query.length > 100) {
      UiUtils.showWarningDialog(
        context: context,
        title: '검색어를 확인해 주세요',
        message: '지역과 장소 이름을 100자 이내로 입력해 주세요.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final places = await _repository.search(
        groupId: widget.groupId,
        query: query,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = places;
        _searched = true;
      });
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _select(MeetupPlace place) => setState(() => _selected = place);

  @override
  Widget build(BuildContext context) {
    final mapPlaces = _selected == null ? _results : [_selected!];
    return Scaffold(
      backgroundColor: AppConstants.scaffoldBackground,
      appBar: AppBar(
        title: const Text('만난 장소 찾기'),
        backgroundColor: AppConstants.scaffoldBackground,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _query,
                      hint: '예) 송파구 카페 이름',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Button(
                    text: '검색',
                    width: 80,
                    onPressed: _loading ? null : _search,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      height: 250,
                      child: PlacesMap(
                        pins: mapPlaces
                            .map((p) => PlacePin(place: p, visits: []))
                            .toList(),
                        onPinTap: (pin) => _select(pin.place),
                        onLongPress: (latitude, longitude) => _select(
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
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '검색 결과에서 장소를 선택해 주세요.\n검색되지 않는 장소는 지도를 길게 눌러 선택할 수 있어요.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppConstants.textBody,
                      height: 1.5,
                    ),
                  ),
                  if (_selected != null) ...[
                    const SizedBox(height: 20),
                    const SectionTitle('선택한 장소'),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.place_rounded),
                      title: Text(_selected!.name),
                      subtitle: Text(
                        _selected!.address.isEmpty
                            ? '주소 없는 핀은 지역 통계에 포함되지 않아요.'
                            : _selected!.address,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_failed) ...[
                    const Text(
                      '장소를 검색하지 못했습니다. 잠시 후 다시 시도해 주세요.',
                      style: TextStyle(color: AppConstants.textBody),
                    ),
                    const SizedBox(height: 12),
                    Button(
                      text: '검색 다시 시도',
                      type: ButtonType.outlined,
                      onPressed: _search,
                    ),
                  ] else if (_searched && _results.isEmpty)
                    const Text('검색 결과가 없어요. 지역 이름과 장소 이름을 함께 입력해 보세요.')
                  else
                    for (final place in _results)
                      Card(
                        elevation: 0,
                        color: AppConstants.cardBackground,
                        child: ListTile(
                          title: Text(place.name),
                          subtitle: Text(place.address),
                          selected: identical(_selected, place),
                          trailing: identical(_selected, place)
                              ? const Icon(Icons.check_rounded)
                              : const Icon(Icons.chevron_right_rounded),
                          onTap: () => _select(place),
                        ),
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Button(
                text: '이 장소 선택하기',
                onPressed: _selected == null
                    ? null
                    : () => Navigator.pop(context, _selected),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
