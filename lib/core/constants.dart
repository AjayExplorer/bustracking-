import 'package:flutter/material.dart';

class AppConstants {
  // Backend API and WebSocket URLs
  // When running in an Android Emulator, use '10.0.2.2' instead of '127.0.0.1'.
  // However, we will allow dynamic configuration or auto-detect in services.
  static const String localHost = '127.0.0.1:8787';
  static const String emulatorHost = '10.0.2.2:8787';
  
  static const String httpBaseUrl = 'http://$localHost';
  static const String wsBaseUrl = 'ws://$localHost';

  // Design Tokens (Aesthetic Palette)
  static const Color primaryColor = Color(0xFF6366F1); // Indigo
  static const Color accentColor = Color(0xFFF59E0B);  // Amber
  
  // Dark Mode Colors
  static const Color darkBg = Color(0xFF0F172A);       // Sleek slate-900
  static const Color darkCard = Color(0xFF1E293B);     // Slate-800
  static const Color darkText = Color(0xFFF8FAFC);     // Slate-50
  static const Color darkTextMuted = Color(0xFF94A3B8); // Slate-400

  // Light Mode Colors
  static const Color lightBg = Color(0xFFF8FAFC);      // Slate-50
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightTextMuted = Color(0xFF64748B);

  // Status Colors
  static const Color success = Color(0xFF10B981);      // Emerald-500
  static const Color danger = Color(0xFFEF4444);       // Red-500
  static const Color info = Color(0xFF3B82F6);         // Blue-500

  // Simulation speed in m/s (approx 30 km/h)
  static const double fallbackSpeed = 8.33; 
}
