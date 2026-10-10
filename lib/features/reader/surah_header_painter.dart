import 'package:flutter/painting.dart';

/// Paints the frame of a surah header line: a rounded outline with small diamond end-caps, in
/// `accent-ink`. No fill and no shadow; the brand guide keeps decoration away from ayah text.
void paintSurahFrame(Canvas canvas, Rect rect, Color color) {
  final stroke = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = rect.height * 0.035;
  final r = rect.height * 0.28;
  canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)), stroke);
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect.deflate(rect.height * 0.09), Radius.circular(r * 0.7)),
    stroke..strokeWidth = rect.height * 0.018,
  );
  final fill = Paint()..color = color;
  final d = rect.height * 0.16;
  for (final cx in [rect.left, rect.right]) {
    final c = Offset(cx, rect.center.dy);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - d)
        ..lineTo(c.dx + d * 0.7, c.dy)
        ..lineTo(c.dx, c.dy + d)
        ..lineTo(c.dx - d * 0.7, c.dy)
        ..close(),
      fill,
    );
  }
}
