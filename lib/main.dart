import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'constants/app_constants.dart';
import 'locator.dart';
import 'router.dart';
import 'repositories/user_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  setupLocator();
  runApp(const ProviderScope(child: MorakApp()));
}

class MorakApp extends ConsumerStatefulWidget {
  const MorakApp({super.key});
  @override
  ConsumerState<MorakApp> createState() => _MorakAppState();
}

class _MorakAppState extends ConsumerState<MorakApp> {
  @override
  void initState() {
    super.initState();
    // 🌟 앱 전체의 로그인 상태를 감지해서 자동으로 화면을 이동
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session == null) {
        router.go('/login');
      } else {
        // 로그인 성공 시 프로필 유무 확인 후 알아서 보내줌
        final userData = await locator<UserRepository>().fetchMyGlobalProfile();
        if (userData == null) {
          router.go('/profile-setup');
        } else {
          router.go('/home');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Morak',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppConstants.primaryColor),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
