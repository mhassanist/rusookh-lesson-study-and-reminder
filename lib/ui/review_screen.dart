import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/interleave.dart';
import '../logic/scheduler.dart';
import '../models/models.dart';
import '../state/app_state.dart';

/// A review session. Cards from different lessons are interleaved.
///
/// In normal mode the first answer for each card updates its schedule;
/// forgotten cards come back at the end of the session until recalled.
/// In [cram] mode nothing is recorded — it's free practice.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.cards, this.cram = false});

  final List<StudyCard> cards;
  final bool cram;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final List<StudyCard> _queue = interleave(widget.cards);
  late final int _total = _queue.length;
  final _answered = <String>{};
  final _typed = TextEditingController();
  var _remembered = 0;
  var _forgot = 0;
  var _revealed = false;

  /// Shuffled options for the current card once the learner asks for them.
  List<String>? _options;
  String? _picked;

  bool get _canGrade => _revealed || _picked != null;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  Future<void> _answer(bool remembered) async {
    final card = _queue.removeAt(0);
    final firstAttempt = _answered.add(card.id);
    if (firstAttempt) remembered ? _remembered++ : _forgot++;
    if (!remembered) _queue.add(card);
    _typed.clear();
    setState(() {
      _revealed = false;
      _options = null;
      _picked = null;
    });
    if (!widget.cram && firstAttempt) {
      await context.read<AppState>().recordReview(card, remembered: remembered);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cram ? 'مذاكرة حرة' : 'المراجعة'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: _total == 0 ? 1 : _answered.length / _total),
        ),
      ),
      body: SafeArea(child: _queue.isEmpty ? _summary(context) : _cardView(context, _queue.first)),
    );
  }

  Widget _cardView(BuildContext context, StudyCard card) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final lesson = state.lessonById(card.lessonId);
    final relearning = _answered.contains(card.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 6,
                children: [
                  Chip(label: Text(lesson?.title ?? ''), visualDensity: VisualDensity.compact),
                  Chip(label: Text(card.type.label), visualDensity: VisualDensity.compact),
                  if (relearning)
                    Chip(
                      label: const Text('تاني'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: theme.colorScheme.errorContainer,
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(card.question, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              if (state.typeAnswer && !_revealed)
                TextField(
                  controller: _typed,
                  minLines: 2,
                  maxLines: 6,
                  decoration: const InputDecoration(hintText: 'اكتب اللي فاكره قبل ما تشوف الإجابة'),
                ),
              if (_options != null) ...[
                for (final option in _options!) _choiceTile(context, card, option),
                if (_picked != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      _picked == card.correctOption ? 'إجابة صحيحة ✓' : 'اختيار غلط — الصح متعلّم بالأخضر',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: _picked == card.correctOption ? Colors.green.shade700 : theme.colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
              if (_revealed) ...[
                if (_typed.text.trim().isNotEmpty) ...[
                  Text('إجابتك:', style: theme.textTheme.labelLarge),
                  Text(_typed.text),
                  const SizedBox(height: 16),
                ],
                Card(
                  color: theme.colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(card.answer, style: theme.textTheme.titleMedium),
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_canGrade || !_revealed)
                Row(
                  children: [
                    if (card.hasChoices && _options == null) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                          onPressed: () =>
                              setState(() => _options = [card.correctOption, ...card.wrongOptions]..shuffle()),
                          icon: const Icon(Icons.list),
                          label: const Text('اظهر الاختيارات'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: (_canGrade ? OutlinedButton.new : FilledButton.new)(
                        style: ButtonStyle(minimumSize: WidgetStateProperty.all(const Size.fromHeight(56))),
                        onPressed: () => setState(() => _revealed = true),
                        child: const Text('اظهر الإجابة'),
                      ),
                    ),
                  ],
                ),
              if (_canGrade) ...[
                if (!_revealed) const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        ),
                        onPressed: () => _answer(false),
                        icon: const Icon(Icons.close),
                        label: const Text('نسيت'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                        onPressed: () => _answer(true),
                        icon: const Icon(Icons.check),
                        label: const Text('افتكرت'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _choiceTile(BuildContext context, StudyCard card, String option) {
    final scheme = Theme.of(context).colorScheme;
    final isCorrect = option == card.correctOption;
    final (Color? bg, IconData? icon) = switch (_picked) {
      null => (null, null),
      _ when isCorrect => (Colors.green.withValues(alpha: 0.18), Icons.check_circle),
      final p when p == option => (scheme.errorContainer, Icons.cancel),
      _ => (null, null),
    };
    return Card(
      color: bg,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: ListTile(
        title: Text(option),
        trailing: icon == null ? null : Icon(icon, color: isCorrect ? Colors.green.shade700 : scheme.error),
        onTap: _picked == null ? () => setState(() => _picked = option) : null,
      ),
    );
  }

  Widget _summary(BuildContext context) {
    final theme = Theme.of(context);
    final tomorrow = context.watch<AppState>().forecast(2)[1];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text('خلصت!', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 16),
            Text('افتكرت $_remembered • نسيت $_forgot', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              widget.cram
                  ? 'دي كانت مذاكرة حرة، مواعيد المراجعة متغيرتش.'
                  : _forgot > 0
                  ? 'الأسئلة اللي نسيتها رجعت لأول الدورة (بعد ${Scheduler.intervalDays(0)} يوم). بكرة: $tomorrow سؤال.'
                  : 'كل اللي افتكرته فترته طوّلت. بكرة: $tomorrow سؤال.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('رجوع')),
          ],
        ),
      ),
    );
  }
}
