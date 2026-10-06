import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../models/account_info.dart';
import '../utils/storage_uploads.dart';

class UserRepository {
  // === 수정한 내용: 프로필 저장과 삭제를 실제 서버 없이 검증하도록 클라이언트 주입을 지원한다 ===
  UserRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  // === 수정한 내용: 계정 화면은 현재 인증 상태를 구독해 로그아웃·계정 변경 후 이전 정보를 지운다 ===
  Stream<AccountInfo?> watchAccountInfo() => Stream.multi((controller) {
    final subscription = _client.auth.onAuthStateChange.listen(
      (state) {
        final current = state.session?.user;
        controller.add(current == null ? null : AccountInfo.fromUser(current));
      },
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
    final user = _client.auth.currentUser;
    controller.add(user == null ? null : AccountInfo.fromUser(user));
  });

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
        .maybeSingle()
        .timeout(const Duration(seconds: 20));

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
    if (nickname.trim().isEmpty) throw ArgumentError('닉네임을 입력해 주세요.');

    String? finalImageUrl = existingImageUrl;
    final uploads = StorageUploads(_client);

    // 💡 새로운 사진이 들어왔다면 스토리지에 냅다 업로드 후 URL 뽑아오기
    if (newImageFile != null) {
      // === 수정한 내용: 기존 파일을 덮어쓰지 않아 프로필 저장 실패가 기존 사진을 변경하지 않는다 ===
      finalImageUrl = await uploads.upload(
        'profiles',
        newImageFile,
        prefix: 'avatars/${currentUser.id}_',
      );
    }

    final updateData = {
      'display_name': nickname,
      'birthday': birthday,
      // === 수정한 내용: 화면에서 사진을 삭제한 경우 null도 저장하여 이전 사진이 다시 나타나지 않게 한다 ===
      'profile_image_url': finalImageUrl,
    };

    if (_client.auth.currentUser?.id != currentUser.id) {
      throw StateError('로그인 계정이 변경되었습니다.');
    }
    if (isNewSetup) {
      // 신규 가입일 땐 insert! (id도 같이 넣어줍니다)
      updateData['id'] = currentUser.id;
      // === 수정한 내용: 동일 프로필 설정의 재시도는 중복 INSERT 대신 본인 행을 안전하게 갱신한다 ===
      await uploads.commit(() => _client.from('users').upsert(updateData));
    } else {
      // 기존 유저면 update!
      await uploads.commit(
        () => _client.from('users').update(updateData).eq('id', currentUser.id),
      );
    }
  }

  // 🌟 로그아웃 처리
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // 🌟 회원 탈퇴 처리 (여기에 새로 추가!)
  Future<void> deleteAccount() async {
    try {
      // 1. DB에 만들어둔 삭제 함수(RPC) 호출
      // 인증 서버 계정 삭제 -> CASCADE 제약조건으로 DB 데이터까지 자동 삭제
      // === 수정한 내용: 탈퇴 RPC의 무한 대기를 제한하고 확정되지 않은 실패를 화면에 알린다 ===
      await _client.rpc('delete_user').timeout(const Duration(seconds: 30));
    } catch (e) {
      // DB 삭제 실패 시 UI 쪽에 에러 던지기
      rethrow;
    }

    try {
      // 2. 기기에 남아있는 로그인 찌꺼기(토큰) 비우기
      await _client.auth.signOut();
    } catch (e) {
      // 이미 서버에서 유저가 날아간 상태라 에러가 날 수 있으므로 가볍게 무시
      // === 수정한 내용: 인증 오류의 원문을 로그에 노출하지 않고 로컬 세션 정리 실패만 알린다 ===
      debugPrint('회원탈퇴 후 로컬 로그아웃을 완료하지 못했습니다.');
    }
  }
}
