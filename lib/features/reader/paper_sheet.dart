import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../app/theme/app_theme.dart';

/// The Mushaf page as a sheet of paper (specs/002-print-like-mushaf-page/contracts/
/// reader-page-view.md › Sheet): the theme's paper colour, a faint grain, and a soft shade on
/// the binding side. The grain is generated once in memory, so it adds nothing to the app size.
class PaperSheet extends StatefulWidget {
  const PaperSheet({super.key, required this.bindingOnRight, required this.child});

  /// Side the page is bound on: the right for odd pages, the left for even ones.
  final bool bindingOnRight;
  final Widget child;

  static const tileSize = 128;

  /// Opacity of the grain at its strongest pixel, in the ink colour.
  static const textureOpacity = 0.03;

  /// Opacity of the binding shade at the very edge, in the ink colour.
  static const edgeOpacity = 0.06;

  /// Width of the binding shade.
  static const edgeWidth = 12.0;

  /// RGBA pixels of the grain tile: white, with a random alpha from a fixed seed.
  static Uint8List noisePixels() {
    final random = math.Random(1421);
    final pixels = Uint8List(tileSize * tileSize * 4);
    for (var i = 0; i < pixels.length; i += 4) {
      pixels[i] = pixels[i + 1] = pixels[i + 2] = 255;
      pixels[i + 3] = random.nextInt(256);
    }
    return pixels;
  }

  static Future<ui.Image>? _tile;

  /// The grain tile, decoded once per process.
  static Future<ui.Image> noiseTile() => _tile ??= () {
        final done = Completer<ui.Image>();
        ui.decodeImageFromPixels(
            noisePixels(), tileSize, tileSize, ui.PixelFormat.rgba8888, done.complete);
        return done.future;
      }();

  @override
  State<PaperSheet> createState() => _PaperSheetState();
}

class _PaperSheetState extends State<PaperSheet> {
  static ui.Image? _tile;

  @override
  void initState() {
    super.initState();
    if (_tile == null) {
      PaperSheet.noiseTile().then((t) {
        _tile = t;
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MathaniColors.of(context);
    return CustomPaint(
      painter: _PaperPainter(colors.surface, colors.ink, _tile, widget.bindingOnRight),
      child: widget.child,
    );
  }
}

class _PaperPainter extends CustomPainter {
  _PaperPainter(this.paper, this.ink, this.tile, this.bindingOnRight);

  final Color paper;
  final Color ink;
  final ui.Image? tile;
  final bool bindingOnRight;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = paper);
    final grain = tile;
    if (grain != null) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ImageShader(grain, TileMode.repeated, TileMode.repeated, Matrix4.identity().storage)
          ..colorFilter = ColorFilter.mode(
              ink.withValues(alpha: PaperSheet.textureOpacity), BlendMode.srcIn),
      );
    }
    final edge = bindingOnRight
        ? Rect.fromLTWH(size.width - PaperSheet.edgeWidth, 0, PaperSheet.edgeWidth, size.height)
        : Rect.fromLTWH(0, 0, PaperSheet.edgeWidth, size.height);
    final shade = ink.withValues(alpha: PaperSheet.edgeOpacity);
    canvas.drawRect(
      edge,
      Paint()
        ..shader = LinearGradient(
          begin: bindingOnRight ? Alignment.centerRight : Alignment.centerLeft,
          end: bindingOnRight ? Alignment.centerLeft : Alignment.centerRight,
          colors: [shade, shade.withValues(alpha: 0)],
        ).createShader(edge),
    );
  }

  @override
  bool shouldRepaint(_PaperPainter old) =>
      old.paper != paper || old.ink != ink || old.tile != tile || old.bindingOnRight != bindingOnRight;
}
