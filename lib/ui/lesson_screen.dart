import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../logic/scheduler.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'ai_import_screen.dart';
import 'editors.dart';
import 'review_screen.dart';

class LessonScreen extends StatelessWidget {
  const LessonScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lesson = state.lessonById(lessonId);
    if (lesson == null) return const Scaffold(body: SizedBox.shrink());
    final cards = state.cardsOf(lessonId);

    return Scaffold(
      appBar: AppBar(
        title: Text(lesson.title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'edit' ? _editInfo(context, lesson) : _delete(context, lesson),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('تعديل العنوان')),
              PopupMenuItem(value: 'delete', child: Text('حذف الدرس')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (lesson.source.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('المصدر: ${lesson.source}', style: Theme.of(context).textTheme.bodySmall),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AiImportScreen(targetLessonId: lessonId)),
                  ),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('ضيف من الـ AI'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: cards.isEmpty
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ReviewScreen(cards: cards, cram: true)),
                        ),
                  icon: const Icon(Icons.school),
                  label: const Text('ذاكر دلوقتي'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _CoreSection(lesson: lesson),
          const SizedBox(height: 16),
          _CardsSection(lesson: lesson, cards: cards),
        ],
      ),
    );
  }

  Future<void> _editInfo(BuildContext context, Lesson lesson) async {
    final result = await showLessonInfoDialog(context, lesson: lesson);
    if (result == null || !context.mounted) return;
    lesson
      ..title = result.title
      ..source = result.source;
    await context.read<AppState>().saveLesson(lesson);
  }

  Future<void> _delete(BuildContext context, Lesson lesson) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الدرس؟'),
        content: const Text('هيتحذف الدرس وكل أسئلته ومش هتقدر ترجعهم.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    Navigator.pop(context);
    await context.read<AppState>().deleteLesson(lesson);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.hint, required this.onAdd});
  final String title;
  final String hint;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
            IconButton.filledTonal(onPressed: onAdd, icon: const Icon(Icons.add)),
          ],
        ),
        Text(hint, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _CoreSection extends StatelessWidget {
  const _CoreSection({required this.lesson});
  final Lesson lesson;

  Future<void> _edit(BuildContext context, [int? index]) async {
    final point = await showCorePointDialog(context, point: index == null ? null : lesson.core[index]);
    if (point == null || !context.mounted) return;
    if (index == null) {
      lesson.core.add(point);
    } else {
      lesson.core[index] = point;
    }
    await context.read<AppState>().saveLesson(lesson);
  }

  Future<void> _toQuestion(BuildContext context, CorePoint point) async {
    final draft = await Navigator.push<CardDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => CardEditorScreen(
          hint: '${point.kind.label}: ${point.text}\n\nحوّلها لسؤال يجبرك تسترجعها.',
          initial: (
            type: QuestionType.why,
            question: '',
            answer: point.text,
            correctOption: '',
            wrongOptions: const [],
          ),
        ),
      ),
    );
    if (draft == null || !context.mounted) return;
    final state = context.read<AppState>();
    await state.saveCards([state.newCard(lesson.id, draft)]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'اللُّب',
          hint: 'لو الدرس اتمسح من دماغك ومسموحلك تحتفظ بأهم الحاجات بس، هيبقوا إيه؟ اكتبهم بأسلوبك.',
          onAdd: () => _edit(context),
        ),
        if (lesson.core.isEmpty) const Card(child: ListTile(title: Text('مفيش نقاط لسه'))),
        for (var i = 0; i < lesson.core.length; i++)
          Card(
            child: ListTile(
              leading: _KindChip(lesson.core[i].kind),
              title: Text(lesson.core[i].text),
              onTap: () => _edit(context, i),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'q') {
                    await _toQuestion(context, lesson.core[i]);
                  } else {
                    lesson.core.removeAt(i);
                    await context.read<AppState>().saveLesson(lesson);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'q', child: Text('حوّلها لسؤال')),
                  PopupMenuItem(value: 'del', child: Text('حذف')),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip(this.kind);
  final CorePointKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (kind) {
      CorePointKind.principle => scheme.primary,
      CorePointKind.rule => scheme.tertiary,
      CorePointKind.warning => scheme.error,
      CorePointKind.step => scheme.secondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(kind.label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

class _CardsSection extends StatelessWidget {
  const _CardsSection({required this.lesson, required this.cards});
  final Lesson lesson;
  final List<StudyCard> cards;

  Future<void> _edit(BuildContext context, [StudyCard? card]) async {
    final draft = await Navigator.push<CardDraft>(
      context,
      MaterialPageRoute(builder: (_) => CardEditorScreen(initial: card?.draft)),
    );
    if (draft == null || !context.mounted) return;
    final state = context.read<AppState>();
    if (card == null) {
      await state.saveCards([state.newCard(lesson.id, draft)]);
    } else {
      card.applyDraft(draft);
      await state.saveCards([card]);
    }
  }

  String _dueLabel(StudyCard card) {
    final now = DateTime.now();
    if (Scheduler.isDue(card, now)) return 'عليه الدور';
    final days = Scheduler.daysBetween(now, card.due);
    if (days == 1) return 'بكرة';
    return DateFormat('d MMM', 'ar').format(card.due);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missing = QuestionType.values.where((t) => !cards.any((c) => c.type == t)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'الأسئلة',
          hint: 'الاسترجاع هو اللي بيقوّي الذاكرة، مش إعادة القراية. نوّع: تعريف، ليه، تطبيق، غلط شائع.',
          onAdd: () => _edit(context),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in QuestionType.values)
              Chip(
                label: Text('${t.label}: ${cards.where((c) => c.type == t).length}'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        if (cards.isNotEmpty && missing.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'ناقصك أسئلة من نوع: ${missing.map((t) => t.label).join('، ')}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 8),
        if (cards.isEmpty) const Card(child: ListTile(title: Text('مفيش أسئلة لسه'))),
        for (final card in cards)
          Card(
            child: ListTile(
              title: Text(card.question),
              subtitle: Text('${card.type.label} • ${_dueLabel(card)} • مرحلة ${card.step + 1}'),
              onTap: () => _edit(context, card),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => context.read<AppState>().deleteCard(card),
              ),
            ),
          ),
      ],
    );
  }
}
