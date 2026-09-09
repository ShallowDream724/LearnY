import 'package:flutter/material.dart';

/// Canonical 1024-unit artwork. Platform assets are generated from these paths.
enum BrandLayer { complete, background, foreground, monochrome }

class LearnYIconArt extends CustomPainter {
  const LearnYIconArt({this.layer = BrandLayer.complete});
  final BrandLayer layer;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1024, size.height / 1024);
    const bounds = Rect.fromLTWH(0, 0, 1024, 1024);
    if (layer == BrandLayer.complete || layer == BrandLayer.background) {
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7D83C9), Color(0xFF5966AC), Color(0xFF374A7D)],
            stops: [0, .5, 1],
          ).createShader(bounds),
      );
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-.72, -.9),
            radius: 1.3,
            colors: [Color(0x24F4E8FF), Color(0x00F4E8FF)],
          ).createShader(bounds),
      );
    }
    if (layer != BrandLayer.background) {
      if (layer == BrandLayer.foreground || layer == BrandLayer.monochrome) {
        // Android's outer foreground area moves beneath the launcher mask.
        canvas.translate(512, 512);
        canvas.scale(.8);
        canvas.translate(-512, -512);
      }
      final book = Path()
        ..moveTo(243, 275)
        ..cubicTo(348, 260, 441, 319, 510, 392)
        ..cubicTo(570, 320, 654, 272, 775, 252)
        ..quadraticBezierTo(794, 249, 794, 269)
        ..lineTo(794, 448)
        ..quadraticBezierTo(794, 465, 778, 468)
        ..cubicTo(681, 484, 607, 523, 545, 583)
        ..lineTo(545, 744)
        ..quadraticBezierTo(545, 766, 524, 769)
        ..lineTo(483, 776)
        ..quadraticBezierTo(464, 779, 464, 760)
        ..lineTo(464, 585)
        ..cubicTo(392, 525, 322, 496, 246, 492)
        ..quadraticBezierTo(227, 491, 227, 473)
        ..lineTo(227, 294)
        ..quadraticBezierTo(227, 278, 243, 275)
        ..close();
      if (layer == BrandLayer.monochrome) {
        canvas.drawPath(book, Paint()..color = Colors.white);
      } else {
        canvas.drawPath(
          book.shift(const Offset(0, 9)),
          Paint()
            ..color = const Color(0x24233160)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
        );
        canvas.drawPath(
          book,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFF5), Color(0xFFF0F4F8), Color(0xFFD5E1EF)],
            ).createShader(bounds),
        );
        canvas.save();
        canvas.clipPath(book);
        final turn = Path()
          ..moveTo(510, 392)
          ..cubicTo(507, 465, 505, 526, 505, 580)
          ..lineTo(505, 788)
          ..lineTo(820, 788)
          ..lineTo(820, 223)
          ..close();
        canvas.drawPath(
          turn,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0x28476489), Color(0x00FFFFFF), Color(0x5CFFFFFF)],
              stops: [0, .22, 1],
            ).createShader(const Rect.fromLTWH(505, 250, 289, 530)),
        );
        canvas.restore();
        canvas.drawPath(
          book,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0x5CFFFFFF),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(LearnYIconArt oldDelegate) => layer != oldDelegate.layer;
}
