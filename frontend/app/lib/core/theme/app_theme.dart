import 'package:flutter/material.dart';

class AppColors {
  static const primaryColor   = Color(0xFF0540F2);
  static const primaryDark    = Color(0xFF04198C);
  static const darkest        = Color(0xFF0B0940);
  static const primaryLight   = Color(0xFFF0F4FF);
  static const accentColor    = Color(0xFFF2CB05);
  static const secondaryColor = Color(0xFF056CF2);
  static const backgroundColor = Color(0xFFF0F4FF);
  static const textPrimary    = Color(0xFF04198C);
  static const textSecondary  = Color(0xFF056CF2);
  static const white          = Color(0xFFFFFFFF);
  static const online         = Color(0xFF22C55E);
  static const offline        = Color(0xFF94A3B8);
}

const _satoshi = 'Satoshi';

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        fontFamily: _satoshi,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(
              allowEnterRouteSnapshotting: false,
            ),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryColor).copyWith(
          primary: AppColors.primaryColor,
          secondary: AppColors.secondaryColor,
          surface: AppColors.backgroundColor,
        ),
        scaffoldBackgroundColor: AppColors.backgroundColor,
        textTheme: const TextTheme(
          displayLarge:  TextStyle(fontFamily: _satoshi),
          displayMedium: TextStyle(fontFamily: _satoshi),
          displaySmall:  TextStyle(fontFamily: _satoshi),
          headlineLarge:  TextStyle(fontFamily: _satoshi),
          headlineMedium: TextStyle(fontFamily: _satoshi),
          headlineSmall:  TextStyle(fontFamily: _satoshi),
          titleLarge:  TextStyle(fontFamily: _satoshi),
          titleMedium: TextStyle(fontFamily: _satoshi),
          titleSmall:  TextStyle(fontFamily: _satoshi),
          bodyLarge:  TextStyle(fontFamily: _satoshi),
          bodyMedium: TextStyle(fontFamily: _satoshi),
          bodySmall:  TextStyle(fontFamily: _satoshi),
          labelLarge:  TextStyle(fontFamily: _satoshi),
          labelMedium: TextStyle(fontFamily: _satoshi),
          labelSmall:  TextStyle(fontFamily: _satoshi),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: AppColors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: _satoshi,
            color: AppColors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentColor,
            foregroundColor: AppColors.primaryDark,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            minimumSize: const Size(double.infinity, 56),
            textStyle: const TextStyle(
              fontFamily: _satoshi,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.white,
          elevation: 4,
          shadowColor: AppColors.primaryColor.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.primaryLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          labelStyle: const TextStyle(fontFamily: _satoshi, color: AppColors.textSecondary),
          hintStyle: const TextStyle(
            fontFamily: _satoshi,
            color: Color.fromRGBO(5, 108, 242, 0.5),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.primaryColor,
          unselectedItemColor: AppColors.secondaryColor,
          type: BottomNavigationBarType.fixed,
          elevation: 12,
        ),
      );
}
