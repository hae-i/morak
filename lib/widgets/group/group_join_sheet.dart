import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/group_repository.dart';
import '../common/common_widgets.dart';

class GroupJoinSheet extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupJoinSheet({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupJoinSheet> createState() => _GroupJoinSheetState();
}

class _GroupJoinSheetState extends State<GroupJoinSheet> {
  final TextEditingController _nicknameController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _globalProfileImageUrl;
  bool _isBirthdayPublic = true;

  final _userRepo = UserRepository();
  final _groupRepo = GroupRepository();

  @override
  void initState() {
    super.initState();
    _loadGlobalProfile();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadGlobalProfile() async {
    try {
      final profile = await _userRepo.fetchMyGlobalProfile();
      if (profile != null && mounted) {
        setState(() {
          _nicknameController.text = profile.displayName;
          _globalProfileImageUrl = profile.profileImageUrl;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinGroup() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await _groupRepo.joinGroup(
        groupId: widget.groupId,
        nickname: nickname,
        profileImageUrl: _globalProfileImageUrl,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 ${widget.groupName} 모임에 가입되었습니다!'),
            backgroundColor: AppConstants.primaryColor,
          ),
        );
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
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: bottomInset > 0 ? bottomInset + 24 : 40,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(
                  color: AppConstants.primaryColor,
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
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '💌 ${widget.groupName}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '모임 프로필 설정',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),

                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.grey[100],
                  backgroundImage: _globalProfileImageUrl != null
                      ? NetworkImage(_globalProfileImageUrl!)
                      : null,
                  child: _globalProfileImageUrl == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 48,
                          color: Colors.grey[300],
                        )
                      : null,
                ),
                const SizedBox(height: 24),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '이 모임에서 사용할 닉네임',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),

                CustomTextField(
                  controller: _nicknameController,
                  hint: '예: 모락대장',
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
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '이 모임에 내 생일 공개하기 🎂',
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _joinGroup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            '이 프로필로 참여하기',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
