import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../ai/ai_prompt.dart';
import '../state/app_state.dart';
import 'review_screen.dart';

/// Copy the prompt → send it with the lesson to any AI in the browser → copy
/// the reply → come back. The reply is picked up from the clipboard
/// automatically and saved with one tap.
class AiImportScreen extends StatefulWidget {
  const AiImportScreen({super.key, this.targetLessonId});

  /// When set, everything is added to this lesson instead of new ones.
  final String? targetLessonId;

  @override
  State<AiImportScreen> createState() => _AiImportScreenState();
}

class _AiImportScreenState extends State<AiImportScreen> with WidgetsBindingObserver {
  final _manual = TextEditingController();
  List<AiLesson>? _lessons;
  String? _error;
  String? _promptText;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _promptText = buildPrompt();
    _checkClipboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _manual.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _lessons == null) _checkClipboard();
  }

  /// Silently tries the clipboard; only surfaces errors on explicit paste.
  Future<void> _checkClipboard({bool explicit = false}) async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    if (!mounted || text == _promptText) return;
    if (text.trim().isEmpty) {
      if (explicit) setState(() => _error = 'الحافظة فاضية. انسخ رد الـ AI الأول.');
      return;
    }
    _parse(text, showError: explicit);
  }

  void _parse(String text, {bool showError = true}) {
    try {
      final lessons = parseAiResponse(text);
      final known = context.read<AppState>().cards.map((c) => c.question).toSet();
      final alreadyImported = lessons.every((l) => l.cards.every((c) => known.contains(c.question)));
      if (alreadyImported) {
        if (showError) setState(() => _error = 'الرد ده اتحفظ قبل كده.');
        return;
      }
      setState(() {
        _lessons = lessons;
        _error = null;
      });
    } on FormatException catch (e) {
      if (showError) setState(() => _error = e.message);
    }
  }

  Future<void> _copyPrompt() async {
    await Clipboard.setData(ClipboardData(text: _promptText!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('اتنسخ! الصقه في ChatGPT أو Claude أو Gemini مع الدرس، وانسخ الرد وارجع هنا.'),
        duration: Duration(seconds: 5),
      ),
    );
  }

  Future<void> _save({required bool studyNow}) async {
    setState(() => _saving = true);
    final state = context.read<AppState>();
    final added = await state.importLessons(_lessons!, targetLessonId: widget.targetLessonId);
    if (!mounted) return;
    final navigator = Navigator.of(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('اتحفظ ${added.length} سؤال. أول مراجعة ليهم بكرة.')));
    if (studyNow && added.isNotEmpty) {
      navigator.pushReplacement(MaterialPageRoute(builder: (_) => ReviewScreen(cards: added, cram: true)));
    } else {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('درس من الـ AI'),
        actions: [
          if (_lessons != null)
            IconButton(
              tooltip: 'ابدأ من الأول',
              onPressed: () => setState(() => _lessons = null),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _lessons == null ? _instructions(context) : _preview(context, _lessons!),
    );
  }

  Widget _instructions(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Step(
          number: '١',
          title: 'انسخ البرومبت',
          body: 'مرة واحدة بس — بعد كده هتلاقيه في الشات عندك.',
          action: FilledButton.icon(
            onPressed: _copyPrompt,
            icon: const Icon(Icons.copy),
            label: const Text('انسخ البرومبت'),
          ),
        ),
        const _Step(
          number: '٢',
          title: 'ابعته للـ AI مع الدرس',
          body: 'في ChatGPT أو Claude أو Gemini: الصق البرومبت، وحط الدرس (نص، ملف، صور، أو لينك).',
        ),
        _Step(
          number: '٣',
          title: 'انسخ الرد وارجع هنا',
          body: 'دوس "Copy" على الرد أو الـ code block. التطبيق هيلقطه لوحده أول ما ترجع.',
          action: OutlinedButton.icon(
            onPressed: () => _checkClipboard(explicit: true),
            icon: const Icon(Icons.content_paste),
            label: const Text('الصق الرد'),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ),
        const SizedBox(height: 8),
        ExpansionTile(
          title: const Text('أو الصقه يدوي'),
          tilePadding: EdgeInsets.zero,
          children: [
            TextField(
              controller: _manual,
              minLines: 3,
              maxLines: 8,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(hintText: '{ "title": ..., "core": [...], "cards": [...] }'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonal(onPressed: () => _parse(_manual.text), child: const Text('حلّل')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _preview(BuildContext context, List<AiLesson> lessons) {
    final theme = Theme.of(context);
    final target = widget.targetLessonId == null ? null : context.read<AppState>().lessonById(widget.targetLessonId!);
    final totalCards = lessons.fold(0, (n, l) => n + l.cards.length);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (target != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('هيتضاف لدرس: ${target.title}', style: theme.textTheme.titleSmall),
                ),
              for (final lesson in lessons) _LessonPreview(lesson: lesson, editableTitle: target == null),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _saving ? null : () => _save(studyNow: true),
                    child: const Text('احفظ وذاكر دلوقتي'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _saving ? null : () => _save(studyNow: false),
                    icon: const Icon(Icons.check),
                    label: Text('احفظ ($totalCards سؤال)'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.body, this.action});
  final String number;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 14, child: Text(number)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(body, style: theme.textTheme.bodyMedium),
                  if (action != null) ...[const SizedBox(height: 12), action!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonPreview extends StatelessWidget {
  const _LessonPreview({required this.lesson, required this.editableTitle});
  final AiLesson lesson;
  final bool editableTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (editableTitle)
              TextFormField(
                initialValue: lesson.title,
                decoration: const InputDecoration(labelText: 'عنوان الدرس'),
                onChanged: (v) => lesson.title = v,
              ),
            const SizedBox(height: 8),
            Text('${lesson.core.length} نقطة لب • ${lesson.cards.length} سؤال', style: theme.textTheme.bodySmall),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('اللُّب'),
              children: [
                for (final c in lesson.core) ListTile(dense: true, leading: Text(c.kind.label), title: Text(c.text)),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('الأسئلة'),
              children: [
                for (final c in lesson.cards)
                  ListTile(dense: true, title: Text(c.question), subtitle: Text('${c.type.label} — ${c.answer}')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
