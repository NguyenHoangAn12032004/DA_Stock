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
    return Card(
      color: Colors.grey.withOpacity(0.1),
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        title: Text(course.title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        subtitle: Text(course.level, style: TextStyle(color: AppColors.primary)),
        leading: CircleAvatar(child: Text("${course.order}")),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showCourseDialog(context, course)),
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteCourse(course.id)),
             const Icon(Icons.expand_more),
          ],
        ),
        children: [
          // Lessons List
          ...course.lessons.map((lesson) => ListTile(
            contentPadding: const EdgeInsets.only(left: 32, right: 16),
            leading: const Icon(Icons.play_circle_outline, color: Colors.grey),
            title: Text(lesson.title, style: TextStyle(color: textColor)),
            subtitle: Text(lesson.duration, style: TextStyle(color: Colors.grey)),
            trailing: IconButton(
              icon: const Icon(Icons.edit_note),
              onPressed: () => _showLessonDialog(context, course, lesson),
            ),
          )),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("Add Lesson"),
              onPressed: () => _showLessonDialog(context, course, null),
            ),
          )
        ],
      ),
    );
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
