import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InviteHelper {
  // 🌟 어디서든 InviteHelper.copyInviteLink(...) 로 가져다 쓸 수 있게 static으로 만듭니다!
  static Future<void> copyInviteLink({
    required BuildContext context,
    required String groupId,
  }) async {
    // 1. 링크 만들기
    final inviteLink = 'https://morak.app/invite?groupId=$groupId';

    // 2. 클립보드에 복사하기
    await Clipboard.setData(ClipboardData(text: inviteLink));

    // 3. 스낵바 띄우기 (화면이 아직 살아있을 때만)
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔗 초대 링크가 복사되었습니다!'),
          // backgroundColor: AppConstants.primaryColor, // 원하시면 색상 추가!
        ),
      );
    }
  }
}
