import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../domain/entities/course_entity.dart';

class AdminCourseScreen extends StatefulWidget {
  const AdminCourseScreen({super.key});

  @override
  State<AdminCourseScreen> createState() => _AdminCourseScreenState();
}

class _AdminCourseScreenState extends State<AdminCourseScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111418) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("CMS: Course Manager"),
        backgroundColor: bgColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('courses').orderBy('order').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("No courses found. Seed them first!"));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final course = Course.fromJson(docs[index].id, docs[index].data() as Map<String, dynamic>);
              return _buildCourseCard(course, textColor);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCourseDialog(context, null),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCourseCard(Course course, Color textColor) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        shape: const Border(), // Remove default border
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40, height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)
          ),
          child: Text("${course.order}", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
        ),
        title: Text(course.title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getLevelColor(course.level).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4)
                ),
                child: Text(course.level, style: TextStyle(color: _getLevelColor(course.level), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Icon(Icons.video_library, size: 14, color: textColor.withOpacity(0.5)),
              const SizedBox(width: 4),
              Text("${course.lessons.length} lessons", style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12)),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue), onPressed: () => _showCourseDialog(context, course)),
            IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: () => _deleteCourse(course.id)),
          ],
        ),
        children: [
          Container(
             decoration: BoxDecoration(
               color: AppColors.primary.withOpacity(0.02),
               border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1)))
             ),
             child: Column(
               children: [
                 if (course.lessons.isEmpty)
                   Padding(
                     padding: const EdgeInsets.all(16.0),
                     child: Text("No lessons yet. Add one!", style: TextStyle(color: textColor.withOpacity(0.5), fontStyle: FontStyle.italic)),
                   ),
                 ...course.lessons.map((lesson) => _buildLessonItem(lesson, course, textColor)).toList(),
                 
                 // Add Lesson Button
                 InkWell(
                   onTap: () => _showLessonDialog(context, course, null),
                   child: Container(
                     width: double.infinity,
                     padding: const EdgeInsets.symmetric(vertical: 12),
                     alignment: Alignment.center,
                     /* decoration: BoxDecoration(
                       border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1)))
                     ), */
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         const Icon(Icons.add_circle_outline, size: 18, color: AppColors.primary),
                         const SizedBox(width: 8),
                         Text("Add New Lesson", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                       ],
                     ),
                   ),
                 )
               ],
             ),
          )
        ],
      ),
    );
  }

  Widget _buildLessonItem(Lesson lesson, Course course, Color textColor) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      leading: Text("${lesson.order}", style: TextStyle(color: textColor.withOpacity(0.5), fontWeight: FontWeight.bold)),
      title: Text(lesson.title, style: TextStyle(color: textColor, fontSize: 14)),
      subtitle: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          Text(lesson.duration, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.edit_note, size: 18, color: Colors.grey),
        onPressed: () => _showLessonDialog(context, course, lesson),
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'beginner': return Colors.green;
      case 'intermediate': return Colors.orange;
      case 'advanced': return Colors.red;
      default: return Colors.blue;
    }
  }

  // --- CRUD LOGIC ---

  Future<void> _deleteCourse(String id) async {
    final confirm = await showDialog(
      context: context, 
      builder: (_) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Delete this course and all its lessons?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      )
    );
    
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('courses').doc(id).delete();
    }
  }

  void _showCourseDialog(BuildContext context, Course? course) {
    final titleCtrl = TextEditingController(text: course?.title);
    final descCtrl = TextEditingController(text: course?.description);
    final levelCtrl = TextEditingController(text: course?.level ?? 'Beginner');
    final orderCtrl = TextEditingController(text: course?.order.toString() ?? '1');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(course == null ? "Add Course" : "Edit Course"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Title")),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Description")),
              TextField(controller: levelCtrl, decoration: const InputDecoration(labelText: "Level (Beginner, Intermediate...)")),
              TextField(controller: orderCtrl, decoration: const InputDecoration(labelText: "Order"), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Map<String, dynamic> data = {
                'title': titleCtrl.text,
                'description': descCtrl.text,
                'level': levelCtrl.text,
                'order': int.tryParse(orderCtrl.text) ?? 1,
                // Preserve lessons if editing
                'lessons': course?.lessons.map((l) => {
                  'id': l.id,
                  'title': l.title,
                  'duration': l.duration,
                  'video_url': l.videoUrl,
                  'order': l.order,
                }).toList() ?? []
              };
              
              final collection = FirebaseFirestore.instance.collection('courses');
              if (course == null) {
                // Use level as ID (simple slug) or auto-id
                String id = levelCtrl.text.toLowerCase();
                 await collection.doc(id).set(data);
              } else {
                 await collection.doc(course.id).update(data);
              }
              Navigator.pop(context);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  void _showLessonDialog(BuildContext context, Course course, Lesson? lesson) {
    final titleCtrl = TextEditingController(text: lesson?.title);
    final videoCtrl = TextEditingController(text: lesson?.videoUrl);
    final durationCtrl = TextEditingController(text: lesson?.duration ?? "10:00");
    final orderCtrl = TextEditingController(text: lesson?.order.toString() ?? '${course.lessons.length + 1}');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lesson == null ? "Add Lesson" : "Edit Lesson"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Title")),
              TextField(controller: videoCtrl, decoration: const InputDecoration(labelText: "YouTube URL")),
              TextField(controller: durationCtrl, decoration: const InputDecoration(labelText: "Duration (mm:ss)")),
              TextField(controller: orderCtrl, decoration: const InputDecoration(labelText: "Order"), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          if (lesson != null)
             TextButton(onPressed: () async {
               // Delete Lesson Logic (Filter out)
               // This is tricky with Firestore Array.
               // Best way: Read, Filter, Update.
               final newLessons = course.lessons.where((l) => l.id != lesson.id).map((l) => {
                   'id': l.id, 'title': l.title, 'duration': l.duration, 'video_url': l.videoUrl, 'order': l.order
               }).toList();
               
               await FirebaseFirestore.instance.collection('courses').doc(course.id).update({'lessons': newLessons});
               Navigator.pop(context);
             }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Map<String, dynamic> lessonData = {
                'id': lesson?.id ?? 'l_${DateTime.now().millisecondsSinceEpoch}',
                'title': titleCtrl.text,
                'video_url': videoCtrl.text,
                'duration': durationCtrl.text,
                'order': int.tryParse(orderCtrl.text) ?? 1,
              };

              List<Map<String, dynamic>> updatedLessons = course.lessons.map((l) => {
                  'id': l.id, 'title': l.title, 'duration': l.duration, 'video_url': l.videoUrl, 'order': l.order
              }).toList();

              if (lesson == null) {
                updatedLessons.add(lessonData);
              } else {
                final index = updatedLessons.indexWhere((l) => l['id'] == lesson.id);
                if (index != -1) updatedLessons[index] = lessonData;
              }
              
              // Sort by order
              updatedLessons.sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));

              await FirebaseFirestore.instance.collection('courses').doc(course.id).update({'lessons': updatedLessons});
              Navigator.pop(context);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }
}
