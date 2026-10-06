import 'package:supabase_flutter/supabase_flutter.dart';

// === 수정한 내용: 계정 정보에는 인증 계정의 필요한 항목만 전달하고 토큰과 원문 메타데이터를 제외한다 ===
class AccountInfo {
  final String loginMethod;
  final String? email;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;
  const AccountInfo({
    required this.loginMethod,
    this.email,
    this.createdAt,
    this.lastSignInAt,
  });

  factory AccountInfo.fromUser(User user) {
    final providers = (user.identities ?? [])
        .map((identity) => identity.provider)
        .toSet();
    if (providers.isEmpty) {
      final metadataProviders = user.appMetadata['providers'];
      if (metadataProviders is List) {
        providers.addAll(metadataProviders.whereType<String>());
      }
      if (providers.isEmpty && user.appMetadata['provider'] is String) {
        providers.add(user.appMetadata['provider'] as String);
      }
    }
    // provider 메타데이터는 최초 가입 방식일 수 있어 여러 연결 계정 중 현재 방식을 임의 선택하지 않습니다.
    final provider = providers.length == 1 ? providers.single : null;
    final method = switch (provider) {
      'google' => 'Google',
      'email' => '이메일',
      'apple' => 'Apple',
      null => '확인할 수 없음',
      _ => provider,
    };
    return AccountInfo(
      loginMethod: method,
      email: user.email,
      // === 수정한 내용: Google 실명을 계정 표시 모델로 읽거나 전달하지 않는다 ===
      createdAt: DateTime.tryParse(user.createdAt),
      lastSignInAt: DateTime.tryParse(user.lastSignInAt ?? ''),
    );
  }
}
