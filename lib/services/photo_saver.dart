import 'dart:async';
import 'dart:typed_data' show BytesBuilder;

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../utils/storage_uploads.dart';
import '../utils/operation_id.dart';
import 'private_photos.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class PhotoSaveException implements Exception {
  final String message;
  const PhotoSaveException(this.message);
}

// === 수정한 내용: 갤러리 권한과 실제 저장 완료를 확인하고 제한된 크기로 사진을 다운로드한다 ===
class PhotoSaver {
  final http.Client? client;
  final Future<bool> Function() hasAccess;
  final Future<bool> Function() requestAccess;
  final Future<void> Function(Uint8List bytes, String name) write;
  PhotoSaver({
    this.client,
    Future<bool> Function()? hasAccess,
    Future<bool> Function()? requestAccess,
    Future<void> Function(Uint8List bytes, String name)? write,
  }) : hasAccess = hasAccess ?? (() => Gal.hasAccess()),
       requestAccess = requestAccess ?? (() => Gal.requestAccess()),
       write = write ?? ((bytes, name) => Gal.putImageBytes(bytes, name: name));

  Future<void> save(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const PhotoSaveException('사진 주소를 확인해 주세요.');
    }
    if (kIsWeb) throw const PhotoSaveException('기기 앱에서 사진 저장을 이용해 주세요.');
    try {
      if (!await hasAccess() && !await requestAccess()) {
        throw const PhotoSaveException('사진 저장 권한이 필요합니다. 기기 설정에서 허용해 주세요.');
      }
      final transport = client ?? http.Client();
      try {
        // === 수정한 내용: 모임 사진 저장도 공개 주소 대신 현재 세션과 Storage 정책을 사용한다 ===
        StoragePhotoRef? ref;
        SupabaseClient? storageClient;
        try {
          storageClient = Supabase.instance.client;
          ref = StoragePhotoRef.parse(
            url,
            storageClient.storage.from('profiles').url,
          );
        } on AssertionError {
          // 독립 다운로드 테스트에서는 Supabase가 초기화되지 않을 수 있습니다.
        }
        final image = ref == null
            ? await _download(
                transport,
                uri,
              ).timeout(const Duration(seconds: 30))
            : await readImagePayload(
                XFile.fromData(
                  await PrivatePhotos.download(storageClient!, ref),
                ),
              ).timeout(const Duration(seconds: 30));
        // 기기 저장은 완료 여부가 불명확한 timeout으로 중복 저장을 유도하지 않습니다.
        await write(image.bytes, 'morak_${newOperationId()}');
      } finally {
        if (client == null) transport.close();
      }
    } on PhotoSaveException {
      rethrow;
    } on GalException catch (error) {
      throw PhotoSaveException(switch (error.type) {
        GalExceptionType.accessDenied => '사진 저장 권한이 필요합니다. 기기 설정에서 허용해 주세요.',
        GalExceptionType.notEnoughSpace => '기기의 저장 공간이 부족합니다.',
        GalExceptionType.notSupportedFormat => '기기에서 저장할 수 없는 사진 형식입니다.',
        GalExceptionType.unexpected => '사진을 저장하지 못했습니다. 다시 시도해 주세요.',
      });
    } on TimeoutException {
      throw const PhotoSaveException('사진 다운로드 시간이 초과되었습니다. 다시 시도해 주세요.');
    } catch (_) {
      throw const PhotoSaveException('사진을 저장하지 못했습니다. 연결 상태를 확인해 주세요.');
    }
  }

  Future<ImagePayload> _download(http.Client transport, Uri uri) async {
    const limit = 10 * 1024 * 1024;
    final request = http.Request('GET', uri)..followRedirects = false;
    final response = await transport.send(request);
    if (response.statusCode != 200)
      throw const PhotoSaveException('사진을 다운로드하지 못했습니다. 다시 시도해 주세요.');
    if ((response.contentLength ?? 0) > limit)
      throw const PhotoSaveException('10MB 이하의 사진만 저장할 수 있습니다.');
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > limit)
        throw const PhotoSaveException('10MB 이하의 사진만 저장할 수 있습니다.');
      bytes.add(chunk);
    }
    try {
      return await readImagePayload(XFile.fromData(bytes.takeBytes()));
    } on ArgumentError {
      throw const PhotoSaveException('지원하지 않는 사진 파일입니다.');
    }
  }
}
