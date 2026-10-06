import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// === 수정한 내용: 계정 ID 변경만 구독하여 토큰 갱신은 유지하고 개인 화면의 이전 계정 데이터를 비운다 ===
final authUserIdProvider = StreamProvider<String?>(
  (ref) => Supabase.instance.client.auth.onAuthStateChange
      .map((event) => event.session?.user.id)
      .distinct(),
);
