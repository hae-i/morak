import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// === 수정한 내용: 기존 공개 주소는 식별자로만 사용하고 사진은 현재 세션으로 권한 검사 후 읽는다 ===
class StoragePhotoRef {
  final String bucket, path;
  const StoragePhotoRef(this.bucket, this.path);
  static StoragePhotoRef? parse(String value, String storageUrl) {
    final uri = Uri.tryParse(value);
    final base = Uri.parse(storageUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.scheme != base.scheme ||
        uri.origin != base.origin ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    final prefix = '${base.path}/object/public/';
    if (!uri.path.startsWith(prefix)) return null;
    final parts = uri.path.substring(prefix.length).split('/');
    if (parts.length < 2 ||
        !const {
          'profiles',
          'group_covers',
          'meetup_photos',
        }.contains(parts.first)) {
      return null;
    }
    final path = parts.skip(1).join('/');
    if (path.isEmpty || parts.any((p) => p == '..' || p == '.')) return null;
    return StoragePhotoRef(parts.first, path);
  }
}

class PrivatePhotos {
  static int generation = 0;
  // === 수정한 내용: 계정 전환과 모임 탈퇴 후 이전 캐시·진행 중 다운로드를 함께 무효화한다 ===
  static void invalidate({bool clearMemoryCache = false}) {
    generation++;
    if (clearMemoryCache) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
  }

  static Future<Uint8List> download(
    SupabaseClient client,
    StoragePhotoRef ref, {
    String? expectedUser,
    int? expectedGeneration,
  }) async {
    final user = expectedUser ?? client.auth.currentUser?.id;
    final epoch = expectedGeneration ?? generation;
    void check() {
      if (user == null ||
          client.auth.currentUser?.id != user ||
          epoch != generation) {
        throw StateError('사진 접근 권한을 다시 확인해 주세요.');
      }
    }

    check();
    final bytes = BytesBuilder(copy: false);
    final result = Completer<Uint8List>();
    late final StreamSubscription<Uint8List> subscription;
    void fail() {
      if (!result.isCompleted) {
        result.completeError(StateError('사진을 불러오지 못했습니다. 권한과 연결 상태를 확인해 주세요.'));
      }
      unawaited(subscription.cancel());
    }

    // === 수정한 내용: 청크가 계속 도착해도 전체 다운로드를 30초 이내로 제한하고 스트림을 취소한다 ===
    final timer = Timer(const Duration(seconds: 30), fail);
    subscription = client.storage
        .from(ref.bucket)
        .downloadStream(ref.path)
        .listen(
          (chunk) {
            if (result.isCompleted) return;
            try {
              check();
              if (bytes.length + chunk.length > 10 * 1024 * 1024) {
                throw StateError('사진 크기를 확인해 주세요.');
              }
              bytes.add(chunk);
            } catch (_) {
              fail();
            }
          },
          onError: (Object error, StackTrace stack) => fail(),
          onDone: () {
            if (result.isCompleted) return;
            try {
              check();
              result.complete(bytes.takeBytes());
            } catch (_) {
              fail();
            }
          },
        );
    try {
      return await result.future;
    } finally {
      timer.cancel();
      await subscription.cancel();
    }
  }
}

ImageProvider privatePhoto(String url) {
  // 로컬 웹 미리보기와 외부 이미지는 인증 헤더 없이 기존 방식으로 표시합니다.
  if (!url.contains('/storage/v1/object/public/')) return NetworkImage(url);
  final client = Supabase.instance.client;
  final ref = StoragePhotoRef.parse(url, client.storage.from('profiles').url);
  if (ref == null) return NetworkImage(url);
  return PrivatePhotoProvider(
    client,
    ref,
    client.auth.currentUser?.id,
    PrivatePhotos.generation,
  );
}

// 디스크에 인증 사진을 저장하지 않으며 메모리 캐시 키에도 계정과 권한 세대를 포함합니다.
class PrivatePhotoProvider extends ImageProvider<PrivatePhotoProvider> {
  final SupabaseClient client;
  final StoragePhotoRef ref;
  final String? user;
  final int generation;
  const PrivatePhotoProvider(this.client, this.ref, this.user, this.generation);
  @override
  Future<PrivatePhotoProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    PrivatePhotoProvider key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _load(decode),
    scale: 1,
    debugLabel: 'Private photo',
  );
  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    if (user == null) throw StateError('로그인이 필요합니다.');
    final bytes = await PrivatePhotos.download(
      client,
      ref,
      expectedUser: user,
      expectedGeneration: generation,
    );
    final codec = await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    if (client.auth.currentUser?.id != user ||
        generation != PrivatePhotos.generation) {
      codec.dispose();
      throw StateError('사진 접근 권한이 변경되었습니다.');
    }
    return codec;
  }

  @override
  bool operator ==(Object other) =>
      other is PrivatePhotoProvider &&
      identical(client, other.client) &&
      ref.bucket == other.ref.bucket &&
      ref.path == other.ref.path &&
      user == other.user &&
      generation == other.generation;
  @override
  int get hashCode =>
      Object.hash(client, ref.bucket, ref.path, user, generation);
}

// === 수정한 내용: 기존 로딩·오류 UI를 유지하며 공개 다운로드와 디스크 캐시를 인증 이미지로 교체한다 ===
class PrivatePhotoImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit? fit;
  final double? width, height;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;
  const PrivatePhotoImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });
  @override
  Widget build(BuildContext context) => Image(
    image: privatePhoto(imageUrl),
    fit: fit,
    width: width,
    height: height,
    gaplessPlayback: false,
    loadingBuilder: (context, child, progress) => progress == null
        ? child
        : (placeholder?.call(context, imageUrl) ?? child),
    frameBuilder: (context, child, frame, sync) =>
        frame == null ? (placeholder?.call(context, imageUrl) ?? child) : child,
    errorBuilder: (context, error, stack) =>
        errorWidget?.call(context, imageUrl, StateError('사진을 불러오지 못했습니다.')) ??
        const Icon(Icons.broken_image_outlined),
  );
}
