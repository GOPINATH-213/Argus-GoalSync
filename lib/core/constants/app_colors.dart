import 'package:flutter/material.dart';

class AppColors {
  // Dark Theme Palette (Primary theme)
  static const Color darkBackground = Color(0xFF0F172A); // Slate 900
  static const Color darkSurface = Color(0xFF1E293B);    // Slate 800
  static const Color darkSurfaceCard = Color(0xFF334155); // Slate 700
  
  static const Color primary = Color(0xFF6366F1);        // Indigo 500
  static const Color primaryLight = Color(0xFF818CF8);   // Indigo 400
  static const Color secondary = Color(0xFFEC4899);     // Pink 500
  
  // Status Colors (completed today, pending, missed)
  static const Color success = Color(0xFF10B981);       // Emerald 500 (Completed)
  static const Color pending = Color(0xFFF59E0B);       // Amber 500 (Pending)
  static const Color danger = Color(0xFFEF4444);        // Red 500 (Missed)
  static const Color info = Color(0xFF0EA5E9);          // Sky 500
  
  // Gamification & Streak Colors
  static const Color streakActive = Color(0xFFF59E0B);  // Gold/Amber
  static const Color streakGold = Color(0xFFFFD700);    // True Gold
  static const Color xpColor = Color(0xFF8B5CF6);       // Purple 500
  
  // Light Theme Palette (Optional toggle)
  static const Color lightBackground = Color(0xFFF8FAFC); // Slate 50
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceCard = Color(0xFFE2E8F0); // Slate 200

  // Gradients for high-fidelity UI cards
  static const Gradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF4F46E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient streakGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient xpGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
