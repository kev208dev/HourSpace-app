/// 웹 전용 — PNG 바이트를 브라우저 다운로드로 떨어뜨린다.
///
/// 웹에는 갤러리가 없으므로 gal 대신 이 경로를 쓴다. 조건부 import 로 갈리므로
/// 모바일 빌드에는 이 파일이 들어가지 않는다.
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> downloadImageBytes(Uint8List bytes, String filename) async {
  final blob = web.Blob(
    <JSUint8Array>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/png'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
