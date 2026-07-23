import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// A recognized text block with its (optional) translation.
class DetectedItem {
  final List<Point<int>> corners;
  final String original;
  final String? translated;
  DetectedItem({
    required this.corners,
    required this.original,
    this.translated,
  });
}

/// Draws translation plates anchored to the original text: each plate is
/// positioned and rotated to match the recognized text block, so it stays
/// "stuck" to the sign as the camera moves.
class OverlayPainter extends CustomPainter {
  final List<DetectedItem> items;
  final Size? imageSize;
  final InputImageRotation? rotation;
  final CameraLensDirection lensDirection;

  OverlayPainter({
    required this.items,
    required this.imageSize,
    required this.rotation,
    required this.lensDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final imgSize = imageSize;
    final rot = rotation;
    if (imgSize == null || rot == null) return;

    for (final item in items) {
      if (item.corners.length < 4) continue;
      final pts = item.corners
          .map((p) => Offset(
                translateX(p.x.toDouble(), size, imgSize, rot, lensDirection),
                translateY(p.y.toDouble(), size, imgSize, rot, lensDirection),
              ))
          .toList();

      final tl = pts[0], tr = pts[1], bl = pts[3];
      final center = Offset(
        (pts[0].dx + pts[1].dx + pts[2].dx + pts[3].dx) / 4,
        (pts[0].dy + pts[1].dy + pts[2].dy + pts[3].dy) / 4,
      );
      final width = (tr - tl).distance;
      final height = (bl - tl).distance;
      if (width < 6 || height < 6 || width.isNaN || height.isNaN) continue;
      final angle = atan2(tr.dy - tl.dy, tr.dx - tl.dx);

      final display = item.translated ?? item.original;
      final ready = item.translated != null;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: width + 10,
        height: height + 6,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = ready ? const Color(0xF2101418) : const Color(0x99000000),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color =
              ready ? const Color(0xFF00E5A0) : const Color(0x5500E5A0),
      );

      final tp = _fitText(display, width, height, ready);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  TextPainter _fitText(String text, double maxW, double maxH, bool ready) {
    double fontSize = maxH.clamp(10.0, 34.0);
    late TextPainter tp;
    while (true) {
      tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: ready ? Colors.white : Colors.white70,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            height: 1.05,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 3,
        ellipsis: '…',
      )..layout(maxWidth: maxW);
      if (fontSize <= 10 || (tp.width <= maxW && tp.height <= maxH)) break;
      fontSize -= 1.0;
    }
    return tp;
  }

  @override
  bool shouldRepaint(covariant OverlayPainter oldDelegate) => true;
}

double translateX(
  double x,
  Size canvasSize,
  Size imageSize,
  InputImageRotation rotation,
  CameraLensDirection lens,
) {
  switch (rotation) {
    case InputImageRotation.rotation90deg:
      return x *
          canvasSize.width /
          (Platform.isIOS ? imageSize.width : imageSize.height);
    case InputImageRotation.rotation270deg:
      return canvasSize.width -
          x *
              canvasSize.width /
              (Platform.isIOS ? imageSize.width : imageSize.height);
    case InputImageRotation.rotation0deg:
    case InputImageRotation.rotation180deg:
      switch (lens) {
        case CameraLensDirection.back:
          return x * canvasSize.width / imageSize.width;
        default:
          return canvasSize.width - x * canvasSize.width / imageSize.width;
      }
  }
}

double translateY(
  double y,
  Size canvasSize,
  Size imageSize,
  InputImageRotation rotation,
  CameraLensDirection lens,
) {
  switch (rotation) {
    case InputImageRotation.rotation90deg:
    case InputImageRotation.rotation270deg:
      return y *
          canvasSize.height /
          (Platform.isIOS ? imageSize.height : imageSize.width);
    case InputImageRotation.rotation0deg:
    case InputImageRotation.rotation180deg:
      return y * canvasSize.height / imageSize.height;
  }
}
