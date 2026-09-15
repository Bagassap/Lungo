import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import 'tracking_timeline.dart';

/// Shared "active trip" card used by waiting_screen, booking trip_screen,
/// and the driver active-trip bar. Renders id/title/route/status/contact/
/// timeline chrome; screen-specific business UI (live meter, phase banner,
/// action buttons) is injected via [footer] and stays owned by the caller.
class TripTrackingCard extends StatelessWidget {
  final String idLabel;
  final VoidCallback? onCopyId;
  final String title;
  final String originText;
  final String destText;
  final String statusText;
  final Color statusColor;
  final String? metaText;
  final String? contactName;
  final String? contactPhotoUrl;
  final IconData contactFallbackIcon;
  final VoidCallback? onCallTap;
  final List<TrackingStep> timelineSteps;
  final VoidCallback? onViewAllTap;
  final Widget? footer;

  const TripTrackingCard({
    super.key,
    required this.idLabel,
    this.onCopyId,
    required this.title,
    required this.originText,
    required this.destText,
    required this.statusText,
    required this.statusColor,
    this.metaText,
    this.contactName,
    this.contactPhotoUrl,
    this.contactFallbackIcon = Icons.person_rounded,
    this.onCallTap,
    this.timelineSteps = const [],
    this.onViewAllTap,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Color(0x1A0B0940), blurRadius: 24, offset: Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.offline.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _IdRow(idLabel: idLabel, onCopyId: onCopyId),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              _InfoRow(
                originText: originText,
                destText: destText,
                metaText: metaText,
                statusText: statusText,
                statusColor: statusColor,
              ),
              if (contactName != null) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                _ContactRow(
                  contactName: contactName!,
                  contactPhotoUrl: contactPhotoUrl,
                  contactFallbackIcon: contactFallbackIcon,
                  onCallTap: onCallTap,
                ),
              ],
              if (timelineSteps.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionHeader(onViewAllTap: onViewAllTap),
                const SizedBox(height: 12),
                TrackingTimeline(steps: timelineSteps),
              ],
              if (footer != null) ...[
                const SizedBox(height: 4),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IdRow extends StatelessWidget {
  final String idLabel;
  final VoidCallback? onCopyId;
  const _IdRow({required this.idLabel, this.onCopyId});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            idLabel,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.offline,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onCopyId != null)
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onCopyId!();
            },
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.copy_rounded, size: 15, color: AppColors.offline),
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String originText;
  final String destText;
  final String? metaText;
  final String statusText;
  final Color statusColor;

  const _InfoRow({
    required this.originText,
    required this.destText,
    required this.metaText,
    required this.statusText,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _InfoBlock(label: 'Dari', value: originText)),
              const SizedBox(width: 8),
              Expanded(child: _InfoBlock(label: 'Tujuan', value: destText)),
              if (metaText != null) ...[
                const SizedBox(width: 8),
                Expanded(child: _InfoBlock(label: 'Jarak', value: metaText!)),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            statusText,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String label;
  final String value;
  const _InfoBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.offline),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  final String contactName;
  final String? contactPhotoUrl;
  final IconData contactFallbackIcon;
  final VoidCallback? onCallTap;

  const _ContactRow({
    required this.contactName,
    required this.contactPhotoUrl,
    required this.contactFallbackIcon,
    required this.onCallTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primaryLight,
          backgroundImage: (contactPhotoUrl != null && contactPhotoUrl!.isNotEmpty)
              ? NetworkImage(contactPhotoUrl!)
              : null,
          child: (contactPhotoUrl == null || contactPhotoUrl!.isEmpty)
              ? Icon(contactFallbackIcon, color: AppColors.primaryColor, size: 22)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Driver',
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.offline),
              ),
              Text(
                contactName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (onCallTap != null)
          Material(
            color: AppColors.primaryColor,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onCallTap,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.call_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final VoidCallback? onViewAllTap;
  const _SectionHeader({this.onViewAllTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Riwayat Perjalanan',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (onViewAllTap != null)
          InkWell(
            onTap: onViewAllTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Lihat semua',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
