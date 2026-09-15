import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/main_skeleton.dart';
import 'screens/auth/login_screen.dart';
import 'screens/group/my_group_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://kzatuowxrixutuclglfj.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6YXR1b3d4cml4dXR1Y2xnbGZqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUxNDYxMDAsImV4cCI6MjEwMDcyMjEwMH0.IaEPcu2f73l2HUhiy9h6e3acelrL5CpR3T9a7OQj7-E',
  );

  runApp(const MorakApp());
}

class MorakApp extends StatelessWidget {
  const MorakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Morak',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF8A80)),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      // 수파베이스의 로그인 상태가 변할 때마다 감지
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFF8A80))));
        }

        final session = snapshot.data?.session;

        // 세션이 있으면(로그인 상태) 내 모임 화면으로, 없으면 로그인 화면으로!
        if (session != null) {
          return const MyGroupScreen();
        }
        return const LoginScreen();
      },
    );
  }
}


