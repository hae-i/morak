import 'package:url_launcher/url_launcher.dart';

// === 수정한 내용: 개인정보처리방침과 고객센터 메일 실행을 테스트 가능하게 하고 실패를 호출자에 전달한다 ===
class ExternalLinks {
  static const supportEmail = 'morak@morak.app';
  final Future<bool> Function(Uri) launch;
  ExternalLinks({Future<bool> Function(Uri)? launch})
    : launch =
          launch ??
          ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));
  Future<void> openSupportEmail() => _open(
    Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: 'subject=${Uri.encodeComponent('모락 문의 / 피드백')}',
    ),
  );
  Future<void> openPrivacyPolicy() =>
      _open(Uri.parse('https://morak.app/privacy'));
  Future<void> _open(Uri uri) async {
    if (!await launch(uri)) {
      throw StateError('External application unavailable');
    }
  }
}
