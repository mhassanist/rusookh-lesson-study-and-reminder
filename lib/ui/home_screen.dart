import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'ai_import_screen.dart';
import 'review_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final due = state.dueCards();
    final forecast = state.forecast(7);
    final theme = Theme.of(context);
    final retention = state.retention;

    return Scaffold(
      appBar: AppBar(title: const Text('رسوخ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('مراجعة النهارده', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    due.isEmpty ? 'مفيش حاجة عليها الدور 🎉' : '${due.length} سؤال',
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    due.isEmpty
                        ? (state.cards.isEmpty
                              ? 'ضيف أول درس من الـ AI وابدأ.'
                              : 'بكرة: ${forecast[1]} سؤال. ممكن تذاكر حر من صفحة أي درس.')
                        : 'مخلوطة من ${due.map((c) => c.lessonId).toSet().length} درس — حاول تفتكر قبل ما تشوف الإجابة.',
                  ),
                  if (due.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () =>
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewScreen(cards: due))),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('ابدأ المراجعة'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiImportScreen())),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('خلصت درس؟ ضيفه من الـ AI'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(label: 'أيام متتالية', value: '${state.streak} 🔥'),
              _Stat(label: 'نسبة التذكر (٣٠ يوم)', value: retention == null ? '—' : '${(retention * 100).round()}%'),
            ],
          ),
          Row(
            children: [
              _Stat(label: 'الدروس', value: '${state.lessons.length}'),
              _Stat(label: 'الأسئلة', value: '${state.cards.length}'),
              _Stat(label: 'رسخت', value: '${state.masteredCount}'),
            ],
          ),
          const SizedBox(height: 12),
          if (state.cards.isNotEmpty) _Forecast(counts: forecast),
          const SizedBox(height: 12),
          const _MethodCard(),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(label, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _Forecast extends StatelessWidget {
  const _Forecast({required this.counts});
  final List<int> counts;

  static const _names = ['النهارده', 'بكرة'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = counts.fold(1, (a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الأيام الجاية', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            for (var i = 0; i < counts.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(width: 72, child: Text(i < 2 ? _names[i] : 'بعد $i أيام')),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: counts[i] / max, minHeight: 10),
                      ),
                    ),
                    SizedBox(width: 36, child: Text('${counts[i]}', textAlign: TextAlign.end)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ExpansionTile(
        leading: Icon(Icons.lightbulb_outline),
        title: Text('الطريقة'),
        childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '١. أول ما تخلص الدرس: استخلص اللُّب — المبادئ، القواعد، التحذيرات، والخطوات العملية. بأسلوبك إنت.\n\n'
            '٢. حوّل اللب لأسئلة، مش كلام تقراه. نوّع: تعريف، ليه، تطبيق، غلط شائع.\n\n'
            '٣. راجع على فترات متباعدة: يوم، ٣ أيام، أسبوع، أسبوعين، شهر، ٣ شهور. لو نسيت، السؤال يرجع لأول الدورة.\n\n'
            '٤. المراجعة بتخلط أسئلة من دروس مختلفة، عشان دماغك تتعلم تفرّق وتطلّع المعلومة الصح.',
          ),
        ],
      ),
    );
  }
}
