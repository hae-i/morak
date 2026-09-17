import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_model.dart';

class UserRepository {
  final _client = Supabase.instance.client;

  // 🌟 내 진짜 계정(글로벌 유저) 정보 가져오기
  // 용도: 마이페이지, 프로필 수정 화면 진입 시 내 정보 띄워줄 때 사용
  Future<UserModel?> fetchMyGlobalProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    // 🌟 .single() 대신 .maybeSingle()
    // 데이터가 없으면 에러(PGRST116)를 내지 않고 null을 반환
    final data = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return null;
    return UserModel.fromJson(data);
  }

  // 🌟 내 글로벌 프로필(닉네임, 프사, 생일) 업데이트 & 최초 가입 시에도 사용
  // 용도: ProfileEditScreen, ProfileSetupScreen 에서 저장 버튼 누를 때
  Future<void> updateMyGlobalProfile({
    required String nickname,
    required String? birthday,
    String? existingImageUrl,
    XFile? newImageFile,
    bool isNewSetup = false, // 💡 가입(insert)인지 수정(update)인지 구분
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) throw '로그인 정보가 없습니다.';

    String? finalImageUrl = existingImageUrl;

    // 💡 새로운 사진이 들어왔다면 스토리지에 냅다 업로드 후 URL 뽑아오기
    if (newImageFile != null) {
      final ext = newImageFile.name.split('.').last.toLowerCase();
      final fileName = '${currentUser.id}.$ext';
      final filePath = 'avatars/$fileName';

      await _client.storage
          .from('profiles')
          .uploadBinary(
            filePath,
            await newImageFile.readAsBytes(),
            fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
          );
      finalImageUrl = _client.storage.from('profiles').getPublicUrl(filePath);
    }

    final updateData = {
      'display_name': nickname,
      'birthday': birthday,
      if (finalImageUrl != null) 'profile_image_url': finalImageUrl,
    };

    if (isNewSetup) {
      // 신규 가입일 땐 insert! (id도 같이 넣어줍니다)
      updateData['id'] = currentUser.id;
      await _client.from('users').insert(updateData);
    } else {
      // 기존 유저면 update!
      await _client.from('users').update(updateData).eq('id', currentUser.id);
    }
  }

  // 🌟 로그아웃 처리
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
