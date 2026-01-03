import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../presentation/providers/settings_provider.dart';
import '../presentation/providers/auth_provider.dart';
import 'static_content_screens.dart';
import 'help_support_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Local state is no longer needed for these preferences, as we watch providers directly.
  
  void _showLanguageDialog(Locale currentLocale) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.language),
        children: [
          {'name': 'English', 'code': 'en'},
          {'name': 'Vietnamese', 'code': 'vi'}
        ].map((lang) => SimpleDialogOption(
                  onPressed: () {
                    ref.read(languageControllerProvider.notifier).setLocale(Locale(lang['code']!));
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(lang['name']!),
                        if (currentLocale.languageCode == lang['code'])
                          const Icon(Icons.check, color: AppColors.primary),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  void _showDataRefreshDialog(String currentRate) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Data Refresh Rate'),
        children: ['Auto', 'Manual', '1 Minute', '5 Minutes']
            .map((rate) => SimpleDialogOption(
                  onPressed: () {
                    ref.read(dataRefreshControllerProvider.notifier).setRate(rate);
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(rate),
                        if (currentRate == rate)
                          const Icon(Icons.check, color: AppColors.primary),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Stock App'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('Developed by: GitHub Copilot'),
            SizedBox(height: 8),
            Text('© 2025 All rights reserved.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Watch Providers
    final themeMode = ref.watch(themeModeControllerProvider);
    final notificationsEnabled = ref.watch(notificationsControllerProvider); 
    
    final languageState = ref.watch(languageControllerProvider);
    final dataRefreshState = ref.watch(dataRefreshControllerProvider);
    final newsAlertsState = ref.watch(newsAlertsControllerProvider);
    final aiInsightsState = ref.watch(aiInsightsControllerProvider);

    final userState = ref.watch(authControllerProvider);
    final userEmail = userState.asData?.value?.email ?? 'user@example.com';

    final isDarkMode = themeMode.value == ThemeMode.dark;
    final isPriceAlertsEnabled = notificationsEnabled.value ?? true;
    final Locale currentLocale = languageState.value ?? const Locale('en');
    final currentRefreshRate = dataRefreshState.value ?? 'Auto';
    final isNewsAlertsEnabled = newsAlertsState.value ?? true;
    final isAiInsightsEnabled = aiInsightsState.value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('PREFERENCES', isDark),
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
                    Icons.contrast,
                    l10n.darkMode,
                    isDarkMode,
                    (val) {
                      final newMode = val ? ThemeMode.dark : ThemeMode.light;
                      ref.read(themeModeControllerProvider.notifier).setThemeMode(newMode);
                    },
                  ),
                  const Divider(height: 1),
                  _buildNavItem(
                    context,
                    Icons.language,
                    l10n.language,
                    currentLocale.languageCode == 'vi' ? 'Tiếng Việt' : 'English',
                    onTap: () => _showLanguageDialog(currentLocale),
                  ),
                  const Divider(height: 1),
                  _buildNavItem(
                    context,
                    Icons.sync,
                    'Data Refresh',
                    currentRefreshRate,
                    onTap: () => _showDataRefreshDialog(currentRefreshRate),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('NOTIFICATIONS', isDark),
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
                    Icons.attach_money,
                    'Price Alerts', // TODO: Add key if needed
                    isPriceAlertsEnabled,
                    (val) {
                      ref.read(notificationsControllerProvider.notifier).toggle(val);
                    },
                  ),
                  const Divider(height: 1),
                  _buildSwitchItem(
                    context,
                    Icons.article,
                    'News Alerts',
                    isNewsAlertsEnabled,
                    (val) => ref.read(newsAlertsControllerProvider.notifier).toggle(val),
                  ),
                  const Divider(height: 1),
                  _buildSwitchItem(
                    context,
                    Icons.auto_awesome,
                    'AI Insights',
                    isAiInsightsEnabled,
                    (val) => ref.read(aiInsightsControllerProvider.notifier).toggle(val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('PRIVACY & LEGAL', isDark),
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
                  _buildNavItem(
                    context,
                    Icons.lock,
                    'Privacy & Data Usage',
                    '',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PrivacyPolicyScreen())),
                  ),
                  const Divider(height: 1),
                  _buildNavItem(
                    context,
                    Icons.description,
                    'Terms of Service',
                    '',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TermsOfServiceScreen())),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('SUPPORT', isDark),
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
                  _buildNavItem(
                    context,
                    Icons.help,
                    'Help Center',
                    '',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HelpSupportScreen())),
                  ),
                  const Divider(height: 1),
                  _buildNavItem(
                    context,
                    Icons.info,
                    'About App',
                    'v2.4.0',
                    onTap: _showAboutDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
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
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.danger.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Logged in as $userEmail',
                style: TextStyle(
                  color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 24),
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

  Widget _buildSwitchItem(BuildContext context, IconData icon, String title,
      bool value, Function(bool) onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : const Color(0xFF111418),
              ),
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

  Widget _buildNavItem(BuildContext context, IconData icon, String title,
      String trailing,
      {VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF111418),
                ),
              ),
            ),
            if (trailing.isNotEmpty)
              Text(
                trailing,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? const Color(0xFF9CABBA)
                      : const Color(0xFF637588),
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
