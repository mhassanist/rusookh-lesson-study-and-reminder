import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/scheduler.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'ai_import_screen.dart';
import 'editors.dart';
import 'lesson_screen.dart';

class LessonsScreen extends StatelessWidget {
  const LessonsScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final result = await showLessonInfoDialog(context);
    if (result == null || !context.mounted) return;
    final lesson = Lesson(title: result.title, source: result.source);
    await context.read<AppState>().saveLesson(lesson);
    if (!context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => LessonScreen(lessonId: lesson.id)));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدروس'),
        actions: [IconButton(tooltip: 'درس يدوي', onPressed: () => _add(context), icon: const Icon(Icons.edit_note))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiImportScreen())),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('درس من الـ AI'),
      ),
      body: state.lessons.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'لسه مفيش دروس.\nخلصت درس؟ ابعته للـ AI بالبرومبت والصق الرد هنا.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: state.lessons.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final lesson = state.lessons[i];
                final cards = state.cardsOf(lesson.id);
                final due = cards.where((c) => Scheduler.isDue(c, now)).length;
                return ListTile(
                  title: Text(lesson.title),
                  subtitle: Text('${lesson.core.length} نقطة لب • ${cards.length} سؤال'),
                  trailing: due > 0
                      ? Badge(label: Text('$due'), child: const Icon(Icons.schedule))
                      : const Icon(Icons.chevron_left),
                  onTap: () =>
                      Navigator.push(context, MaterialPageRoute(builder: (_) => LessonScreen(lessonId: lesson.id))),
                );
              },
            ),
    );
  }
}
