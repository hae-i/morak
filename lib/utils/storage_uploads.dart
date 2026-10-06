import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'operation_id.dart';

class ImagePayload {
  final Uint8List bytes;
  final String extension, contentType;
  const ImagePayload(this.bytes, this.extension, this.contentType);
}

// === 수정한 내용: 사진의 실제 헤더와 크기를 확인하고 JPEG 등의 MIME을 올바르게 설정한다 ===
Future<ImagePayload> readImagePayload(XFile file) async {
  const maximumBytes = 10 * 1024 * 1024;
  if (await file.length() > maximumBytes) {
    throw ArgumentError('사진 크기는 10MB 이하여야 합니다.');
  }
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty || bytes.length > maximumBytes) {
    throw ArgumentError('사진 파일을 확인해 주세요.');
  }
  bool prefix(List<int> signature, [int offset = 0]) =>
      bytes.length >= signature.length + offset &&
      List.generate(
        signature.length,
        (i) => bytes[offset + i] == signature[i],
      ).every((v) => v);
  if (prefix([0xff, 0xd8, 0xff])) {
    return ImagePayload(bytes, 'jpg', 'image/jpeg');
  }
  if (prefix([137, 80, 78, 71, 13, 10, 26, 10])) {
    return ImagePayload(bytes, 'png', 'image/png');
  }
  if (prefix('RIFF'.codeUnits) && prefix('WEBP'.codeUnits, 8)) {
    return ImagePayload(bytes, 'webp', 'image/webp');
  }
  if (prefix('GIF87a'.codeUnits) || prefix('GIF89a'.codeUnits)) {
    return ImagePayload(bytes, 'gif', 'image/gif');
  }
  throw ArgumentError('JPEG, PNG, WEBP, GIF 사진을 선택해 주세요.');
}

// === 수정한 내용: 새 파일은 고유 경로에 저장하고 확정된 DB 실패만 정리하여 기존 사진 손상을 방지한다 ===
class StorageUploads {
  final SupabaseClient client;
  final String? _userId;
  final Map<String, List<String>> _files = {};
  StorageUploads(this.client) : _userId = client.auth.currentUser?.id;

  void checkSession() {
    if (client.auth.currentUser?.id != _userId) {
      throw StateError('로그인 계정이 변경되었습니다.');
    }
  }

  Future<String> upload(String bucket, XFile file, {String prefix = ''}) async {
    try {
      final image = await readImagePayload(file);
      checkSession();
      final path = '$prefix${newOperationId()}.${image.extension}';
      (_files[bucket] ??= []).add(path);
      await client.storage
          .from(bucket)
          .uploadBinary(
            path,
            image.bytes,
            fileOptions: FileOptions(contentType: image.contentType),
          )
          .timeout(const Duration(seconds: 30));
      checkSession();
      return client.storage.from(bucket).getPublicUrl(path);
    } catch (_) {
      await discard();
      rethrow;
    }
  }

  Future<T> commit<T>(Future<T> Function() write) async {
    checkSession();
    // === 수정한 내용: 저장 응답 대기를 제한하되 timeout의 저장 여부가 불명확하면 사진을 보존한다 ===
    try {
      return await write().timeout(const Duration(seconds: 30));
    } on PostgrestException catch (error) {
      // === 수정한 내용: gateway 오류도 저장 결과가 불명확하므로 확정된 입력·권한·제약 거절만 정리한다 ===
      final code = error.code ?? '';
      if (code.startsWith('22') ||
          code.startsWith('23') ||
          code.startsWith('42') ||
          code == 'PGRST202') {
        await discard();
      }
      rethrow;
    }
    // 통신 실패는 DB 저장 여부가 불명확하므로 참조될 수 있는 파일을 삭제하지 않습니다.
  }

  Future<void> discard() async {
    if (client.auth.currentUser?.id != _userId) return;
    for (final entry in _files.entries) {
      try {
        await client.storage
            .from(entry.key)
            .remove(entry.value)
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        debugPrint('미사용 업로드 파일을 정리하지 못했습니다.');
      }
    }
    _files.clear();
  }
}
