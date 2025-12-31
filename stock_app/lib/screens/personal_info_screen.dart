import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _nameController = TextEditingController(text: 'Alex Morgan');
  final _emailController = TextEditingController(text: 'alex.morgan@example.com');
  final _phoneController = TextEditingController(text: '+1 (555) 123-4567');
  final _dobController = TextEditingController(text: '1990-05-15');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Information'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Information updated successfully')),
              );
            },
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildAvatar(isDark),
            const SizedBox(height: 32),
            _buildTextField('Full Name', _nameController, isDark),
            const SizedBox(height: 16),
            _buildTextField('Email Address', _emailController, isDark,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            _buildTextField('Phone Number', _phoneController, isDark,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            _buildTextField('Date of Birth', _dobController, isDark,
                keyboardType: TextInputType.datetime),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(bool isDark) {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: const DecorationImage(
                image: NetworkImage(
                    "https://lh3.googleusercontent.com/aida-public/AB6AXuBhADJ-5Vc3CKdOGmnD51JZGr5iKMVEbDGqTnIgwM-lJI9A2J8KjSvLXH2r-bdy9aN97wd16OwqbZGBaAtOXSxfi1AtdM2I3b9va8aRSaKwIdMCmNukNP1R8am42ThRwmOgo0WluO3uOM1zXMz1gVR2ZCVVNRox2ipNn9ln8srtQ6FyLMhuw2Syrh-DQtUHr3_GHhMlPTP2WAhryzhLHhYVwHHE2Qb-nv2HoaUCsuGkDDeZx8LIy9IIz3EjD9i19re46xw8Ftz4sHDE"),
                fit: BoxFit.cover,
              ),
              border: Border.all(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.backgroundDark : Colors.white,
                  width: 2,
                ),
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, bool isDark,
      {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF111418),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? AppColors.surfaceDark : Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color:
                    isDark ? const Color(0xFF3B4754) : const Color(0xFFDCE0E5),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color:
                    isDark ? const Color(0xFF3B4754) : const Color(0xFFDCE0E5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}
