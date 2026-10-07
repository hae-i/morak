import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../models/meetup_place.dart';
import '../../repositories/group_repository.dart';
import '../common/common_widgets.dart';
import '../common/request_error_view.dart';
import '../maps/places_map.dart';

class GroupPlacesSection extends StatefulWidget {
  final String groupId;
  final GroupRepository repository;
  const GroupPlacesSection({
    super.key,
    required this.groupId,
    required this.repository,
  });
  @override
  State<GroupPlacesSection> createState() => _GroupPlacesSectionState();
}

class _GroupPlacesSectionState extends State<GroupPlacesSection> {
  PlaceHistory? _history;
  bool _loading = true;
  bool _failed = false;
  String? _district;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(GroupPlacesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId ||
        oldWidget.repository != widget.repository) {
      _history = null;
      _district = null;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final history = await widget.repository.fetchPlaceHistory(widget.groupId);
      if (mounted && generation == _generation) {
        setState(() => _history = history);
      }
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _showVisits(PlacePin pin) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.cardBackground,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                pin.place.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                pin.place.address,
                style: const TextStyle(color: AppConstants.textBody),
              ),
              const SizedBox(height: 20),
              for (final visit in pin.visits)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(visit.title),
                  subtitle: Text(visit.date.split('T').first),
                  leading: const Icon(Icons.auto_stories_outlined),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_failed) {
      return RequestErrorView(message: '만난 장소를 불러오지 못했습니다.', onRetry: _load);
    }
    final history = _history ?? PlaceHistory([]);
    if (history.visits.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('우리가 만난 장소'),
          SizedBox(height: 12),
          Text(
            '만남을 기록할 때 지도에서 장소를 선택하면\n우리의 장소가 여기에 쌓여요.',
            style: TextStyle(color: AppConstants.textBody, height: 1.5),
          ),
        ],
      );
    }
    final filtered = _district == null
        ? history
        : PlaceHistory(
            history.visits.where((visit) => visit.place.district == _district),
          );
    final districts = history.districts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('우리가 만난 장소'),
        const SizedBox(height: 12),
        Text(
          '장소를 남긴 만남 ${history.visits.map((v) => v.meetupId).toSet().length}번',
          style: const TextStyle(color: AppConstants.textBody),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 260,
            child: PlacesMap(pins: filtered.pins, onPinTap: _showVisits),
          ),
        ),
        const SizedBox(height: 12),
        for (final pin in filtered.pins)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place_outlined),
            title: Text(pin.place.name),
            subtitle: Text('${pin.visits.length}번 만났어요'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showVisits(pin),
          ),
        const SizedBox(height: 24),
        const SectionTitle('우리가 자주 만난 지역'),
        const SizedBox(height: 8),
        const Text(
          '장소의 주소를 기준으로 지역별 만남 횟수를 세어요.',
          style: TextStyle(color: AppConstants.textBody, fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (districts.isEmpty)
          const Text('지역을 확인할 수 있는 장소가 아직 없어요.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('전체 장소'),
                selected: _district == null,
                onSelected: (_) => setState(() => _district = null),
              ),
              for (var i = 0; i < districts.length; i++)
                ChoiceChip(
                  label: Text(
                    '${i + 1}. ${districts[i].name} · ${districts[i].count}번',
                  ),
                  selected: _district == districts[i].name,
                  onSelected: (selected) => setState(
                    () => _district = selected ? districts[i].name : null,
                  ),
                ),
            ],
          ),
        if (history.unclassifiedMeetups > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '주소로 지역을 확인할 수 없는 만남 ${history.unclassifiedMeetups}번은 지역 순위에서 제외했어요.',
              style: const TextStyle(
                color: AppConstants.textBody,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}
