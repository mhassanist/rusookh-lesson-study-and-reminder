import 'package:flutter/material.dart';

import '../models/models.dart';

Future<({String title, String source})?> showLessonInfoDialog(BuildContext context, {Lesson? lesson}) {
  final title = TextEditingController(text: lesson?.title);
  final source = TextEditingController(text: lesson?.source);
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(lesson == null ? 'درس جديد' : 'تعديل الدرس'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: title,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'عنوان الدرس'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: source,
            decoration: const InputDecoration(labelText: 'المصدر (اختياري)', hintText: 'كتاب، كورس، فصل...'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            if (title.text.trim().isEmpty) return;
            Navigator.pop(context, (title: title.text.trim(), source: source.text.trim()));
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
}

Future<CorePoint?> showCorePointDialog(BuildContext context, {CorePoint? point}) {
  var kind = point?.kind ?? CorePointKind.principle;
  final text = TextEditingController(text: point?.text);
  return showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('نقطة من اللب'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                children: [
                  for (final k in CorePointKind.values)
                    ChoiceChip(label: Text(k.label), selected: kind == k, onSelected: (_) => setState(() => kind = k)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: text,
                autofocus: true,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(hintText: 'اكتبها بأسلوبك إنت، مش نسخ من الكتاب'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (text.text.trim().isEmpty) return;
              Navigator.pop(context, CorePoint(kind: kind, text: text.text.trim()));
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
}

/// Full-screen editor for a question card.
class CardEditorScreen extends StatefulWidget {
  const CardEditorScreen({super.key, this.initial, this.hint});

  final CardDraft? initial;

  /// Shown above the fields, e.g. the core point being converted.
  final String? hint;

  @override
  State<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
  late QuestionType _type = widget.initial?.type ?? QuestionType.definition;
  late final _question = TextEditingController(text: widget.initial?.question);
  late final _answer = TextEditingController(text: widget.initial?.answer);
  late final _correct = TextEditingController(text: widget.initial?.correctOption);
  late final _wrong = List.generate(
    3,
    (i) => TextEditingController(text: (widget.initial?.wrongOptions ?? const []).elementAtOrNull(i)),
  );

  @override
  void dispose() {
    for (final c in [_question, _answer, _correct, ..._wrong]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (_question.text.trim().isEmpty || _answer.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب السؤال والإجابة')));
      return;
    }
    final wrong = _wrong.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    final correct = _correct.text.trim();
    if (correct.isEmpty != wrong.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('للاختيارات: اكتب الاختيار الصح واختيار غلط واحد على الأقل')));
      return;
    }
    Navigator.pop<CardDraft>(context, (
      type: _type,
      question: _question.text.trim(),
      answer: _answer.text.trim(),
      correctOption: correct,
      wrongOptions: wrong,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'سؤال جديد' : 'تعديل السؤال'),
        actions: [TextButton(onPressed: _save, child: const Text('حفظ'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.hint != null)
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: Padding(padding: const EdgeInsets.all(12), child: Text(widget.hint!)),
            ),
          const SizedBox(height: 8),
          Text('نوع السؤال', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final t in QuestionType.values)
                ChoiceChip(label: Text(t.label), selected: _type == t, onSelected: (_) => setState(() => _type = t)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _question,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(labelText: 'السؤال', hintText: _type.template),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _answer,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(labelText: 'الإجابة (ضهر الورقة)'),
          ),
          const SizedBox(height: 24),
          Text('الاختيارات (اختياري)', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _correct,
            decoration: const InputDecoration(labelText: 'الاختيار الصح', prefixIcon: Icon(Icons.check)),
          ),
          for (var i = 0; i < _wrong.length; i++) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _wrong[i],
              decoration: InputDecoration(labelText: 'اختيار غلط ${i + 1}', prefixIcon: const Icon(Icons.close)),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'السؤال الكويس ما يكشفش إجابته. اسأل عن السبب أو الموقف، مش بس التعريف.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
