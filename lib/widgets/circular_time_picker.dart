import 'dart:math';
import 'package:flutter/material.dart';

class CircularTimePicker extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final Function(double) onChanged;
  final Color color;

  const CircularTimePicker({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.color = Colors.blue,
  });

  @override
  State<CircularTimePicker> createState() => _CircularTimePickerState();
}

class _CircularTimePickerState extends State<CircularTimePicker> {
  void _handlePan(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Beregn vinkel (atan2 returnerer -pi til pi)
    double angle = atan2(localPosition.dy - center.dy, localPosition.dx - center.dx);
    
    // Roter så 0 grader er toppen (kl. 12)
    angle += pi / 2;

    // Normaliser til 0 -> 2*pi
    if (angle < 0) {
      angle += 2 * pi;
    }

    // Konverter vinkel til procent
    double percentage = angle / (2 * pi);
    
    // Beregn værdi
    double range = widget.max - widget.min;
    double newValue = widget.min + (range * percentage);

    // Snap til hele tal (valgfrit)
    newValue = newValue.roundToDouble();

    // Clamp værdien
    newValue = newValue.clamp(widget.min, widget.max);

    widget.onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        
        return GestureDetector(
          onPanStart: (details) => _handlePan(details.localPosition, size),
          onPanUpdate: (details) => _handlePan(details.localPosition, size),
          onTapDown: (details) => _handlePan(details.localPosition, size),
          child: CustomPaint(
            size: size,
            painter: _CircularSliderPainter(
              value: widget.value,
              minValue: widget.min, // RETTET: Sender widget.min til minValue
              maxValue: widget.max, // RETTET: Sender widget.max til maxValue
              color: widget.color,
              backgroundColor: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white12 
                  : Colors.grey.shade200,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${widget.value.round()}",
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    "minutter",
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CircularSliderPainter extends CustomPainter {
  final double value;
  // RETTET: Omdøbt fra 'min'/'max' til 'minValue'/'maxValue' for at undgå konflikt med math.min
  final double minValue; 
  final double maxValue;
  final Color color;
  final Color backgroundColor;

  _CircularSliderPainter({
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Nu virker min() funktionen korrekt, fordi vi ikke har en variabel der hedder 'min'
    final radius = min(size.width, size.height) / 2 - 20; 
    const strokeWidth = 15.0;

    // 1. Tegn baggrund
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // 2. Beregn vinkel
    double range = maxValue - minValue;
    double normalizedValue = (value - minValue) / range;
    double sweepAngle = 2 * pi * normalizedValue;
    
    const startAngle = -pi / 2; // Start ved kl. 12

    // 3. Tegn fremskridt
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );

    // 4. Tegn Knob
    double knobAngle = startAngle + sweepAngle;
    
    final knobCenter = Offset(
      center.dx + radius * cos(knobAngle),
      center.dy + radius * sin(knobAngle),
    );

    // Skygge
    canvas.drawCircle(
      knobCenter,
      18,
      Paint()..color = Colors.black.withOpacity(0.15)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Hvid kant
    canvas.drawCircle(knobCenter, 12, Paint()..color = Colors.white);
    // Farvet indre
    canvas.drawCircle(knobCenter, 8, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CircularSliderPainter oldDelegate) {
    return oldDelegate.value != value || 
           oldDelegate.color != color ||
           oldDelegate.backgroundColor != backgroundColor;
  }
}