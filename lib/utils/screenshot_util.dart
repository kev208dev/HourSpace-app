import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'image_save.dart';
import '../app.dart' show scaffoldMessengerKey;

// 전역 key — MainShell의 RepaintBoundary에 연결
final screenshotKey = GlobalKey();

void _snack(String msg) {
  scaffoldMessengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

/// 현재 화면(RepaintBoundary)을 PNG로 캡처해 기기 갤러리에 저장한다.
Future<void> captureAndSaveImage() async {
  final boundary = screenshotKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
  if (boundary == null) return;
  try {
    final image = await boundary.toImage(pixelRatio: 2.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    final now = DateTime.now();
    final name =
        'Surlap_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.millisecondsSinceEpoch}';
    final result = await saveImageBytes(bytes.buffer.asUint8List(), name);
    _snack(result.message);
  } catch (_) {
    _snack('이미지를 저장하지 못했어요');
  }
}
