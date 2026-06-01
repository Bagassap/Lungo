import 'package:flutter/material.dart';

class LungoSnackbar {
  static void error(BuildContext context, String message) =>
      _show(context, message, const Color(0xFFDC2626), Icons.error_rounded);

  static void success(BuildContext context, String message) =>
      _show(context, message, const Color(0xFF059669), Icons.check_circle_rounded);

  static void warning(BuildContext context, String message) =>
      _show(context, message, const Color(0xFFD97706), Icons.warning_rounded);

  static void _show(BuildContext context, String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          duration: const Duration(seconds: 3),
        ),
      );
  }
}
