import 'package:flutter/material.dart';

class AppColors {
  // 1. BRAND COLOURS 
  static const Color primaryCyan = Color(0xFF00CFFA); // Was brightCyan
  static const Color skyBlue = Color(0xFF00B9F5);
  static const Color purple = Color(0xFF7B2CF5);
  
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // 2. LIGHT THEME COLOURS
  static const Color lightBackground = Color(0xFFF4F7F9); // Main app background
  static const Color lightSurface = Color(0xFFFFFFFF);    // Cards, Dialogs, BottomSheets
  static const Color lightSurfaceHighlight = Color(0xFFE2E8F0); // Secondary boxes, filled fields
  
  static const Color lightTextPrimary = Color(0xFF0F172A); // Headings, main text
  static const Color lightTextSecondary = Color(0xFF64748B); // Subtitles, hints
  
  static const Color lightBorder = Color(0xFFCBD5E1); // Outlines, dividers
  static const Color lightIcon = Color(0xFF475569); // Default icon colour

  // 3. DARK THEME COLOURS
  static const Color darkBackground = Color(0xFF001A4D); // Main app background
  static const Color darkSurface = Color(0xFF2D0D52);    // Cards, Dialogs
  static const Color darkSurfaceHighlight = Color(0xFF4D0D5C); // Secondary boxes
  
  static const Color darkTextPrimary = Color(0xFFFFFFFF); // Headings, main text
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Subtitles, hints
  
  static const Color darkBorder = Color(0xFF334155); // Outlines, dividers
  static const Color darkIcon = Color(0xFFCBD5E1); // Default icon colour
}