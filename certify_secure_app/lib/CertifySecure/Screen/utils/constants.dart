// lib/utils/constants.dart

import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF2196F3);
  static const Color secondary = Color(0xFF1976D2);
  static const Color accent = Color(0xFF64B5F6);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Background Colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);

  // Border Colors
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFEEEEEE);

  // Gradient Colors
  static const List<Color> primaryGradient = [
    primary,
    secondary,
  ];

  // Overlay Colors
  static Color overlay30 = Colors.black.withOpacity(0.3);
  static Color overlay50 = Colors.black.withOpacity(0.5);
  
  // Shimmer Colors
  static const Color shimmerBase = Color(0xFFEEEEEE);
  static const Color shimmerHighlight = Color(0xFFFAFAFA);
}

class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle body1 = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
  );

  static const TextStyle body2 = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
}

class AppConstants {
  // Animation Durations
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String certificatesCollection = 'certificates';
  static const String notificationsCollection = 'notifications';

  // Storage Paths
  static const String profileImagesPath = 'profile_images';
  static const String certificatesPath = 'certificates';

  // Pagination
  static const int defaultPageSize = 10;

  // Validation
  static const int maxFileSize = 5 * 1024 * 1024; // 5MB
  static const List<String> allowedFileTypes = ['.pdf', '.jpg', '.jpeg', '.png'];

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 12.0;
  static const double defaultElevation = 2.0;

  // Error Messages
  static const String defaultErrorMessage = 'Something went wrong';
  static const String networkErrorMessage = 'Please check your internet connection';
  static const String unauthorizedMessage = 'Please login to continue';
}