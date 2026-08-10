/// 모바일·데스크톱에서는 브라우저 다운로드가 없다 — 호출될 일이 없는 자리표시자.
library;

import 'dart:typed_data';

Future<void> downloadImageBytes(Uint8List bytes, String filename) async {
  throw UnsupportedError('브라우저 다운로드는 웹에서만 쓴다');
}
