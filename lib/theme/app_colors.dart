import 'package:flutter/material.dart';

class AppColors {
  // Brand Color Palette
  static const Color brightCyan = Color(0xFF00CFFA);
  static const Color skyBlue = Color(0xFF00B9F5);
  static const Color blue = Color(0xFF0077F9);
  static const Color deepBlue = Color(0xFF0055F5);
  static const Color purple = Color(0xFF7B2CF5);
  static const Color violet = Color(0xFF8A35F5);
  static const Color lightPurple = Color(0xFFB588F5);
  static const Color magenta = Color(0xFFD42CF5);

  // Dark Variants (Great for replacing your current 0xFF2A3036 backgrounds)
  static const Color darkCyan = Color(0xFF003D4D);
  static const Color darkBlue = Color(0xFF001A4D);
  static const Color darkPurple = Color(0xFF2D0D52);
  static const Color darkMagenta = Color(0xFF4D0D5C);

  // Light Theme Base
  static const Color background = Color(0xFFFFFFFF);
  static const Color foreground = Color(0xFF1E293B);
  static const Color card = Color(0xFFF7F9FC);
  
  // Semantic Colors
  static const Color primary = Color(0xFF001A4D);
  static const Color secondary = Color(0xFFDBEAFE);
  static const Color muted = Color(0xFFEEF2F6);
  static const Color accent = Color(0xFF3B82F6);
  static const Color destructive = Color(0xFFDC2626);

  // Custom Gradients (Extracted from your Sidebar CSS)
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF001A4D), Color(0xFF2D0D52), Color(0xFF4D0D5C)],
  );
}