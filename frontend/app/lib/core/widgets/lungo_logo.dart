import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class LungoLogo extends StatelessWidget {
  final Color? iconColor;
  final Color? titleColor;
  final Color? subtitleColor;

  const LungoLogo({
    super.key,
    this.iconColor,
    this.titleColor,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.electric_moped,
          color: iconColor ?? AppColors.primaryColor,
          size: 32,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Lungo',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 28,
                color: titleColor ?? AppColors.primaryColor,
                height: 1.0,
              ),
            ),
            Text(
              'Ojek Online',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: subtitleColor ?? AppColors.secondaryColor,
                height: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
