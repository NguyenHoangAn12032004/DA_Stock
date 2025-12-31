import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/course_entity.dart';

// Manual Provider definition to avoid build_runner
final learningControllerProvider = FutureProvider<List<Course>>((ref) async {
  final db = FirebaseFirestore.instance;
  try {
    final snapshot = await db.collection('courses').orderBy('order').get();
    return snapshot.docs.map((doc) => Course.fromJson(doc.id, doc.data())).toList();
  } catch (e) {
    print('Error fetching courses: $e');
    return [];
  }
});
