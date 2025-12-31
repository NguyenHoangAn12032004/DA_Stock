import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn'),
        backgroundColor: isDark ? const Color(0xFF111418) : Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 64,
              color: isDark ? const Color(0xFF3B4754) : const Color(0xFFDCE0E5),
            ),
            const SizedBox(height: 16),
            Text(
              'Learning Center',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF111418),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Educational content coming soon',
              style: TextStyle(
                color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
