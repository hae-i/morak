import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/meetup/meetup_story.dart';

import '../../constants/app_constants.dart';
import '../../models/meetup_model.dart';
import '../../models/member_model.dart';
import 'photo_viewer_screen.dart';
import 'meetup_create_screen.dart'; // 🌟 수정 화면 이동을 위한 임포트 추가
import '../../locator.dart';
import '../../repositories/meetup_repository.dart';
import '../../utils/ui_utils.dart';
import '../../utils/data_refresh.dart';

class MeetupDetailScreen extends StatefulWidget {
  final MeetupModel meetup;
  final List<MemberModel> groupMembers;
  final Color activeColor;

  const MeetupDetailScreen({
    super.key,
    required this.meetup,
    required this.groupMembers,
    required this.activeColor,
  });

  @override
  State<MeetupDetailScreen> createState() => _MeetupDetailScreenState();
}

class _MeetupDetailScreenState extends State<MeetupDetailScreen> {
  late MeetupModel _meetup;
  bool _changed = false;
  bool _isDeleting = false;
  MeetupModel get meetup => _meetup;
  List<MemberModel> get groupMembers => widget.groupMembers;
  Color get activeColor => widget.activeColor;
  MemberModel? get _me {
    final user = Supabase.instance.client.auth.currentUser?.id;
    return groupMembers
        .where((m) => user != null && m.userId == user && m.isActive)
        .firstOrNull;
  }

  bool get _canEdit => meetup.canEdit(_me);
  bool get _canDelete => meetup.canDelete(_me);

  @override
  void initState() {
    super.initState();
    _meetup = widget.meetup;
  }

  // === 수정한 내용: 편집 성공 후 최신 기록을 다시 읽어 상세 화면의 이전 데이터 표시를 방지한다 ===
  Future<void> _editMeetup() async {
    if (!mounted || _isDeleting || !_canEdit) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MeetupCreateScreen(groupId: meetup.groupId, initialMeetup: meetup),
      ),
    );
    if (!mounted || changed != true) return;
    _changed = true;
    try {
      final latest = await locator<MeetupRepository>().fetchMeetup(meetup.id);
      if (mounted) setState(() => _meetup = latest);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장된 기록을 다시 불러오지 못했습니다. 다시 열어 주세요.')),
        );
      }
    }
  }

  // === 수정한 내용: 삭제 버튼을 확인 창과 실제 DB 삭제에 연결하고 성공 결과를 상위 화면에 반환한다 ===
  Future<void> _deleteMeetup() async {
    if (!mounted || _isDeleting || !_canDelete) return;
    final confirmed = await UiUtils.showBeautifulDialog(
      context: context,
      title: '기록 삭제',
      content: '이 만남 기록을 삭제할까요?',
      confirmText: '삭제하기',
      confirmColor: AppConstants.dangerColor,
      icon: Icons.delete_outline_rounded,
    );
    if (!mounted || confirmed != true) return;
    _isDeleting = true;
    try {
      await locator<MeetupRepository>().deleteMeetup(meetup.id);
      if (!mounted) return;
      refreshHomeFeed(context);
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기록을 삭제하지 못했습니다. 다시 시도해 주세요.')),
        );
      }
    } finally {
      _isDeleting = false;
    }
  }

  String _formatDate(String date) {
    try {
      final dt = DateTime.parse(date);
      return '${dt.year}년 ${dt.month}월 ${dt.day}일';
    } catch (_) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    // === 수정한 내용: 저장한 제목을 우선 표시하고 이전 제목 없는 기록만 장소와 메뉴로 대체한다 ===
    final title = meetup.title?.trim().isNotEmpty == true
        ? meetup.title!
        : [
            meetup.location ?? '',
            meetup.menu ?? '',
          ].where((s) => s.isNotEmpty).join(' · ');
    return Scaffold(
      backgroundColor: AppConstants.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          '만남 기록',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
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
          onPressed: () => Navigator.pop(context, _changed),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🌟 날짜와 제목이 있는 영역을 Row로 감싸고 우측 끝에 버튼 배치!
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(meetup.date),
                          style: const TextStyle(
                            color: AppConstants.textBody,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        // === 수정한 내용: 현재 작성자·탈퇴 작성자를 표시하고 권한이 있는 작업만 제공한다 ===
                        Text(
                          '작성자: ${meetup.authorLabel}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppConstants.textCaption,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title.isNotEmpty ? title : '기록 내용 없음',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppConstants.textTitle,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 🌟 여기에 더보기 아이콘이 쏙 들어갑니다
                  if (_canEdit || _canDelete)
                    IconButton(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: AppConstants.textCaption,
                        size: 26,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: AppConstants.cardBackground,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                          builder: (context) => SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_canEdit)
                                    ListTile(
                                      leading: const Icon(
                                        Icons.edit_rounded,
                                        color: AppConstants.textTitle,
                                      ),
                                      title: const Text(
                                        '기록 수정하기',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppConstants.textTitle,
                                        ),
                                      ),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _editMeetup();
                                      },
                                    ),
                                  if (_canDelete)
                                    ListTile(
                                      leading: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppConstants.dangerColor,
                                      ),
                                      title: const Text(
                                        '기록 삭제하기',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppConstants.dangerColor,
                                        ),
                                      ),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _deleteMeetup();
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            MeetupStory(
              meetup: meetup,
              members: groupMembers,
              onOpenPhotos: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PhotoViewerScreen(
                    imageUrls: meetup.photos,
                    initialIndex: 0,
                    groupMembers: groupMembers,
                    activeColor: activeColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
