import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';

import '../../utils/ui_utils.dart';
import '../../widgets/common/common_widgets.dart';
import '../../repositories/group_repository.dart';
import '../../repositories/meetup_repository.dart';
import '../../models/meetup_model.dart';
import '../../models/member_model.dart';

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

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  List<MemberModel> _members = [];
  final Set<String> _selectedMemberIds = {};

  final ImagePicker _picker = ImagePicker();
  List<dynamic> _photos = [];
  final _groupRepo = GroupRepository();
  final _meetupRepo = MeetupRepository();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _menuController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      _members = await _groupRepo.fetchGroupMembers(widget.groupId);
      if (mounted) setState(() {});

      if (widget.initialMeetup != null) {
        _titleController.text = widget.initialMeetup!.title ?? '';
        _locationController.text = widget.initialMeetup!.location ?? '';
        _menuController.text = widget.initialMeetup!.menu ?? '';
        if (widget.initialMeetup!.date.isNotEmpty)
          _selectedDate = DateTime.parse(widget.initialMeetup!.date);
        _photos = List<dynamic>.from(widget.initialMeetup!.photos);
        _selectedMemberIds.addAll(widget.initialMeetup!.attendanceMemberIds);
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('데이터 로드 실패: $e');
    }
  }

  void _pickDate() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '날짜 선택',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          '완료',
                          style: TextStyle(
                            color: Color(0xFFFF8A80),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: _selectedDate,
                    minimumDate: DateTime(2020),
                    maximumDate: DateTime.now().add(const Duration(days: 365)),
                    onDateTimeChanged: (DateTime newDate) {
                      setState(() => _selectedDate = newDate);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 80,
      );
      if (pickedFiles.isNotEmpty) setState(() => _photos.addAll(pickedFiles));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('사진을 불러오지 못했습니다: $e')));
    }
  }

  Future<void> _saveMeetup() async {
    final title = _titleController.text.trim();
    final location = _locationController.text.trim();
    final menu = _menuController.text.trim();

    if (title.isEmpty && location.isEmpty && menu.isEmpty && _photos.isEmpty) {
      // 💡 UiUtils 한 줄 컷!
      UiUtils.showWarningDialog(
        context: context,
        title: '빈 기록이에요!',
        message: '제목, 장소, 사진 중\n최소 하나는 기록을 남겨주세요. ☁️',
      );
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
        photos: _photos,
        memberIds: _selectedMemberIds,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.initialMeetup == null
                  ? '🎉 기록과 사진이 저장되었어요!'
                  : '🎉 기록이 수정되었어요!',
            ),
            backgroundColor: const Color(0xFFFF8A80),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildImagePreview(int index, dynamic item) {
    final bool isRepresentative = index == 0;
    return GestureDetector(
      onTap: () {
        if (!isRepresentative) {
          setState(() {
            final movedItem = _photos.removeAt(index);
            _photos.insert(0, movedItem);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '대표 사진이 변경되었습니다! 📸',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Color(0xFFFF8A80),
              duration: Duration(seconds: 1),
            ),
          );
        }
      },
      child: Container(
        width: 100,
        height: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          border: isRepresentative
              ? Border.all(color: const Color(0xFFFF8A80), width: 3)
              : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: item is String
                    ? Image.network(item, fit: BoxFit.cover)
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
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
            if (isRepresentative)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF8A80),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(13),
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          isEditMode ? '기록 수정하기 ✏️' : '기록 남기기 ✏️',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey[50],
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 💡 SectionTitle과 CustomTextField 레고 블록 도입!
            const SectionTitle('무슨 만남이었나요?'), const SizedBox(height: 12),
            CustomTextField(
              controller: _titleController,
              hint: '예) 모락이 생일파티 🎂',
            ),
            const SizedBox(height: 24),

            const SectionTitle('만난 날짜'), const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedDate.year}. ${_selectedDate.month.toString().padLeft(2, '0')}. ${_selectedDate.day.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(Icons.calendar_month_rounded, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const SectionTitle('누가 참석했나요?'), const SizedBox(height: 12),
            _members.isEmpty
                ? Text(
                    '등록된 멤버가 없어요.\n이전 화면에서 멤버를 먼저 추가해주세요!',
                    style: TextStyle(color: Colors.grey[500]),
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
                          color: isSelected ? Colors.white : Colors.grey[700],
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
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
                        selectedColor: const Color(0xFFFF8A80),
                        checkmarkColor: Colors.white,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? Colors.transparent
                                : Colors.grey[300]!,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 24),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SectionTitle('추억 사진 (선택)'),
                const SizedBox(width: 8),
                Text(
                  '사진을 터치하면 대표로 지정돼요!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.bold,
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
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 100,
                      height: 100,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_rounded,
                            color: Colors.grey[400],
                            size: 28,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_photos.length}장',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
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
            const SizedBox(height: 24),

            const SectionTitle('장소'), const SizedBox(height: 12),
            CustomTextField(
              controller: _locationController,
              hint: '예) 구로몬 시장, 도톤보리',
            ),
            const SizedBox(height: 24),

            const SectionTitle('메뉴'), const SizedBox(height: 12),
            CustomTextField(
              controller: _menuController,
              hint: '예) 오코노미야키, 생맥주 🍻',
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveMeetup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8A80),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        isEditMode ? '수정 완료' : '기록 완료',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
