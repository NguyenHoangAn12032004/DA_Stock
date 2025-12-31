import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class InvestmentPreferencesScreen extends StatefulWidget {
  const InvestmentPreferencesScreen({super.key});

  @override
  State<InvestmentPreferencesScreen> createState() =>
      _InvestmentPreferencesScreenState();
}

class _InvestmentPreferencesScreenState
    extends State<InvestmentPreferencesScreen> {
  String _riskTolerance = 'Moderate';
  final List<String> _sectors = [
    'Technology',
    'Healthcare',
    'Finance',
    'Energy',
    'Consumer Goods'
  ];
  final Set<String> _selectedSectors = {'Technology', 'Finance'};
  double _investmentHorizon = 5;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Investment Preferences'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('RISK PROFILE', isDark),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF3B4754)
                      : const Color(0xFFDCE0E5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Risk Tolerance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF111418),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: ['Conservative', 'Moderate', 'Aggressive']
                        .map((level) => ChoiceChip(
                              label: Text(level),
                              selected: _riskTolerance == level,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _riskTolerance = level);
                                }
                              },
                              selectedColor: AppColors.primary.withOpacity(0.2),
                              labelStyle: TextStyle(
                                color: _riskTolerance == level
                                    ? AppColors.primary
                                    : (isDark
                                        ? const Color(0xFF9CABBA)
                                        : const Color(0xFF637588)),
                              ),
                              backgroundColor: isDark
                                  ? const Color(0xFF2A3441)
                                  : const Color(0xFFF0F2F5),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('PREFERRED SECTORS', isDark),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF3B4754)
                      : const Color(0xFFDCE0E5),
                ),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _sectors.map((sector) {
                  final isSelected = _selectedSectors.contains(sector);
                  return FilterChip(
                    label: Text(sector),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedSectors.add(sector);
                        } else {
                          _selectedSectors.remove(sector);
                        }
                      });
                    },
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark
                              ? const Color(0xFF9CABBA)
                              : const Color(0xFF637588)),
                    ),
                    backgroundColor: isDark
                        ? const Color(0xFF2A3441)
                        : const Color(0xFFF0F2F5),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('INVESTMENT HORIZON', isDark),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF3B4754)
                      : const Color(0xFFDCE0E5),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Duration',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color:
                              isDark ? Colors.white : const Color(0xFF111418),
                        ),
                      ),
                      Text(
                        '${_investmentHorizon.round()} years',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _investmentHorizon,
                    min: 1,
                    max: 30,
                    divisions: 29,
                    activeColor: AppColors.primary,
                    onChanged: (value) =>
                        setState(() => _investmentHorizon = value),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
        ),
      ),
    );
  }
}
