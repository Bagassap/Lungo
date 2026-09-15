import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

const double _kBarHeight = 68;
const double _kFabSize = 62;
const double _kFabOverflow = 26;

class LungoBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int chatBadge;

  const LungoBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.chatBadge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return SizedBox(
      height: _kBarHeight + _kFabOverflow + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            height: _kBarHeight + bottomInset,
            decoration: const BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _NavItem(
                      icon: Icons.history_outlined,
                      filledIcon: Icons.history_rounded,
                      label: 'Aktivitas',
                      index: 1,
                      currentIndex: currentIndex,
                      onTap: onTap,
                    ),
                    _NavItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      filledIcon: Icons.chat_bubble_rounded,
                      label: 'Chat',
                      index: 2,
                      currentIndex: currentIndex,
                      onTap: onTap,
                      badge: chatBadge,
                    ),
                    const SizedBox(width: _kFabSize),
                    _NavItem(
                      icon: Icons.person_outline_rounded,
                      filledIcon: Icons.person_rounded,
                      label: 'Profil',
                      index: 3,
                      currentIndex: currentIndex,
                      onTap: onTap,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: _FloatingHomeButton(
              isSelected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingHomeButton extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _FloatingHomeButton({required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: _kFabSize,
        height: _kFabSize,
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: AppColors.accentColor, width: 3)
              : null,
          boxShadow: const [
            BoxShadow(
              color: Color(0x330B0940),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          isSelected ? Icons.home_rounded : Icons.home_outlined,
          color: AppColors.primaryColor,
          size: 28,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData filledIcon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int badge;

  const _NavItem({
    required this.icon,
    required this.filledIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? filledIcon : icon,
                  color: isSelected ? Colors.white : Colors.white54,
                  size: 24,
                ),
                if (badge > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white54,
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(top: 4),
              width: isSelected ? 6 : 0,
              height: isSelected ? 6 : 0,
              decoration: const BoxDecoration(
                color: AppColors.accentColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
