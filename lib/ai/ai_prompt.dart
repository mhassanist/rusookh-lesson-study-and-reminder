import 'dart:convert';

import '../models/models.dart';

/// Copy/paste bridge to any chat AI (ChatGPT, Claude, Gemini...).
///
/// The learner sends [buildPrompt] plus the lesson to an AI in the browser,
/// copies the reply, and the app imports it with [parseAiResponse]. When an
/// API key is available later, an API-backed generator can reuse both.
const lessonPlaceholder = '[الصق نص الدرس هنا، أو ارفع الملف أو الصور، أو ضع الرابط]';

String buildPrompt() =>
    '''
أنت مساعد دراسي. سأرسل إليك درسًا، وهدفي أن أرسّخه في ذاكرتي فلا أنساه.

اكتب كل المحتوى (العنوان، والنقاط، والأسئلة، والإجابات، والاختيارات) باللغة العربية الفصحى السليمة الواضحة، ولا تستخدم العامية إطلاقًا.

المطلوب:

1) عنوان قصير للدرس.

2) استخلص "اللُّب": لو مُحي الدرس من ذاكرتي وسُمح لي بالاحتفاظ بأهم ما فيه فقط، فماذا سيكون؟
   - ركّز على: المبادئ (principle)، والقواعد (rule)، والتحذيرات (warning)، والخطوات العملية (step).
   - كل نقطة جملة أو جملتان بأسلوب بسيط واضح، لا نسخًا حرفيًا من النص.
   - من 4 إلى 10 نقاط بحسب حجم الدرس.

3) حوّل اللب إلى أسئلة استرجاع:
   - نوّع بين أربعة أنواع:
     • definition: سؤال تعريف ("ما المقصود بـ ...؟")
     • why: سؤال تعليل ("لماذا ...؟ وما السبب؟")
     • application: سؤال تطبيق ("إذا حدث كذا، فماذا أفعل؟")
     • mistake: سؤال الخطأ الشائع ("ما الخطأ الشائع في ...؟")
   - لا يكشف السؤال إجابته.
   - answer: إجابة مكتوبة مختصرة (من سطر إلى ثلاثة أسطر).
   - correct_option: صياغة قصيرة للإجابة الصحيحة تصلح اختيارًا في سؤال اختيار من متعدد.
   - wrong_options: ثلاثة اختيارات خاطئة لكنها معقولة ومقنعة، قريبة من الصحيحة في الطول والأسلوب، حتى لا تُعرف الإجابة من شكلها.
   - سؤال أو سؤالان لكل نقطة، ويجب أن تظهر الأنواع الأربعة كلها.

أجب بصيغة JSON فقط داخل code block واحد، بهذا الشكل تمامًا:
```json
{
  "title": "...",
  "core": [
    {"kind": "principle | rule | warning | step", "text": "..."}
  ],
  "cards": [
    {
      "type": "definition | why | application | mistake",
      "question": "...",
      "answer": "...",
      "correct_option": "...",
      "wrong_options": ["...", "...", "..."]
    }
  ]
}
```
إذا أرسلتُ أكثر من درس دفعة واحدة، فأجب بـ {"lessons": [ ... ]} وكل عنصر بالشكل نفسه أعلاه.

الدرس:
$lessonPlaceholder
''';

class AiLesson {
  AiLesson({required this.title, required this.core, required this.cards});

  String title;
  final List<CorePoint> core;
  final List<CardDraft> cards;
}

/// Tolerant parser: accepts code fences, surrounding chatter, trailing commas,
/// a single lesson object, `{"lessons": [...]}`, or a bare array of lessons.
List<AiLesson> parseAiResponse(String raw) {
  final decoded = _decodeJson(raw);
  final List<Object?> items = switch (decoded) {
    {'lessons': final List list} => list,
    final List list => list,
    final Map map => [map],
    _ => throw const FormatException('شكل الرد مش متوقع.'),
  };
  final lessons = items.whereType<Map>().map(_lesson).where((l) => l.core.isNotEmpty || l.cards.isNotEmpty).toList();
  if (lessons.isEmpty) {
    throw const FormatException('الرد مفيهوش نقاط ولا أسئلة.');
  }
  return lessons;
}

Object? _decodeJson(String raw) {
  final starts = [raw.indexOf('{'), raw.indexOf('[')].where((i) => i >= 0);
  final end = raw.lastIndexOf(RegExp(r'[}\]]'));
  if (starts.isEmpty || end < 0) {
    throw const FormatException('مش لاقي JSON في الرد. اتأكد إنك نسخت الرد كله.');
  }
  final body = raw.substring(starts.reduce((a, b) => a < b ? a : b), end + 1);
  try {
    return jsonDecode(body);
  } on FormatException {
    try {
      return jsonDecode(body.replaceAllMapped(RegExp(r',\s*([}\]])'), (m) => m[1]!));
    } on FormatException {
      throw const FormatException('الـ JSON فيه غلط. اطلب من الـ AI يرد بـ JSON صحيح بس.');
    }
  }
}

AiLesson _lesson(Map m) => AiLesson(
  title: m['title']?.toString().trim() ?? '',
  core: (m['core'] as List? ?? [])
      .whereType<Map>()
      .map((c) => CorePoint.fromJson(Map<String, dynamic>.from(c)))
      .where((c) => c.text.isNotEmpty)
      .toList(),
  cards: (m['cards'] as List? ?? [])
      .whereType<Map>()
      .map(
        (c) => (
          type: QuestionType.parse(c['type']?.toString()),
          question: c['question']?.toString().trim() ?? '',
          answer: c['answer']?.toString().trim() ?? '',
          correctOption: c['correct_option']?.toString().trim() ?? '',
          wrongOptions: (c['wrong_options'] as List? ?? [])
              .map((o) => o.toString().trim())
              .where((o) => o.isNotEmpty)
              .toList(),
        ),
      )
      .where((c) => c.question.isNotEmpty && c.answer.isNotEmpty)
      .toList(),
);
