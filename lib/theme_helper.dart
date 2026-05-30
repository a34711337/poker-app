import 'package:flutter/material.dart';

Widget forceLightTheme(Widget child) {
  return Theme(
    data: ThemeData.light().copyWith(
      scaffoldBackgroundColor: const Color(0xFFF2F2F7),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        surfaceTintColor: Colors.white,
      ),

      cardColor: Colors.white,

      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: Colors.black,
        displayColor: Colors.black,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    ),

    child: child,
  );
}