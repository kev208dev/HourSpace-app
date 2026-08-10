/// PNG 바이트를 플랫폼에 맞는 방식으로 저장한다.
///
/// 모바일은 기존대로 갤러리(gal)에 넣고, 웹에는 갤러리가 없으므로 브라우저
/// 다운로드로 떨어뜨린다. 저장 결과 문구를 한 곳에서 만들어, 시간표 내보내기와
/// 화면 캡처가 서로 다른 메시지를 쓰지 않게 한다.
library;

import 'dart:typed_data';

import 'package:gal/gal.dart';

import '../core/platform/platform_support.dart';
import 'image_save_web.dart' if (dart.library.io) 'image_save_io.dart';

/// 저장 결과 — 호출부는 이 문구를 그대로 스낵바에 띄우면 된다.
class ImageSaveResult {
  final bool ok;
  final String message;
  const ImageSaveResult(this.ok, this.message);
}

/// [bytes] 를 [name] 이름으로 저장한다. 확장자는 붙이지 않는다.
Future<ImageSaveResult> saveImageBytes(Uint8List bytes, String name) async {
  if (!PlatformSupport.gallerySave) {
    try {
      await downloadImageBytes(bytes, '$name.png');
      return const ImageSaveResult(true, '이미지를 내려받았어요');
    } catch (_) {
      return const ImageSaveResult(false, '이미지를 내려받지 못했어요');
    }
  }
  try {
    await Gal.putImageBytes(bytes, name: name);
    return const ImageSaveResult(true, '이미지를 갤러리에 저장했어요');
  } on GalException catch (e) {
    return ImageSaveResult(false, '저장 실패: ${e.type.message}');
  } catch (_) {
    return const ImageSaveResult(false, '이미지를 저장하지 못했어요');
  }
}
