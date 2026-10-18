import 'dart:convert';
import 'dart:math';

final _rand = Random();

String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36) + _rand.nextInt(1 << 32).toRadixString(36);

/// The kinds of "core" (اللُّب) a lesson boils down to.
enum CorePointKind {
  principle('مبدأ'),
  rule('قاعدة'),
  warning('تحذير'),
  step('خطوة عملية');

  const CorePointKind(this.label);
  final String label;

  static CorePointKind parse(String? value) => CorePointKind.values.firstWhere(
    (k) => k.name == value || k.label == value,
    orElse: () => CorePointKind.principle,
  );
}

/// Question variety: definition, why, application, common mistake.
enum QuestionType {
  definition('تعريف', 'يعني إيه ...؟'),
  why('ليه؟', 'ليه ...؟ وإيه السبب؟'),
  application('تطبيق', 'لو حصل موقف كذا، أعمل إيه؟'),
  mistake('غلط شائع', 'إيه الغلط الشائع في ...؟');

  const QuestionType(this.label, this.template);
  final String label;
  final String template;

  static QuestionType parse(String? value) =>
      QuestionType.values.firstWhere((t) => t.name == value || t.label == value, orElse: () => QuestionType.definition);
}

typedef CardDraft = ({
  QuestionType type,
  String question,
  String answer,
  String correctOption,
  List<String> wrongOptions,
});

class CorePoint {
  CorePoint({required this.kind, required this.text});

  CorePointKind kind;
  String text;

  Map<String, dynamic> toJson() => {'kind': kind.name, 'text': text};

  factory CorePoint.fromJson(Map<String, dynamic> json) =>
      CorePoint(kind: CorePointKind.parse(json['kind'] as String?), text: (json['text'] as String?)?.trim() ?? '');
}

class Lesson {
  Lesson({
    String? id,
    required this.title,
    this.source = '',
    this.notes = '',
    List<CorePoint>? core,
    DateTime? createdAt,
  }) : id = id ?? newId(),
       core = core ?? [],
       createdAt = createdAt ?? DateTime.now();

  final String id;
  String title;
  String source;
  String notes;
  List<CorePoint> core;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'source': source,
    'notes': notes,
    'core': core.map((c) => c.toJson()).toList(),
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
    id: json['id'] as String,
    title: json['title'] as String,
    source: json['source'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    core: (json['core'] as List? ?? []).map((e) => CorePoint.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
  );

  String encodeCore() => jsonEncode(core.map((c) => c.toJson()).toList());
}

class StudyCard {
  StudyCard({
    String? id,
    required this.lessonId,
    required this.type,
    required this.question,
    required this.answer,
    this.correctOption = '',
    this.wrongOptions = const [],
    this.step = 0,
    required this.due,
    this.lastReviewed,
    this.reviews = 0,
    this.lapses = 0,
    DateTime? createdAt,
  }) : id = id ?? newId(),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String lessonId;
  QuestionType type;
  String question;
  String answer;

  /// Multiple-choice: a short correct option plus distractors. Shuffled when
  /// shown. Empty for cards without choices.
  String correctOption;
  List<String> wrongOptions;

  bool get hasChoices => correctOption.isNotEmpty && wrongOptions.isNotEmpty;

  CardDraft get draft =>
      (type: type, question: question, answer: answer, correctOption: correctOption, wrongOptions: wrongOptions);

  void applyDraft(CardDraft d) {
    type = d.type;
    question = d.question;
    answer = d.answer;
    correctOption = d.correctOption;
    wrongOptions = d.wrongOptions;
  }

  /// Index into the spaced-repetition ladder (see `Scheduler`).
  int step;

  /// Local calendar day on which the card becomes due.
  DateTime due;
  DateTime? lastReviewed;
  int reviews;
  int lapses;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'lessonId': lessonId,
    'type': type.name,
    'question': question,
    'answer': answer,
    'correctOption': correctOption,
    'wrongOptions': wrongOptions,
    'step': step,
    'due': due.millisecondsSinceEpoch,
    'lastReviewed': lastReviewed?.millisecondsSinceEpoch,
    'reviews': reviews,
    'lapses': lapses,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory StudyCard.fromJson(Map<String, dynamic> json) => StudyCard(
    id: json['id'] as String,
    lessonId: json['lessonId'] as String,
    type: QuestionType.parse(json['type'] as String?),
    question: json['question'] as String,
    answer: json['answer'] as String,
    correctOption: json['correctOption'] as String? ?? '',
    wrongOptions: (json['wrongOptions'] as List? ?? []).map((e) => e.toString()).toList(),
    step: json['step'] as int? ?? 0,
    due: DateTime.fromMillisecondsSinceEpoch(json['due'] as int),
    lastReviewed: json['lastReviewed'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(json['lastReviewed'] as int),
    reviews: json['reviews'] as int? ?? 0,
    lapses: json['lapses'] as int? ?? 0,
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
  );
}

class ReviewLog {
  ReviewLog({required this.cardId, required this.at, required this.remembered});

  final String cardId;
  final DateTime at;
  final bool remembered;

  Map<String, dynamic> toJson() => {'cardId': cardId, 'at': at.millisecondsSinceEpoch, 'remembered': remembered};

  factory ReviewLog.fromJson(Map<String, dynamic> json) => ReviewLog(
    cardId: json['cardId'] as String,
    at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
    remembered: json['remembered'] as bool,
  );
}
