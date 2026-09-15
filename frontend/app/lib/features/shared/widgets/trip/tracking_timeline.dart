import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';

class TrackingStep {
  final String label;
  final DateTime? timestamp;
  final bool done;

  const TrackingStep({
    required this.label,
    this.timestamp,
    required this.done,
  });
}

class TrackingTimeline extends StatelessWidget {
  final List<TrackingStep> steps;

  const TrackingTimeline({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < steps.length; i++)
          _TimelineRow(
            step: steps[i],
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final TrackingStep step;
  final bool isLast;

  const _TimelineRow({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = step.done ? AppColors.primaryColor : AppColors.offline;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: step.done ? color : AppColors.white,
                  border: Border.all(color: color, width: 2),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: CustomPaint(
                    size: const Size(2, double.infinity),
                    painter: _DashedLinePainter(color: color.withValues(alpha: 0.4)),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: step.done ? FontWeight.w700 : FontWeight.w500,
                      color: step.done ? AppColors.textPrimary : AppColors.offline,
                    ),
                  ),
                  if (step.timestamp != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        DateFormat('d MMM • HH:mm').format(step.timestamp!),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.offline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dashHeight = 4.0;
    const dashSpace = 3.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(size.width / 2, y), Offset(size.width / 2, y + dashHeight), paint);
      y += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) => oldDelegate.color != color;
}
