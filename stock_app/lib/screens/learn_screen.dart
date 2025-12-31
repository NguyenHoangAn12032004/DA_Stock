import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../presentation/providers/learning_provider.dart';
import '../domain/entities/course_entity.dart';
import 'lesson_player_screen.dart'; // Import Player
// import 'package:url_launcher/url_launcher.dart'; // Removed as we use embedded player

class LearningScreen extends ConsumerStatefulWidget {
  const LearningScreen({super.key});

  @override
  ConsumerState<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends ConsumerState<LearningScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;



  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111418) : const Color(0xFFF6F7F8);
    final cardColor = isDark ? const Color(0xFF1A2633) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111418);

    final coursesAsync = ref.watch(learningControllerProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        title: Text(
          'Stock Academy 🎓',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Nhập Môn'),
            Tab(text: 'Phổ Thông'),
            Tab(text: 'Chuyên Gia'),
          ],
        ),
      ),
      body: coursesAsync.when(
        data: (courses) {
          if (courses.isEmpty) {
            return const Center(child: Text("Đang cập nhật bài học..."));
          }
           // Map course level to Tab Index? Or just list them? 
           // Our tabs are hardcoded for 3 levels.
           // Filter for each tab:
           final beginner = courses.firstWhere((c) => c.level == 'Beginner', orElse: () => Course(id: '', title: 'N/A', level: 'Beginner', description: '', lessons: []));
           final intermediate = courses.firstWhere((c) => c.level == 'Intermediate', orElse: () => Course(id: '', title: 'N/A', level: 'Intermediate', description: '', lessons: []));
           final advanced = courses.firstWhere((c) => c.level == 'Advanced', orElse: () => Course(id: '', title: 'N/A', level: 'Advanced', description: '', lessons: []));
           
          return TabBarView(
            controller: _tabController,
            children: [
               _buildModuleContent(beginner, isDark, cardColor, textColor),
               _buildModuleContent(intermediate, isDark, cardColor, textColor),
               _buildModuleContent(advanced, isDark, cardColor, textColor),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Lỗi: $err')),
      ),
    );
  }

  Widget _buildModuleContent(Course module, bool isDark, Color cardColor, Color textColor) {
    if (module.id.isEmpty) {
       return Center(child: Text('Chưa có nội dung', style: TextStyle(color: textColor)));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                module.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                module.description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: 0.1, // TODO: Real progress
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                '10% Hoàn thành',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Danh sách bài học',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...module.lessons.map((lesson) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF3B4754) : const Color(0xFFDCE0E5),
              ),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: lesson.isCompleted 
                      ? AppColors.success.withOpacity(0.1) 
                      : Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  lesson.isCompleted ? Icons.check : Icons.play_arrow,
                  color: lesson.isCompleted ? AppColors.success : AppColors.primary,
                  size: 20,
                ),
              ),
              title: Text(
                lesson.title,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                lesson.duration,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              trailing: Icon(
                Icons.open_in_new, // Indicate external link/player
                color: isDark ? Colors.grey : Colors.grey[400],
              ),
              onTap: () {
                // Navigate to In-App Player
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LessonPlayerScreen(lesson: lesson),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ],
    );
  }
}
