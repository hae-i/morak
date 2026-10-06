import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'constants/app_constants.dart';
import 'locator.dart';
import 'router.dart';
import 'repositories/user_repository.dart';
import 'providers/home_provider.dart';
import 'services/image_selection_recovery.dart';
import 'services/private_photos.dart';

import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  setupLocator();
  // === 수정한 내용: Android에서 중단된 사진 선택을 시작 시 보관하여 같은 작업에서 복구할 수 있게 한다 ===
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await ImageSelectionRecovery.instance.initialize();
    } catch (_) {
      debugPrint('중단된 사진 선택을 복구하지 못했습니다.');
    }
  }
  runApp(const ProviderScope(child: MorakApp()));
}

class MorakApp extends ConsumerStatefulWidget {
  const MorakApp({super.key});
  @override
  ConsumerState<MorakApp> createState() => _MorakAppState();
}

class _MorakAppState extends ConsumerState<MorakApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  // === 수정한 내용: 로그인/로그아웃 완료 안내를 이동 후 화면에 한 번 표시하며 토큰 갱신에는 표시하지 않는다 ===
  void _notifyAuth(String message, String? user, int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _authGeneration ||
          Supabase.instance.client.auth.currentUser?.id != user) {
        return;
      }
      _messenger.currentState?.clearSnackBars();
      _messenger.currentState?.showSnackBar(SnackBar(content: Text(message)));
    });
  }

  String? _feedUserId;
  // === 수정한 내용: 인증 요청 세대와 구독을 관리하여 이전 계정의 응답과 구독 누수를 차단한다 ===
  StreamSubscription<AuthState>? _authSubscription;
  int _authGeneration = 0;
  @override
  void initState() {
    super.initState();
    _feedUserId = Supabase.instance.client.auth.currentUser?.id;
    // 🌟 앱 전체의 로그인 상태를 감지해서 자동으로 화면을 이동
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) => unawaited(_handleAuthState(data)),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('인증 상태 변경을 처리하지 못했습니다.');
      },
    );
  }

  Future<void> _handleAuthState(AuthState data) async {
    if (!mounted) return;
    final userId = data.session?.user.id;
    final userChanged = _feedUserId != userId;
    if (userChanged) {
      // === 수정한 내용: 이전 계정의 메모리 사진과 늦은 다운로드 응답을 무효화한다 ===
      PrivatePhotos.invalidate(clearMemoryCache: true);
      _feedUserId = userId;
      _authGeneration++;
      if (ref.exists(feedProvider)) {
        ref.read(feedProvider.notifier).resetForSession();
      }
    }

    // Queued events may belong to a session that has already ended.
    if (Supabase.instance.client.auth.currentUser?.id != userId) return;
    if (userId == null) {
      if (data.event == AuthChangeEvent.signedOut) clearPendingInvite();
      router.go('/login');
      if (userChanged && data.event == AuthChangeEvent.signedOut) {
        _notifyAuth('로그아웃되었습니다.', null, _authGeneration);
      }
      return;
    }
    // === 수정한 내용: 동일 사용자 토큰 갱신은 편집 화면과 진행 중인 로그인 조회를 유지한다 ===
    if (data.event == AuthChangeEvent.initialSession ||
        (!userChanged && data.event != AuthChangeEvent.signedIn)) {
      return;
    }

    final generation = ++_authGeneration;
    try {
      final userData = await locator<UserRepository>().fetchMyGlobalProfile();
      if (!mounted ||
          generation != _authGeneration ||
          Supabase.instance.client.auth.currentUser?.id != userId) {
        return;
      }
      router.go(destinationAfterProfile(hasProfile: userData != null));
      if (data.event == AuthChangeEvent.signedIn) {
        _notifyAuth('로그인되었습니다.', userId, generation);
      }
    } catch (_) {
      if (mounted && generation == _authGeneration) {
        debugPrint('로그인 후 프로필을 확인하지 못했습니다.');
        // === 수정한 내용: 로그인 프로필 조회 실패 시 Splash 재시도로 이동하여 로그인 화면에서 멈추지 않게 한다 ===
        router.go('/');
      }
    }
  }

  @override
  void dispose() {
    // === 수정한 내용: 앱 폐기 시 인증 구독과 대기 중인 화면 이동을 함께 무효화한다 ===
    _authGeneration++;
    final subscription = _authSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '모락',
      scaffoldMessengerKey: _messenger,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR')],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppConstants.primaryColor),
        useMaterial3: true,
        // === 수정한 내용: 모든 Material 메뉴와 버튼의 물결 효과를 전역으로 제거한다 ===
        splashFactory: NoSplash.splashFactory,
      ),
      routerConfig: router,
    );
  }
}
