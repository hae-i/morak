import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:morak/services/photo_saver.dart';
import 'package:morak/screens/group/photo_viewer_screen.dart';

// === 수정한 내용: 실제 저장 계약과 권한 거절, 잘못된 다운로드 및 중복 탭을 검증한다 ===
void main() {
  final png = Uint8List.fromList([137,80,78,71,13,10,26,10]);
  PhotoSaver saver({http.Client? client, bool allowed = true, Future<void> Function(Uint8List, String)? write}) => PhotoSaver(
    client: client ?? MockClient((_) async => http.Response.bytes(png, 200)),
    hasAccess: () async => allowed, requestAccess: () async => allowed,
    write: write ?? (_, _) async {},
  );
  test('downloads without credentials and writes verified bytes once', () async {
    int writes = 0;
    await saver(client: MockClient((request) async {
      expect(request.headers.containsKey('authorization'), false);
      return http.Response.bytes(png, 200);
    }), write: (bytes, name) async { writes++; expect(bytes, png); expect(name, startsWith('morak_')); }).save('https://example.test/photo');
    expect(writes, 1);
  });
  test('permission denial does not download or write', () async {
    int requests = 0, writes = 0;
    await expectLater(saver(allowed: false, client: MockClient((_) async {
      requests++; return http.Response.bytes(png, 200);
    }), write: (_, _) async { writes++; }).save('https://example.test/photo'), throwsA(isA<PhotoSaveException>()));
    expect(requests, 0); expect(writes, 0);
  });
  for (final status in [403,404,500,302]) {
    test('non-success response $status does not write', () async {
      int writes = 0;
      await expectLater(saver(client: MockClient((_) async => http.Response('server detail', status)),
        write: (_, _) async { writes++; }).save('https://example.test/photo'), throwsA(isA<PhotoSaveException>()));
      expect(writes, 0);
    });
  }
  test('invalid bytes do not reach the gallery', () async {
    int writes = 0;
    await expectLater(saver(client: MockClient((_) async => http.Response('not an image', 200)),
      write: (_, _) async { writes++; }).save('https://example.test/photo'), throwsA(isA<PhotoSaveException>()));
    expect(writes, 0);
  });
  test('stream without content length is bounded before gallery write', () async {
    int writes = 0;
    await expectLater(saver(client: MockClient.streaming((_, _) async => http.StreamedResponse(
      Stream.value(Uint8List(10 * 1024 * 1024 + 1)), 200)),
      write: (_, _) async { writes++; }).save('https://example.test/photo'), throwsA(isA<PhotoSaveException>()));
    expect(writes, 0);
  });
  test('insecure and invalid addresses do not request permissions', () async {
    for (final url in ['http://example.test/photo', 'file:///private/photo', 'https://user:password@example.test/photo']) {
      await expectLater(saver().save(url), throwsA(isA<PhotoSaveException>()));
    }
  });
  testWidgets('success appears only after saving and duplicate taps are ignored', (tester) async {
    final pending = Completer<void>(); int writes = 0;
    await tester.pumpWidget(MaterialApp(home: PhotoViewerScreen(imageUrls: const ['https://example.test/photo'],
      initialIndex: 100, groupMembers: const [], activeColor: Colors.blue,
      photoSaver: saver(write: (_, _) { writes++; return pending.future; }))));
    await tester.tap(find.text('저장')); await tester.pump(); await tester.pump();
    expect(writes, 1); expect(find.text('갤러리에 사진을 저장했습니다.'), findsNothing);
    await tester.tap(find.text('저장 중')); await tester.pump(); expect(writes, 1);
    pending.complete(); await tester.pump(); await tester.pump();
    expect(find.text('갤러리에 사진을 저장했습니다.'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
  });
  testWidgets('late save completion after disposal does not use the old context', (tester) async {
    final pending = Completer<void>();
    await tester.pumpWidget(MaterialApp(home: PhotoViewerScreen(imageUrls: const ['https://example.test/photo'],
      initialIndex: 0, groupMembers: const [], activeColor: Colors.blue,
      photoSaver: saver(write: (_, _) => pending.future))));
    await tester.tap(find.text('저장')); await tester.pump(); await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(); await tester.pump(); expect(tester.takeException(), isNull);
  });
}
