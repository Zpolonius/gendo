import 'dart:math';
import 'package:flutter/material.dart';

class ThumbWheelWidget extends StatelessWidget {
  final double rotation;
  final VoidCallback onTap;
  final Function(double) onScroll;

  const ThumbWheelWidget({
    super.key,
    required this.rotation,
    required this.onTap,
    required this.onScroll,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) => onScroll(details.delta.dy),
      onTap: onTap,
      child: SizedBox(
        width: 120, 
        height: 300,
        child: CustomPaint(
          painter: _WheelPainter(rotation: rotation, color: Theme.of(context).primaryColor),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final double rotation;
  final Color color;

  _WheelPainter({required this.rotation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.8) // Opdateret til ny Flutter syntax (.withValues anbefales i nyeste, men .withOpacity virker altid)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width, size.height / 2);
    final radius = size.width * 0.8;

    // Tegn fælgen
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), pi / 2, pi, false, paint);

    // Tegn hak
    final tickPaint = Paint()..strokeWidth = 1.5;
    for (int i = -10; i < 10; i++) {
      double normalizedY = i * 0.15 + (rotation % 0.15);
      if (normalizedY > -1.2 && normalizedY < 1.2) {
         double xPos = size.width - (cos(normalizedY) * radius);
         double yPos = (size.height / 2) + (sin(normalizedY) * radius);
         
         double opacity = (1.0 - normalizedY.abs()).clamp(0.0, 1.0);
         tickPaint.color = color.withOpacity(opacity * 0.5);
         
         canvas.drawLine(Offset(center.dx, yPos), Offset(xPos, yPos), tickPaint);
      }
    }
    
    // Indikator pil
    final path = Path()
      ..moveTo(size.width - radius - 15, size.height / 2)
      ..lineTo(size.width - radius + 5, size.height / 2 - 6)
      ..lineTo(size.width - radius + 5, size.height / 2 + 6)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.redAccent);
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.rotation != rotation || old.color != color;
}