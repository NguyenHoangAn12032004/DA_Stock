import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_wrapper.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0; // 0: Experience, 1: Risk, 2: Goal

  // Step 1: Experience
  int _experienceIndex = 0;
  final List<Map<String, dynamic>> _experienceOptions = [
    {
      'title': 'Beginner',
      'subtitle': 'I\'m new to investing',
      'icon': Icons.school_outlined,
    },
    {
      'title': 'Intermediate',
      'subtitle': 'I know the basics',
      'icon': Icons.trending_up,
    },
    {
      'title': 'Advanced',
      'subtitle': 'I\'m an active trader',
      'icon': Icons.candlestick_chart,
    },
  ];

  // Step 2: Risk
  int _riskIndex = 1;
  final List<Map<String, dynamic>> _riskOptions = [
    {
      'title': 'Low Risk',
      'subtitle': 'Preserve capital',
      'icon': Icons.security,
    },
    {
      'title': 'Moderate Risk',
      'subtitle': 'Balanced growth',
      'icon': Icons.balance,
    },
    {
      'title': 'High Risk',
      'subtitle': 'Maximize returns',
      'icon': Icons.show_chart,
    },
  ];

  // Step 3: Goal
  int _goalIndex = 0;
  bool _guidedExplanations = true;
  final List<Map<String, dynamic>> _goalOptions = [
    {
      'title': 'Learn & Build Confidence',
      'subtitle': 'Start small and learn the ropes',
      'icon': Icons.school,
    },
    {
      'title': 'Long-Term Growth',
      'subtitle': 'Compound wealth over time',
      'icon': Icons.trending_up,
    },
    {
      'title': 'Active Investing',
      'subtitle': 'Market analysis & frequent trades',
      'icon': Icons.bolt,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF111418) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111418);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: textColor),
                onPressed: _prevStep,
              )
            : null,
        actions: [
          TextButton(
            onPressed: _completeOnboarding,
            child: const Text(
              'Skip',
              style: TextStyle(
                color: Color(0xFF9CABBA),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Bar
              _buildProgressBar(isDark),
              const SizedBox(height: 32),

              // Content
              Expanded(
                child: _buildCurrentStepContent(isDark, textColor),
              ),

              // Footer Buttons
              _buildFooter(isDark),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(bool isDark) {
    return Row(
      children: List.generate(3, (index) {
        final isActive = index <= _currentStep;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            height: 4,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary
                  : (isDark ? const Color(0xFF2A3441) : const Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStepContent(bool isDark, Color textColor) {
    switch (_currentStep) {
      case 0:
        return _buildStep1(isDark, textColor);
      case 1:
        return _buildStep2(isDark, textColor);
      case 2:
        return _buildStep3(isDark, textColor);
      default:
        return const SizedBox.shrink();
    }
  }

  // Step 1: Experience
  Widget _buildStep1(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What\'s your investing experience?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textColor,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'We\'ll customize your educational feed and risk warnings based on your knowledge level.',
          style: TextStyle(
            fontSize: 16,
            color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: ListView.separated(
            itemCount: _experienceOptions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _buildOptionCard(
                index: index,
                selectedIndex: _experienceIndex,
                options: _experienceOptions,
                onTap: (idx) => setState(() => _experienceIndex = idx),
                isDark: isDark,
                textColor: textColor,
              );
            },
          ),
        ),
      ],
    );
  }

  // Step 2: Risk
  Widget _buildStep2(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How do you feel about investment risk?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textColor,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'We\'ll tailor your alerts and portfolio recommendations based on your comfort level.',
          style: TextStyle(
            fontSize: 16,
            color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: ListView.separated(
            itemCount: _riskOptions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _buildOptionCard(
                index: index,
                selectedIndex: _riskIndex,
                options: _riskOptions,
                onTap: (idx) => setState(() => _riskIndex = idx),
                isDark: isDark,
                textColor: textColor,
                isRadio: true,
              );
            },
          ),
        ),
        Center(
          child: Text(
            'You can change this anytime in Settings',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // Step 3: Goal
  Widget _buildStep3(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What\'s your main investing goal?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textColor,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'We\'ll tailor your daily insights and risk analysis based on your choice.',
          style: TextStyle(
            fontSize: 16,
            color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: ListView.separated(
            itemCount: _goalOptions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _buildOptionCard(
                index: index,
                selectedIndex: _goalIndex,
                options: _goalOptions,
                onTap: (idx) => setState(() => _goalIndex = idx),
                isDark: isDark,
                textColor: textColor,
              );
            },
          ),
        ),
        // Guided Explanations Toggle
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2028) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2A3441) : const Color(0xFFE0E0E0),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guided Explanations',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Show definitions for complex terms.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _guidedExplanations,
                onChanged: (val) => setState(() => _guidedExplanations = val),
                activeColor: AppColors.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildOptionCard({
    required int index,
    required int selectedIndex,
    required List<Map<String, dynamic>> options,
    required Function(int) onTap,
    required bool isDark,
    required Color textColor,
    bool isRadio = false,
  }) {
    final isSelected = selectedIndex == index;
    final borderColor = isSelected
        ? AppColors.primary
        : (isDark ? const Color(0xFF2A3441) : const Color(0xFFE0E0E0));
    final backgroundColor = isDark ? const Color(0xFF1A2028) : Colors.white;

    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A3441) : const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                options[index]['icon'],
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    options[index]['title'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    options[index]['subtitle'],
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
                    ),
                  ),
                ],
              ),
            ),
            if (isRadio)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF)),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              )
            else if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF),
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Text(
              _currentStep == 2 ? 'Finish Setup' : 'Continue',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        if (_currentStep > 0) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: _prevStep,
            child: Text(
              'Back',
              style: TextStyle(
                color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
    } else {
      _completeOnboarding();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showOnboarding', false);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
      );
    }
  }
}