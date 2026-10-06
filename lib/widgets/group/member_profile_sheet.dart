// === 수정한 내용: 저장된 모임·프로필 사진을 로그인 권한으로 조회한다 ===
import '../../services/private_photos.dart';

import 'package:flutter/material.dart';

import '../../models/member_model.dart';

// === 수정한 내용: 멤버 프로필 표시를 인증 조회·화면 이동과 분리하고 기존 시트 UI를 유지한다 ===
class MemberProfileSheet extends StatelessWidget {
  final MemberModel member;
  final bool isMe;
  final VoidCallback onEdit;
  const MemberProfileSheet({
    super.key,
    required this.member,
    required this.isMe,
    required this.onEdit,
  });
  @override
  Widget build(BuildContext context) {
    final isHost = member.role == 'host';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            if (isMe)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(Icons.settings_rounded, color: Colors.grey[500]),
                  onPressed: onEdit,
                  tooltip: '프로필 수정',
                ),
              )
            else
              const SizedBox(height: 24),
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.grey[100],
                  backgroundImage: member.profileImageUrl != null
                      ? privatePhoto(member.profileImageUrl!)
                      : null,
                  child: member.profileImageUrl == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 36,
                          color: Colors.grey[400],
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isHost)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Text('👑', style: TextStyle(fontSize: 16)),
                            ),
                          Flexible(
                            child: Text(
                              member.displayName + (isMe ? ' (나)' : ''),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // === 수정한 내용: 프로필에서도 부방장 역할을 구분한다 ===
                      Text(
                        (member.isBirthdayPublic && member.birthday != null)
                            ? '🎂 생일: ${member.birthday!.replaceAll('-', '. ')}'
                            : (isHost
                                  ? '모임 방장'
                                  : (member.role == 'deputy'
                                        ? '모임 부방장'
                                        : '일반 멤버')),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // 기존 통계 박스의 배치와 스타일을 유지합니다.
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text(
                        '참여한 만남',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${member.attendedCount}회',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 24, color: Colors.grey[200]),
                  Column(
                    children: [
                      const Text(
                        '참석률',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${member.attendanceRate.toInt()}%',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
