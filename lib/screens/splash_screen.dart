import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../locator.dart';
import '../repositories/user_repository.dart';
import '../router.dart';
import '../widgets/common/request_error_view.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _loadFailed = false;
  @override
  void initState() {
    super.initState();
    _checkAuthAndRoute();
  }

  Future<void> _checkAuthAndRoute() async {
    if (!mounted) return;
    setState(() => _loadFailed = false);
    // === 수정한 내용: 시작 시 프로필 조회는 동일 계정의 살아 있는 화면에서만 적용한다 ===
    final session = Supabase.instance.client.auth.currentSession;
    bool isCurrentSession() =>
        mounted &&
        Supabase.instance.client.auth.currentUser?.id == session?.user.id;
    try {
      if (session == null) {
        if (mounted) context.go('/login');
        return;
      }

      // 🌟 레포지토리에서 안전하게 프로필 확인
      final profile = await locator<UserRepository>().fetchMyGlobalProfile();
      if (mounted && isCurrentSession()) {
        context.go(destinationAfterProfile(hasProfile: profile != null));
      }
    } catch (e) {
      if (!isCurrentSession()) return;
      // === 수정한 내용: 조회 실패를 프로필 없음으로 오인하지 않고 재시도를 제공한다 ===
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadFailed) {
      return Scaffold(
        body: RequestErrorView(
          message: '로그인 정보를 확인하지 못했습니다.',
          onRetry: _checkAuthAndRoute,
        ),
      );
    }
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(color: AppConstants.primaryColor),
      ),
    );
  }
}
