import 'package:flutter/material.dart';

/// Renders geometric origami line-art for Guardian profiles (Owl, Lion, Falcon)
/// in charcoal and warm gold accents without external SVG dependencies.
class OrigamiGuardianIcon extends StatelessWidget {
  const OrigamiGuardianIcon({
    super.key,
    required this.guardianId,
    this.size = 28,
    this.primaryColor,
    this.accentColor,
  });

  final String guardianId;
  final double size;
  final Color? primaryColor;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectivePrimary =
        primaryColor ?? (isDark ? const Color(0xFFE4E4E7) : const Color(0xFF27272A));
    final effectiveAccent =
        accentColor ?? (isDark ? const Color(0xFFEAB308) : const Color(0xFFC9A227));

    final normalized = guardianId.toLowerCase().trim();

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _OrigamiPainter(
          guardianType: normalized,
          primaryColor: effectivePrimary,
          accentColor: effectiveAccent,
        ),
      ),
    );
  }
}

class _OrigamiPainter extends CustomPainter {
  const _OrigamiPainter({
    required this.guardianType,
    required this.primaryColor,
    required this.accentColor,
  });

  final String guardianType;
  final Color primaryColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final linePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w / 18).clamp(1.2, 2.4)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final goldLinePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w / 20).clamp(1.0, 2.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final goldFillPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    if (guardianType.contains('lion')) {
      _paintLion(canvas, w, h, linePaint, goldLinePaint, goldFillPaint);
    } else if (guardianType.contains('falcon')) {
      _paintFalcon(canvas, w, h, linePaint, goldLinePaint, goldFillPaint);
    } else {
      // Default to Owl
      _paintOwl(canvas, w, h, linePaint, goldLinePaint, goldFillPaint);
    }
  }

  void _paintOwl(
    Canvas canvas,
    double w,
    double h,
    Paint line,
    Paint goldLine,
    Paint goldFill,
  ) {
    // Outer silhouette path (origami head & body)
    final bodyPath = Path()
      ..moveTo(w * 0.16, h * 0.22) // Left ear tip
      ..lineTo(w * 0.50, h * 0.32) // Crown center dip
      ..lineTo(w * 0.84, h * 0.22) // Right ear tip
      ..lineTo(w * 0.88, h * 0.56) // Right wing upper
      ..lineTo(w * 0.72, h * 0.86) // Right wing lower
      ..lineTo(w * 0.50, h * 0.94) // Tail base
      ..lineTo(w * 0.28, h * 0.86) // Left wing lower
      ..lineTo(w * 0.12, h * 0.56) // Left wing upper
      ..close();
    canvas.drawPath(bodyPath, line);

    // Brow & Face fold
    final browPath = Path()
      ..moveTo(w * 0.16, h * 0.22)
      ..lineTo(w * 0.50, h * 0.50)
      ..lineTo(w * 0.84, h * 0.22);
    canvas.drawPath(browPath, line);

    // Warm Gold Origami Diamond Eyes
    final leftEye = Path()
      ..moveTo(w * 0.34, h * 0.38)
      ..lineTo(w * 0.42, h * 0.45)
      ..lineTo(w * 0.34, h * 0.52)
      ..lineTo(w * 0.26, h * 0.45)
      ..close();
    canvas.drawPath(leftEye, goldFill);
    canvas.drawPath(leftEye, goldLine);

    final rightEye = Path()
      ..moveTo(w * 0.66, h * 0.38)
      ..lineTo(w * 0.74, h * 0.45)
      ..lineTo(w * 0.66, h * 0.52)
      ..lineTo(w * 0.58, h * 0.45)
      ..close();
    canvas.drawPath(rightEye, goldFill);
    canvas.drawPath(rightEye, goldLine);

    // Beak triangle (warm gold)
    final beak = Path()
      ..moveTo(w * 0.45, h * 0.52)
      ..lineTo(w * 0.55, h * 0.52)
      ..lineTo(w * 0.50, h * 0.64)
      ..close();
    canvas.drawPath(beak, goldFill);
    canvas.drawPath(beak, goldLine);

    // Chest fold facets
    final chestFolds = Path()
      ..moveTo(w * 0.50, h * 0.64)
      ..lineTo(w * 0.32, h * 0.76)
      ..lineTo(w * 0.50, h * 0.94)
      ..lineTo(w * 0.68, h * 0.76)
      ..lineTo(w * 0.50, h * 0.64);
    canvas.drawPath(chestFolds, line);
  }

  void _paintLion(
    Canvas canvas,
    double w,
    double h,
    Paint line,
    Paint goldLine,
    Paint goldFill,
  ) {
    // Origami Lion Mane - faceted star polygon
    final mane = Path()
      ..moveTo(w * 0.50, h * 0.10) // Top crest
      ..lineTo(w * 0.68, h * 0.18)
      ..lineTo(w * 0.88, h * 0.16) // Upper right point
      ..lineTo(w * 0.82, h * 0.36)
      ..lineTo(w * 0.94, h * 0.52) // Right mid point
      ..lineTo(w * 0.80, h * 0.68)
      ..lineTo(w * 0.74, h * 0.88) // Lower right point
      ..lineTo(w * 0.50, h * 0.94) // Bottom chin point
      ..lineTo(w * 0.26, h * 0.88) // Lower left point
      ..lineTo(w * 0.20, h * 0.68)
      ..lineTo(w * 0.06, h * 0.52) // Left mid point
      ..lineTo(w * 0.18, h * 0.36)
      ..lineTo(w * 0.12, h * 0.16) // Upper left point
      ..lineTo(w * 0.32, h * 0.18)
      ..close();
    canvas.drawPath(mane, line);

    // Inner facial shield
    final faceShield = Path()
      ..moveTo(w * 0.32, h * 0.28)
      ..lineTo(w * 0.68, h * 0.28)
      ..lineTo(w * 0.74, h * 0.54)
      ..lineTo(w * 0.50, h * 0.80)
      ..lineTo(w * 0.26, h * 0.54)
      ..close();
    canvas.drawPath(faceShield, line);

    // Warm Gold faceted muzzle / nose triangle
    final muzzle = Path()
      ..moveTo(w * 0.50, h * 0.44)
      ..lineTo(w * 0.60, h * 0.58)
      ..lineTo(w * 0.50, h * 0.72)
      ..lineTo(w * 0.40, h * 0.58)
      ..close();
    canvas.drawPath(muzzle, goldFill);
    canvas.drawPath(muzzle, goldLine);

    // Eyes
    canvas.drawLine(Offset(w * 0.36, h * 0.42), Offset(w * 0.44, h * 0.46), line);
    canvas.drawLine(Offset(w * 0.64, h * 0.42), Offset(w * 0.56, h * 0.46), line);
  }

  void _paintFalcon(
    Canvas canvas,
    double w,
    double h,
    Paint line,
    Paint goldLine,
    Paint goldFill,
  ) {
    // Dynamic origami swept-wings falcon
    final wings = Path()
      ..moveTo(w * 0.50, h * 0.12) // Crown tip
      ..lineTo(w * 0.70, h * 0.22)
      ..lineTo(w * 0.94, h * 0.32) // Right wing tip
      ..lineTo(w * 0.76, h * 0.54)
      ..lineTo(w * 0.64, h * 0.76)
      ..lineTo(w * 0.50, h * 0.94) // Tail point
      ..lineTo(w * 0.36, h * 0.76)
      ..lineTo(w * 0.24, h * 0.54)
      ..lineTo(w * 0.06, h * 0.32) // Left wing tip
      ..lineTo(w * 0.30, h * 0.22)
      ..close();
    canvas.drawPath(wings, line);

    // Wing fold lines
    final innerFolds = Path()
      ..moveTo(w * 0.30, h * 0.22)
      ..lineTo(w * 0.50, h * 0.48)
      ..lineTo(w * 0.70, h * 0.22);
    canvas.drawPath(innerFolds, line);

    final spine = Path()
      ..moveTo(w * 0.50, h * 0.12)
      ..lineTo(w * 0.50, h * 0.94);
    canvas.drawPath(spine, line);

    // Warm Gold faceted sharp raptor beak
    final beak = Path()
      ..moveTo(w * 0.44, h * 0.44)
      ..lineTo(w * 0.56, h * 0.44)
      ..lineTo(w * 0.50, h * 0.62)
      ..close();
    canvas.drawPath(beak, goldFill);
    canvas.drawPath(beak, goldLine);

    // Warm gold eye accents
    canvas.drawLine(Offset(w * 0.38, h * 0.36), Offset(w * 0.46, h * 0.40), goldLine);
    canvas.drawLine(Offset(w * 0.62, h * 0.36), Offset(w * 0.54, h * 0.40), goldLine);
  }

  @override
  bool shouldRepaint(covariant _OrigamiPainter oldDelegate) {
    return oldDelegate.guardianType != guardianType ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor;
  }
}
