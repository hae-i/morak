// === 수정한 내용: 저장된 모임·프로필 사진을 로그인 권한으로 조회한다 ===
import '../../services/private_photos.dart';

// === 수정한 내용: 실패 시 내부 오류와 개인정보 대신 이해 가능한 재시도 메시지를 표시한다 ===
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/image_selection_recovery.dart';

import '../../constants/app_constants.dart';
import '../../widgets/common/common_widgets.dart';
import '../../widgets/common/common_button.dart';
import '../../locator.dart';
import '../../repositories/group_repository.dart';
import '../../repositories/meetup_repository.dart';
import '../../models/meetup_model.dart';
import '../../models/meetup_place.dart';
import '../../widgets/maps/places_map.dart';
import 'place_picker_screen.dart';
import '../../models/member_model.dart';
import '../../utils/data_refresh.dart';

class MeetupCreateScreen extends StatefulWidget {
  final String groupId;
  final MeetupModel? initialMeetup;

  const MeetupCreateScreen({
    super.key,
    required this.groupId,
    this.initialMeetup,
  });
  @override
  State<MeetupCreateScreen> createState() => _MeetupCreateScreenState();
}

class _MeetupCreateScreenState extends State<MeetupCreateScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _menuController = TextEditingController();

  MeetupPlace? _place;
  bool _placeChanged = false;

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  // === 수정한 내용: 필수 멤버 조회가 완료되기 전 기존 기록의 덮어쓰기를 차단한다 ===
  bool _isInitializing = true;
  bool _membersLoaded = false;
  List<MemberModel> _members = [];
  final Set<String> _selectedMemberIds = {};
  final ImagePicker _picker = ImagePicker();
  List<dynamic> _photos = [];

  // 🌟 제목 미입력 시 띄울 에러 메시지 상태 변수
  String? _titleError;

  final _groupRepo = locator<GroupRepository>();
  final _meetupRepo = locator<MeetupRepository>();

  @override
  void initState() {
    super.initState();
    // === 수정한 내용: 기존 입력값은 즉시 복원하여 지연 조회가 사용자의 편집을 덮지 않게 한다 ===
    final initial = widget.initialMeetup;
    if (initial != null) {
      _titleController.text = initial.title ?? '';
      _locationController.text = initial.location ?? '';
      _place = initial.place;
      _menuController.text = initial.menu ?? '';
      _selectedDate = DateTime.tryParse(initial.date) ?? _selectedDate;
      _photos = List<dynamic>.from(initial.photos);
      _selectedMemberIds.addAll(initial.attendanceMemberIds);
    }
    _locationController.addListener(_locationChanged);
    _loadInitialData();
  }

  void _locationChanged() {
    if (_place != null && _locationController.text.trim() != _place!.name) {
      setState(() {
        _place = null;
        _placeChanged = true;
      });
    }
  }

  Future<void> _pickPlace() async {
    final place = await Navigator.push<MeetupPlace>(
      context,
      MaterialPageRoute(
        builder: (_) => PlacePickerScreen(
          groupId: widget.groupId,
          initialQuery: _locationController.text,
          initialPlace: _place,
        ),
      ),
    );
    if (!mounted || place == null) return;
    setState(() {
      _place = place;
      _placeChanged = true;
      _locationController.text = place.name;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _menuController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isInitializing = true);
    try {
      final members = await _groupRepo.fetchGroupMembers(widget.groupId);
      if (!mounted) return;
      setState(() {
        // === 수정한 내용: 새 참석자는 현재 멤버만 선택하고 기존 탈퇴 참석자의 식별자는 보존한다 ===
        _members = members
            .where((m) => m.isActive || _selectedMemberIds.contains(m.id))
            .toList();
        _membersLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('멤버를 불러오지 못했습니다. 다시 시도해 주세요.'),
          action: SnackBarAction(label: '재시도', onPressed: _loadInitialData),
        ),
      );
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _pickDate() async {
    final DateTime? pickedDate = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        DateTime tempDate = _selectedDate;
        return Dialog(
          backgroundColor: AppConstants.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: AppConstants.primaryColor,
                      onPrimary: Colors.white,
                      onSurface: AppConstants.textTitle,
                    ),
                  ),
                  child: CalendarDatePicker(
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    onDateChanged: (DateTime newDate) {
                      tempDate = newDate;
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          color: AppConstants.textCaption,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, tempDate),
                      child: const Text(
                        '확인',
                        style: TextStyle(
                          color: AppConstants.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    // === 수정한 내용: 비동기 선택 창 종료 후 폐기된 화면을 갱신하지 않는다 ===
    if (mounted && pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await pickImagesWithRecovery(
        context: context,
        picker: _picker,
        multiple: true,
        target: 'meetup:${widget.groupId}:${widget.initialMeetup?.id ?? 'new'}',
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (mounted && pickedFiles.isNotEmpty) {
        setState(() => _photos.addAll(pickedFiles));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('사진을 불러오지 못했습니다. 다시 시도해 주세요.')));
      }
    }
  }

  Future<void> _saveMeetup() async {
    // === 수정한 내용: 초기 조회 실패와 중복 저장은 DB 쓰기 전에 차단한다 ===
    if (_isLoading || _isInitializing) return;
    if (!_membersLoaded) {
      await _loadInitialData();
      return;
    }
    setState(() => _titleError = null);

    final title = _titleController.text.trim();
    final location = _locationController.text.trim();
    final menu = _menuController.text.trim();

    // 🌟 알림창(WarningDialog) 대신 필수 입력란(제목) 하단에 빨간색 경고 문구 출력
    if (title.isEmpty) {
      setState(() => _titleError = '어떤 만남이었는지 제목을 입력해 주세요.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _meetupRepo.saveMeetup(
        groupId: widget.groupId,
        meetupId: widget.initialMeetup?.id,
        title: title,
        meetDate: _selectedDate.toIso8601String(),
        location: location,
        menu: menu,
        place: _place,
        updatePlace: _placeChanged,
        photos: List<dynamic>.from(_photos),
        memberIds: Set<String>.from(_selectedMemberIds),
      );

      if (mounted) {
        // === 수정한 내용: 기록 저장 성공 후 홈 캐시를 갱신하고 상위 화면에 변경 결과를 반환한다 ===
        refreshHomeFeed(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.initialMeetup == null
                  ? '🎉 기록과 사진이 저장되었어요!'
                  : '🎉 기록이 수정되었어요!',
            ),
            backgroundColor: AppConstants.textTitle,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('저장하지 못했습니다. 다시 시도해 주세요.')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildImagePreview(int index, dynamic item) {
    // 이미지 프리뷰 관련 기존 코드 유지
    final bool isRepresentative = index == 0;
    return GestureDetector(
      onTap: () {
        if (!isRepresentative) {
          setState(() {
            final movedItem = _photos.removeAt(index);
            _photos.insert(0, movedItem);
          });
        }
      },
      child: Container(
        width: 86,
        height: 86,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          border: isRepresentative
              ? Border.all(color: AppConstants.primaryColor, width: 2)
              : Border.all(color: AppConstants.borderColor),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isRepresentative ? 12 : 13),
                child: item is String
                    ? PrivatePhotoImage(
                        imageUrl: item,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                            color: AppConstants.primaryColor,
                            strokeWidth: 2,
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      )
                    : (kIsWeb
                          ? Image.network(
                              (item as XFile).path,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File((item as XFile).path),
                              fit: BoxFit.cover,
                            )),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => setState(() => _photos.removeAt(index)),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
            if (isRepresentative)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: const BoxDecoration(
                    color: AppConstants.primaryColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '대표',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.initialMeetup != null;

    return Scaffold(
      backgroundColor: AppConstants.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          isEditMode ? '기록 수정하기' : '기록 남기기',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: AppConstants.scaffoldBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppConstants.textTitle,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('무슨 만남이었나요?', isRequired: true),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _titleController,
              hint: '예) 모락이 생일파티 🎂',
              errorText: _titleError, // 🌟 에러 상태 연결
            ),
            const SizedBox(height: 28),

            const SectionTitle('만난 날짜', isRequired: true),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppConstants.cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppConstants.borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedDate.year}. ${_selectedDate.month.toString().padLeft(2, '0')}. ${_selectedDate.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppConstants.textTitle,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(
                      Icons.calendar_month_rounded,
                      color: AppConstants.textCaption,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            const SectionTitle('누가 참석했나요?', isRequired: true),
            const SizedBox(height: 12),
            _members.isEmpty
                ? const Text(
                    '등록된 멤버가 없어요.\n이전 화면에서 멤버를 먼저 추가해주세요!',
                    style: TextStyle(
                      color: AppConstants.textCaption,
                      fontSize: 13,
                    ),
                  )
                : Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _members.map((member) {
                      final memberId = member.id.toString();
                      final isSelected = _selectedMemberIds.contains(memberId);
                      return FilterChip(
                        label: Text(member.displayName),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppConstants.textBody,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          setState(() {
                            if (selected) {
                              _selectedMemberIds.add(memberId);
                            } else {
                              _selectedMemberIds.remove(memberId);
                            }
                          });
                        },
                        selectedColor: AppConstants.primaryColor,
                        checkmarkColor: Colors.white,
                        backgroundColor: AppConstants.cardBackground,
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? AppConstants.primaryColor
                                : AppConstants.borderColor,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 28),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SectionTitle('추억 사진', isOptional: true),
                const SizedBox(width: 8),
                const Text(
                  '사진을 터치하면 대표로 지정돼요!',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppConstants.textCaption,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  InkWell(
                    onTap: _pickImages,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 86,
                      height: 86,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: AppConstants.cardBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppConstants.borderColor),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add_a_photo_outlined,
                            color: AppConstants.textCaption,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_photos.length}장',
                            style: const TextStyle(
                              color: AppConstants.textBody,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ..._photos.asMap().entries.map(
                    (entry) => _buildImagePreview(entry.key, entry.value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            const SectionTitle('장소', isOptional: true),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _locationController,
              hint: '예) 연남동 타코집',
            ),
            const SizedBox(height: 12),
            Button(
              text: _place == null ? '장소 검색하고 지도에 표시하기' : '지도 장소 변경하기',
              type: ButtonType.outlined,
              icon: const Icon(Icons.map_outlined),
              onPressed: _isLoading ? null : _pickPlace,
            ),
            if (_place != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 200,
                  child: PlacesMap(
                    pins: [PlacePin(place: _place!, visits: [])],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _place!.address.isEmpty ? '지도에서 직접 선택한 장소' : _place!.address,
                style: const TextStyle(
                  color: AppConstants.textBody,
                  fontSize: 13,
                ),
              ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                        _place = null;
                        _placeChanged = true;
                      }),
                child: const Text('지도 위치만 지우기'),
              ),
            ],
            const SizedBox(height: 28),

            const SectionTitle('메뉴', isOptional: true),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _menuController,
              hint: '예) 오코노미야키, 생맥주 🍻',
            ),
            const SizedBox(height: 40),

            (_isLoading || _isInitializing)
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppConstants.primaryColor,
                    ),
                  )
                : Button(
                    text: isEditMode ? '수정 완료' : '기록 완료',
                    onPressed: _saveMeetup,
                  ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
