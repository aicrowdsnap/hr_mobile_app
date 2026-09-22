import 'package:flutter/material.dart';

class DayNightSwitch extends StatelessWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onChanged;

  const DayNightSwitch({
    super.key,
    required this.isDarkMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!isDarkMode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 64,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          // Matches the dark/light track background from the image
          color: isDarkMode ? const Color(0xFF6B7280) : const Color(0xFFE5E7EB),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Light mode background moon (grey)
            AnimatedOpacity(
              opacity: isDarkMode ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: const Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: Icon(Icons.nights_stay_rounded, size: 16, color: Colors.black26),
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: isDarkMode ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(Icons.wb_sunny_rounded, size: 16, color: Colors.white54),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: isDarkMode ? 32 : 2,
              right: isDarkMode ? 2 : 32,
              top: 2,
              bottom: 2,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isDarkMode ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
                  size: 16,
                  // Orange for sun, Blue for moon
                  color: isDarkMode ? const Color(0xFF5C6BC0) : const Color(0xFFFFA726),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}