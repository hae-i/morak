// === 수정한 내용: 저장된 모임·프로필 사진을 로그인 권한으로 조회한다 ===
import '../../services/private_photos.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_constants.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/group_repository.dart';
import '../common/common_widgets.dart';
import '../common/common_button.dart';
import '../../utils/data_refresh.dart';
import '../../locator.dart';
import '../common/request_error_view.dart';

class GroupJoinSheet extends StatefulWidget {
  final String groupId;

  const GroupJoinSheet({super.key, required this.groupId});

  @override
  State<GroupJoinSheet> createState() => _GroupJoinSheetState();
}

class _GroupJoinSheetState extends State<GroupJoinSheet> {
  final TextEditingController _nicknameController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _loadFailed = false;
  bool _ready = false;
  String? _loadedUserId;
  String? _globalProfileImageUrl;
  bool _isBirthdayPublic = true;

  String _fetchedGroupName = '모임';

  final _userRepo = locator<UserRepository>();
  final _groupRepo = locator<GroupRepository>();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  // === 수정한 내용: 조회 실패와 계정 변경을 처리하고 준비되지 않은 정보로 가입하지 않는다 ===
  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadFailed = false;
      _ready = false;
    });
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null || widget.groupId.trim().isEmpty) {
        throw StateError('가입 정보를 확인해 주세요.');
      }
      final member = await _groupRepo.fetchMyMembership(widget.groupId);
      if (!mounted || Supabase.instance.client.auth.currentUser?.id != userId) {
        return;
      }
      if (member != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('이미 참여 중인 모임입니다.')));
        Navigator.pop(context, true);
        return;
      }
      final profile = await _userRepo.fetchMyGlobalProfile();
      final groupName = await _groupRepo.fetchGroupName(widget.groupId);
      if (profile == null) throw StateError('프로필을 확인해 주세요.');
      if (!mounted || Supabase.instance.client.auth.currentUser?.id != userId) {
        return;
      }
      setState(() {
        _fetchedGroupName = groupName;
        _nicknameController.text = profile.displayName;
        _globalProfileImageUrl = profile.profileImageUrl;
        _isLoading = false;
        _ready = true;
        _loadedUserId = userId;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      }
    }
  }

  Future<void> _joinGroup() async {
    if (_isSaving || _isLoading || !_ready) return;
    // === 수정한 내용: 이전 계정의 프로필로 새 계정이 가입하거나 지연 응답이 화면을 이동하지 않게 한다 ===
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId != _loadedUserId) {
      await _loadInitialData();
      return;
    }
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await _groupRepo.joinGroup(
        groupId: widget.groupId,
        nickname: nickname,
        profileImageUrl: _globalProfileImageUrl,
        // === 수정한 내용: 사용자의 생일 비공개 선택을 가입 요청에 전달한다 ===
        isBirthdayPublic: _isBirthdayPublic,
      );
      if (mounted && Supabase.instance.client.auth.currentUser?.id == userId) {
        refreshHomeFeed(context);
        // === 수정한 내용: 신규 가입도 성공 결과를 반환하여 초대 화면이 상세로 이동하게 한다 ===
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 $_fetchedGroupName 모임에 가입되었습니다!'),
            backgroundColor: AppConstants.textTitle,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 가입된 모임이거나 에러가 발생했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: bottomInset > 0 ? bottomInset + 24 : 40,
      ),
      child: _loadFailed
          ? RequestErrorView(
              message: '초대 정보를 확인하지 못했습니다.',
              onRetry: _loadInitialData,
            )
          : _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(
                  color: AppConstants.primaryColor, // 🌟 블랙 스피너를 프라이머리 컬러로
                  strokeWidth: 2,
                ),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppConstants.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '💌 $_fetchedGroupName',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppConstants.textCaption,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '모임 프로필 설정',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textTitle,
                  ),
                ),
                const SizedBox(height: 32),
                CircleAvatar(
                  radius: 46,
                  backgroundColor: AppConstants.dividerColor,
                  backgroundImage: _globalProfileImageUrl != null
                      ? privatePhoto(_globalProfileImageUrl!)
                      : null,
                  child: _globalProfileImageUrl == null
                      ? const Icon(
                          Icons.person_rounded,
                          size: 48,
                          color: AppConstants.textCaption,
                        )
                      : null,
                ),
                const SizedBox(height: 28),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '이 모임에서 사용할 닉네임',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textTitle,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _nicknameController,
                  hint: '예: 모락이',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _isBirthdayPublic,
                        onChanged: (val) =>
                            setState(() => _isBirthdayPublic = val ?? true),
                        activeColor: AppConstants.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '이 모임에 내 생일 공개하기',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppConstants.textTitle,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                _isSaving
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppConstants.primaryColor,
                        ),
                      )
                    : Button(text: '이 프로필로 참여하기', onPressed: _joinGroup),
              ],
            ),
    );
  }
}
