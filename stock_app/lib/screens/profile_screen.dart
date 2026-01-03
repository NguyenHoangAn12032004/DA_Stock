import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/auth_provider.dart';
import '../theme/app_colors.dart';
import 'settings_screen.dart';
import 'personal_info_screen.dart';
import 'security_settings_screen.dart';
import 'investment_preferences_screen.dart';

import 'package:stock_app/l10n/app_localizations.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userState = ref.watch(authControllerProvider);
    final user = userState.asData?.value;

    final displayName = user?.displayName ?? 'User';
    final email = user?.email ?? 'user@example.com';
    // Use a default avatar if none provided
    const avatarUrl = "https://lh3.googleusercontent.com/aida-public/AB6AXuBhADJ-5Vc3CKdOGmnD51JZGr5iKMVEbDGqTnIgwM-lJI9A2J8KjSvLXH2r-bdy9aN97wd16OwqbZGBaAtOXSxfi1AtdM2I3b9va8aRSaKwIdMCmNukNP1R8am42ThRwmOgo0WluO3uOM1zXMz1gVR2ZCVVNRox2ipNn9ln8srtQ6FyLMhuw2Syrh-DQtUHr3_GHhMlPTP2WAhryzhLHhYVwHHE2Qb-nv2HoaUCsuGkDDeZx8LIy9IIz3EjD9i19re46xw8Ftz4sHDE";

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profile),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header Card
            Container(
              padding: const EdgeInsets.all(24),
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
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: const DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          ),
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.editProfileComingSoon)),
                              );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit,
                                size: 16, color: AppColors.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF111418),
                    ),
                  ),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFF9CABBA)
                          : const Color(0xFF637588),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified,
                            size: 16, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'INTERMEDIATE · PRO',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: _buildQuickStat(
                    context,
                    value: "Oct '23",
                    label: l10n.memberSince,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickStat(
                    context,
                    value: '12',
                    label: l10n.stocksWatched,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Account Settings
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  l10n.account,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: isDark
                        ? const Color(0xFF9CABBA)
                        : const Color(0xFF637588),
                  ),
                ),
              ),
            ),
            Container(
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
                  _buildSettingItem(
                    context,
                    Icons.person,
                    l10n.personalInfo,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const PersonalInfoScreen()),
                    ),
                  ),
                  const Divider(height: 1),
                  _buildSettingItem(
                    context,
                    Icons.lock,
                    l10n.securitySettings,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SecuritySettingsScreen()),
                    ),
                  ),
                  const Divider(height: 1),
                  _buildSettingItem(
                    context,
                    Icons.tune,
                    l10n.investmentPrefs,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const InvestmentPreferencesScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Features
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  l10n.features,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: isDark
                        ? const Color(0xFF9CABBA)
                        : const Color(0xFF637588),
                  ),
                ),
              ),
            ),
            Container(
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
                  _buildSwitchItem(
                    context,
                    Icons.school,
                    l10n.paperTrading,
                    l10n.paperTradingDesc,
                    true,
                    (val) {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // General Settings & Support
            Container(
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
                  _buildSettingItem(
                    context,
                    Icons.settings,
                    l10n.generalSettings,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsScreen()),
                    ),
                  ),
                  const Divider(height: 1),
                  _buildSettingItem(
                    context,
                    Icons.help,
                    l10n.helpSupport,
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Log Out
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                    ref.read(authControllerProvider.notifier).signOut();
                    if (context.mounted) {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: Text(
                  l10n.logout,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(
                    color: isDark
                        ? const Color(0xFF3B4754)
                        : const Color(0xFFDCE0E5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem(BuildContext context, IconData icon, String title,
      String subtitle, bool value, Function(bool) onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EAF6), // Light indigo
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF3F51B5), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF111418),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF9CABBA)
                        : const Color(0xFF637588),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(BuildContext context,
      {required String value, required String label}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF3B4754) : const Color(0xFFDCE0E5),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(BuildContext context, IconData icon, String title,
      {VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : const Color(0xFF111418),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
      ),
      onTap: onTap,
    );
  }
}
