import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../domain/entities/course_entity.dart';
import '../theme/app_colors.dart';

class LessonPlayerScreen extends StatefulWidget {
  final Lesson lesson;

  const LessonPlayerScreen({super.key, required this.lesson});

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    // Extract ID from URL
    final videoId = YoutubePlayer.convertUrlToId(widget.lesson.videoUrl) ?? '';
    
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111418) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white), 
        // Transparent app bar on top of video? No, standard app bar.
      ),
      extendBodyBehindAppBar: true, 
      body: Center(
        child: _controller.initialVideoId.isEmpty
            ? const Text("Lỗi Video Link", style: TextStyle(color: Colors.red))
            : YoutubePlayer(
                controller: _controller,
                showVideoProgressIndicator: true,
                progressIndicatorColor: AppColors.primary,
                onReady: () {
                   print('Player is ready.');
                },
              ),
      ),
    );
  }
}
