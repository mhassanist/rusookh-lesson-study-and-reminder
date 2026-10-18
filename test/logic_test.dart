import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rusookh/ai/ai_prompt.dart';
import 'package:rusookh/logic/interleave.dart';
import 'package:rusookh/logic/scheduler.dart';
import 'package:rusookh/models/models.dart';

StudyCard card(String lesson, {DateTime? due}) =>
    StudyCard(lessonId: lesson, type: QuestionType.why, question: 'q', answer: 'a', due: due ?? DateTime(2026, 1, 2));

void main() {
  group('Scheduler', () {
    final now = DateTime(2026, 1, 1, 15, 30);

    test('new card is due the next day', () {
      expect(Scheduler.firstDue(now), DateTime(2026, 1, 2));
    });

    test('remembering climbs the 1/3/7/14/30/90 ladder then doubles', () {
      final c = card('l');
      final waits = <int>[];
      var t = now;
      for (var i = 0; i < 8; i++) {
        Scheduler.apply(c, remembered: true, now: t);
        waits.add(Scheduler.daysBetween(t, c.due));
        t = c.due;
      }
      expect(waits, [3, 7, 14, 30, 90, 180, 360, 720]);
      expect(c.reviews, 8);
    });

    test('forgetting resets to the start of the cycle', () {
      final c = card('l')..step = 4;
      Scheduler.apply(c, remembered: false, now: now);
      expect(c.step, 0);
      expect(c.lapses, 1);
      expect(c.due, DateTime(2026, 1, 2));
    });

    test('due compares calendar days, overdue counts as due', () {
      expect(Scheduler.isDue(card('l', due: DateTime(2026, 1, 1)), now), isTrue);
      expect(Scheduler.isDue(card('l', due: DateTime(2025, 12, 20)), now), isTrue);
      expect(Scheduler.isDue(card('l', due: DateTime(2026, 1, 2)), now), isFalse);
    });
  });

  group('interleave', () {
    test('keeps all cards and avoids same-lesson neighbours when possible', () {
      final cards = [
        for (var i = 0; i < 5; i++) card('a'),
        for (var i = 0; i < 4; i++) card('b'),
        for (var i = 0; i < 3; i++) card('c'),
      ];
      for (var seed = 0; seed < 20; seed++) {
        final out = interleave(cards, random: Random(seed));
        expect(out.toSet(), cards.toSet());
        for (var i = 1; i < out.length; i++) {
          expect(out[i].lessonId, isNot(out[i - 1].lessonId));
        }
      }
    });

    test('single lesson still works', () {
      expect(interleave([card('a'), card('a')]).length, 2);
    });
  });

  group('AI response parsing', () {
    test('handles code fences, chatter and Arabic labels', () {
      const raw = '''
تمام، ده الرد:
```json
{"title": "المراجعة", "core": [{"kind": "warning", "text": "متكتبش ملخص طويل"}, {"kind": "قاعدة", "text": "راجع على فترات"}],
 "cards": [{"type": "why", "question": "لماذا الاسترجاع أفضل؟", "answer": "يقوّي الذاكرة",
            "correct_option": "يقوّي الذاكرة", "wrong_options": ["أسرع", " ", "أسهل"]},
           {"type": "mistake", "question": "", "answer": "ignored"}]}
```
''';
      final r = parseAiResponse(raw).single;
      expect(r.title, 'المراجعة');
      expect(r.core.map((c) => c.kind), [CorePointKind.warning, CorePointKind.rule]);
      expect(r.cards.single.type, QuestionType.why);
      expect(r.cards.single.correctOption, 'يقوّي الذاكرة');
      expect(r.cards.single.wrongOptions, ['أسرع', 'أسهل']);
    });

    test('throws a readable error on garbage', () {
      expect(() => parseAiResponse('no json here'), throwsFormatException);
      expect(() => parseAiResponse('{bad json}'), throwsFormatException);
    });

    test('accepts multiple lessons and trailing commas', () {
      const raw = '''{"lessons": [
        {"title": "أ", "cards": [{"type": "why", "question": "س1", "answer": "ج1"},]},
        {"title": "ب", "core": [{"kind": "step", "text": "خطوة"}]},
      ]}''';
      final r = parseAiResponse(raw);
      expect(r.map((l) => l.title), ['أ', 'ب']);
      expect(parseAiResponse('[{"title": "x", "core": [{"kind": "rule", "text": "t"}]}]').single.title, 'x');
    });

    test('prompt asks for a title and has a lesson placeholder', () {
      expect(buildPrompt(), contains('"title"'));
      expect(buildPrompt(), contains('wrong_options'));
      expect(buildPrompt(), contains('الفصحى'));
      expect(buildPrompt(), contains(lessonPlaceholder));
    });
  });
}
