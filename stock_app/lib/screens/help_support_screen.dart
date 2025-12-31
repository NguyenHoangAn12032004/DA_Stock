import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111418) : const Color(0xFFF6F7F8);
    final textColor = isDark ? Colors.white : const Color(0xFF111418);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Help & Support',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSearchBar(isDark),
          const SizedBox(height: 24),
          Text(
            'Popular Topics',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildTopicItem(Icons.account_balance_wallet_outlined, 'Deposit & Withdrawal', isDark),
          _buildTopicItem(Icons.swap_horiz, 'Trading & Spot', isDark),
          _buildTopicItem(Icons.security, 'Account Security', isDark),
          _buildTopicItem(Icons.card_giftcard, 'Rewards & Promos', isDark),
          const SizedBox(height: 24),
          Text(
            'Contact Us',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildContactItem(Icons.chat_bubble_outline, 'Live Chat', '24/7 Support', isDark),
          _buildContactItem(Icons.email_outlined, 'Email Support', 'Response within 24h', isDark),
          const SizedBox(height: 24),
          Text(
            'FAQ',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildFaqItem('How to verify my identity?', isDark),
          _buildFaqItem('Why is my withdrawal pending?', isDark),
          _buildFaqItem('How to reset 2FA?', isDark),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2633) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.transparent : Colors.grey.shade300,
        ),
      ),
      child: TextField(
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          icon: Icon(Icons.search, color: isDark ? Colors.grey : Colors.grey.shade600),
          hintText: 'Search for issues...',
          hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade500),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildTopicItem(IconData icon, String title, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2633) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF111418),
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: isDark ? Colors.grey : Colors.grey.shade400),
        onTap: () {},
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String title, String subtitle, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2633) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: isDark ? Colors.white : const Color(0xFF111418)),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF111418),
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isDark ? Colors.grey : Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        onTap: () {},
      ),
    );
  }

  Widget _buildFaqItem(String question, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2633) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF111418),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'This is a placeholder answer for the FAQ item. In a real app, this would contain detailed instructions.',
              style: TextStyle(
                color: isDark ? Colors.grey : Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
