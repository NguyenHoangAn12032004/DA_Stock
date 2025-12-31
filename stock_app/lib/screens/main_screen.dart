import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../presentation/providers/auth_provider.dart';
import 'home_screen.dart';
import 'portfolio_screen.dart';
import 'learn_screen.dart';
import 'news_screen.dart';
import 'ai_assistant_screen.dart';
import 'settings_screen.dart';
import 'help_support_screen.dart';
import 'discover_screen.dart';
import 'trade_screen.dart';
import 'alerts_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 0; // Default to Market (Home)

  // Screens for the tabs (excluding the center action)
  final List<Widget> _screens = [
    const HomeScreen(), // Market
    const DiscoverScreen(), // Discover
    const NewsScreen(), // News
    const PortfolioScreen(), // Portfolio
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onTradeTapped() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TradeScreen(symbol: 'HPG')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A2633) : Colors.white;
    final navBarColor = isDark ? const Color(0xFF101922) : Colors.white;

    return Scaffold(
      // Drawer for "Remaining Functions"
      drawer: _buildDrawer(isDark),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      floatingActionButton: SizedBox(
        width: 64,
        height: 64,
        child: FloatingActionButton(
          onPressed: _onTradeTapped,
          backgroundColor: AppColors.primary,
          elevation: 4,
          shape: const CircleBorder(),
          child: const Icon(Icons.swap_horiz, size: 32, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: navBarColor,
        elevation: 8,
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.bar_chart_outlined, Icons.bar_chart, 'Market'),
              _buildNavItem(1, Icons.explore_outlined, Icons.explore, 'Discover'),
              const SizedBox(width: 48), // Space for FAB
              _buildNavItem(2, Icons.newspaper_outlined, Icons.newspaper, 'News'),
              _buildNavItem(3, Icons.pie_chart_outline, Icons.pie_chart, 'Portfolio'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? AppColors.primary : const Color(0xFF9CABBA);

    return InkWell(
      onTap: () => _onItemTapped(index),
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(bool isDark) {
    final userState = ref.watch(authControllerProvider);
    final user = userState.asData?.value;
    final displayName = user?.displayName ?? 'InvestMate User';
    final email = user?.email ?? 'user@example.com';

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF111418) : Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AppColors.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.person, size: 40, color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  email,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _buildDrawerItem(Icons.smart_toy_outlined, 'AI Assistant', () {
            Navigator.pop(context); // Close drawer
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AiAssistantScreen()),
            );
          }, isDark),
          _buildDrawerItem(Icons.school_outlined, 'Learning Center', () {
            Navigator.pop(context);
            _onItemTapped(2); // Switch to News/Learn tab
          }, isDark),
          _buildDrawerItem(Icons.pie_chart_outline, 'My Portfolio', () {
            Navigator.pop(context);
            _onItemTapped(3); // Switch to Portfolio tab (Index 3)
          }, isDark),
          _buildDrawerItem(Icons.settings_outlined, 'Settings', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          }, isDark),
          _buildDrawerItem(Icons.notifications_outlined, 'Price Alerts', () {
            Navigator.pop(context);
            Navigator.push(
               context,
               MaterialPageRoute(builder: (context) => const AlertsScreen()),
            );
          }, isDark),
          const Divider(),
          _buildDrawerItem(Icons.help_outline, 'Help & Support', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HelpSupportScreen()),
            );
          }, isDark),
          _buildDrawerItem(Icons.logout, 'Log Out', () {
             ref.read(authControllerProvider.notifier).signOut();
          }, isDark),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap, bool isDark) {
    return ListTile(
      leading: Icon(icon, color: isDark ? Colors.white : const Color(0xFF111418)),
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF111418),
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
