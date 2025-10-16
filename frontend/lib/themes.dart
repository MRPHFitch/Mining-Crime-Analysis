import 'package:flutter/material.dart';

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: Color(0xFF8F00FF),
  scaffoldBackgroundColor: Color(0xFFFFFDF9),
  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFF8F00FF),
    foregroundColor: Colors.white,
  ),
  colorScheme: ColorScheme.light(
    primary: Color(0xFF8F00FF),
    secondary: Color(0xFFFFA500),
    tertiary: Colors.orange,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Colors.white),
  ),
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: Color(0xFF6F3096),
  scaffoldBackgroundColor: Color(0xFF121212),
  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFF6F3096),
    foregroundColor: Colors.white,
  ),
  colorScheme: ColorScheme.dark(
    primary: Color(0xFF6F3096),
    secondary: Color(0xFFFFA500),
    tertiary: Colors.orange,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Colors.white),
  ),
);
