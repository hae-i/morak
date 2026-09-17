import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/splash_screen.dart';
import 'screens/main_skeleton.dart';
import 'screens/auth/login_screen.dart';
import 'screens/profile/profile_setup_screen.dart';
import 'widgets/group/group_join_sheet.dart';
import 'screens/group/group_detail_screen.dart';

// 🌟 앱의 전체 길안내를 담당하는 GoRouter
final router = GoRouter(
  // 앱이 처음 켜지면 무조건 AuthGate로
  initialLocation: '/',

  // 🌟 Auth Guard: 라우팅될 때마다 로그인 상태를 확인
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggingIn = state.matchedLocation == '/login';

    // 로그인이 안 되어 있는데 다른 화면으로 가려고 하면? -> 로그인 화면으로 쫓아냄
    if (session == null && !isLoggingIn) return '/login';

    // 로그인이 되어 있는데 로그인 화면으로 가려고 하면? -> 홈으로 보냄
    if (session != null && isLoggingIn) return '/home';

    return null; // 문제없으면 원래 가려던 곳으로 패스!
  },

  routes: [
    // 🚪 대문 (자동 라우팅 대기소)
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    // 🔑 로그인 화면
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    // 🏠 홈 화면 (메인 뼈대)
    GoRoute(path: '/home', builder: (context, state) => const MainSkeleton()),
    // 👤 초기 프로필 설정 화면
    GoRoute(
      path: '/profile-setup',
      builder: (context, state) => const ProfileSetupScreen(),
    ),

    // 💌 초대 링크 딥링크 처리 (morak://invite?groupId=...&groupName=...)
    GoRoute(
      path: '/invite',
      builder: (context, state) {
        final groupId = state.uri.queryParameters['groupId'] ?? '';

        WidgetsBinding.instance.addPostFrameCallback((_) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => GroupJoinSheet(groupId: groupId),
          ).then((isJoined) {
            // 🌟 바텀시트가 닫힌 후 결과를 받아서 이동
            if (context.mounted) {
              if (isJoined == true) {
                // 🎉 가입 성공 모임 상세 화면으로 다이렉트 꽂아주기
                context.go('/group_detail?groupId=$groupId');
              } else {
                // ❌ 가입 안 하고 그냥 시트를 밑으로 내려서 닫은 경우 -> 홈으로
                context.go('/home');
              }
            }
          });
        });

        return const MainSkeleton();
      },
    ),

    GoRoute(
      path: '/group_detail',
      builder: (context, state) {
        final groupId = state.uri.queryParameters['groupId'] ?? '';

        return GroupDetailScreen(groupId: groupId);
      },
    ),
  ],
);
