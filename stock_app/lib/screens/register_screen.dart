import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../presentation/providers/auth_provider.dart';
import 'main_screen.dart';

import 'package:stock_app/l10n/app_localizations.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _termsAccepted = false;

  void _handleRegister() {
    final l10n = AppLocalizations.of(context)!;
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseAcceptTerms)),
      );
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final fullName = _fullNameController.text.trim();

    if (email.isEmpty || password.isEmpty || fullName.isEmpty) return;

    ref.read(authControllerProvider.notifier).signUp(email, password, fullName);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Listen to Auth State
    ref.listen<AsyncValue>(authControllerProvider, (prev, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.registrationFailed}: ${next.error}')),
        );
      } else if (next is AsyncData && next.value != null) {
        // Navigate
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      }
    });

    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AsyncLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2632) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF3B4754)
                      : const Color(0xFFDBE0E6),
                ),
              ),
              child: Image.network(
                "https://lh3.googleusercontent.com/aida-public/AB6AXuCiKEb46uUPFQmRjq5MhWxaBZt71Udt4crmXVYhyA2DKDmaYY_6OYJN3wwQqKFjAH0efB351zBCGOudaY2fHdtnlNz6I0SjqYjrOxRs-O4RfLlt8YNTi5MdJw8wlo-X59To5uR-V6CyzUj7kBKOzinwq_4tpvDi74Q_ahgbKU50UYtSeUGDAeyloOu5tHlU7yq98LWq_oJ2Aj0-7COH4D9SbbtfvkgNTU0rhY_Hok1tMD8lRuB1oMd_jaLg8D6VkGcWj_Z7vmFZszLn",
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.createAccountTitle,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF111418),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.startJourney,
              style: TextStyle(
                fontSize: 16,
                color: isDark
                    ? const Color(0xFF93A2B7)
                    : const Color(0xFF60758A),
              ),
            ),
            const SizedBox(height: 32),
            // Form
            _buildLabel(l10n.fullName, isDark),
            const SizedBox(height: 8),
            TextField(
              controller: _fullNameController,
              decoration: _inputDecoration(l10n.fullNameHint, isDark),
            ),
            const SizedBox(height: 16),
            _buildLabel(l10n.email, isDark),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              decoration: _inputDecoration('name@example.com', isDark),
            ),
            const SizedBox(height: 16),
            _buildLabel(l10n.password, isDark),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: _inputDecoration(l10n.passwordHint, isDark)
                  .copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: isDark
                        ? const Color(0xFF93A2B7)
                        : const Color(0xFF60758A),
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Password Strength
            Row(
              children: [
                Expanded(child: _buildStrengthBar(true)),
                const SizedBox(width: 4),
                Expanded(child: _buildStrengthBar(true)),
                const SizedBox(width: 4),
                Expanded(child: _buildStrengthBar(true, opacity: 0.5)),
                const SizedBox(width: 4),
                Expanded(child: _buildStrengthBar(false)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.passwordStrength,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF93A2B7)
                        : const Color(0xFF60758A),
                  ),
                ),
                Text(
                  l10n.good,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildLabel(l10n.confirmPassword, isDark),
            const SizedBox(height: 8),
            TextField(
              obscureText: true,
              decoration: _inputDecoration(l10n.confirmPasswordHint, isDark),
            ),
            const SizedBox(height: 16),
            // Terms
            Row(
              children: [
                Checkbox(
                  value: _termsAccepted,
                  onChanged: (val) {
                    setState(() {
                      _termsAccepted = val ?? false;
                    });
                  },
                  activeColor: AppColors.primary,
                ),
                Expanded(
                  child: Text(
                    l10n.agreeTerms,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? const Color(0xFF93A2B7)
                          : const Color(0xFF60758A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        l10n.createAccountButton,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF111418),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? const Color(0xFF93A2B7) : const Color(0xFF60758A),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF1A2632) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3B4754) : const Color(0xFFDBE0E6),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3B4754) : const Color(0xFFDBE0E6),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  Widget _buildStrengthBar(bool active, {double opacity = 1.0}) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: active
            ? AppColors.success.withOpacity(opacity)
            : const Color(0xFFDBE0E6),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
