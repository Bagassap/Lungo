import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Consistent circular map pin (gradient/glow) used across waiting, ongoing
/// trip, and driver-active-trip maps. Optionally wraps itself in a looping
/// pulse animation (used for the "searching" state).
class MapPinMarker extends StatefulWidget {
  final IconData icon;
  final Color fillColor;
  final Color borderColor;
  final Color iconColor;
  final bool pulsing;
  final double size;

  const MapPinMarker({
    super.key,
    required this.icon,
    this.fillColor = AppColors.primaryColor,
    this.borderColor = Colors.white,
    this.iconColor = Colors.white,
    this.pulsing = false,
    this.size = 48,
  });

  @override
  State<MapPinMarker> createState() => _MapPinMarkerState();
}

class _MapPinMarkerState extends State<MapPinMarker>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _pulse;

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat(reverse: true);
      _pulse = Tween<double>(begin: 0.9, end: 1.15).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _pin() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [widget.fillColor, widget.fillColor.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: widget.borderColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: widget.fillColor.withValues(alpha: 0.45),
            blurRadius: 14,
          ),
        ],
      ),
      child: Icon(widget.icon, color: widget.iconColor, size: widget.size * 0.46),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_pulse == null) return _pin();
    return AnimatedBuilder(
      animation: _pulse!,
      builder: (_, child) => Transform.scale(scale: _pulse!.value, child: child),
      child: _pin(),
    );
  }
}
