import 'package:flutter/material.dart';

/// 应用程序配置类
class AppConfig {
  /// 应用名称
  static const String appName = 'SuChat Tiny';

  /// 默认主题色
  static const Color primaryColor = Color(0xFF6750A4);

  /// 默认强调色
  static const Color accentColor = Color(0xFFD0BCFF);

  /// 默认错误色
  static const Color errorColor = Color(0xFFB3261E);

  /// 深色主题色
  static const Color darkPrimaryColor = Color(0xFFD0BCFF);

  /// 深色强调色
  static const Color darkAccentColor = Color(0xFF6750A4);

  /// 深色错误色
  static const Color darkErrorColor = Color(0xFFF2B8B5);

  /// 默认字体大小
  static const double defaultFontSize = 14.0;

  /// 获取MaterialApp主题
  // 简单示例主题
  static ThemeData getSimpleTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      useMaterial3: true,
    );
  }

  /// 获取浅色主题
  static ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      primaryColor: primaryColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  /// 获取深色主题
  static ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: darkPrimaryColor,
        brightness: Brightness.dark,
      ),
      primaryColor: darkPrimaryColor,
      scaffoldBackgroundColor: const Color(0xFF1A1A1A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF2D2D2D),
        foregroundColor: Colors.white,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: darkAccentColor,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkAccentColor,
          foregroundColor: Colors.white,
        ),
      ),
      cardTheme: const CardTheme(color: Color(0xFF2D2D2D)),
    );
  }
}
