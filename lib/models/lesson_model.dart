// ✅ FIX : Ajout d'un enum ExerciseType pour distinguer clairement les 3 modes
//          d'exercice au lieu de deviner via les champs remplis.
enum ExerciseType {
  numericBlanks, // Maths à trous : [?] → champ numérique
  textQcm, // Français QCM  : options textuelles
  singleInput, // Trou unique texte libre
}

class LessonModel {
  final String titre;
  final String? succes;
  final List<FlashcardModel> astuces;
  final List<ExerciseModel> exercices;
  final List<QuizModel> quiz;

  const LessonModel({
    required this.titre,
    this.succes,
    required this.astuces,
    required this.exercices,
    required this.quiz,
  });

  Map<String, dynamic> toJson() => {
    'titre': titre,
    if (succes != null && succes!.trim().isNotEmpty) 'succes': succes!.trim(),
    'astuces': astuces.map((a) => a.toJson()).toList(),
    'exercices': exercices.map((e) => e.toJson()).toList(),
    'quiz': quiz.map((q) => q.toJson()).toList(),
  };

  factory LessonModel.fromJson(Map<String, dynamic> json) {
    final rawSucces = json['succes'];
    final succes = (rawSucces is String && rawSucces.trim().isNotEmpty)
        ? rawSucces.trim()
        : null;
    return LessonModel(
      titre: json['titre'] as String,
      succes: succes,
      astuces: (json['astuces'] as List)
          .map((a) => FlashcardModel.fromJson(a as Map<String, dynamic>))
          .toList(),
      exercices: (json['exercices'] as List)
          .map((e) => ExerciseModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      quiz: (json['quiz'] as List)
          .map((q) => QuizModel.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FlashcardModel {
  final String question;
  final String reponse;

  const FlashcardModel({required this.question, required this.reponse});

  Map<String, dynamic> toJson() => {'question': question, 'reponse': reponse};

  factory FlashcardModel.fromJson(Map<String, dynamic> json) => FlashcardModel(
    question: json['question'] as String,
    reponse: json['reponse'] as String,
  );
}

class ExerciseModel {
  final String question;
  final String consigne;
  final String reponseAttendue;
  final List<String> reponsesMultiples;
  final List<String> options;
  final String astuceErreur;
  final String? typeExplicite;
  final List<String> reponsesAcceptees;
  final String? explication;

  const ExerciseModel({
    required this.question,
    required this.consigne,
    this.reponseAttendue = "",
    this.reponsesMultiples = const [],
    this.options = const [],
    required this.astuceErreur,
    this.typeExplicite,
    this.reponsesAcceptees = const [],
    this.explication,
  });

  // ✅ FIX : Getter qui détermine le type de façon explicite et centralisée.
  //          Plus besoin de répliquer cette logique dans chaque vue.
  ExerciseType get type {
    if (typeExplicite == 'saisieMot' || typeExplicite == 'singleInput') {
      return ExerciseType.singleInput;
    }
    if (typeExplicite == 'textQcm') return ExerciseType.textQcm;
    if (typeExplicite == 'numericBlanks') return ExerciseType.numericBlanks;
    if (options.isNotEmpty) return ExerciseType.textQcm;
    if (reponsesMultiples.isNotEmpty) return ExerciseType.numericBlanks;
    return ExerciseType.singleInput;
  }

  /// Vrai si la réponse attendue est un mot/texte (clavier texte, comparaison
  /// insensible à la casse) plutôt qu'un nombre.
  bool get estSaisieMot {
    if (typeExplicite == 'saisieMot') return true;
    if (type != ExerciseType.singleInput) return false;
    final t = reponseAttendue.trim().replaceAll(',', '.');
    return t.isNotEmpty && num.tryParse(t) == null;
  }

  Map<String, dynamic> toJson() => {
    'question': question,
    'consigne': consigne,
    'reponseAttendue': reponseAttendue,
    'reponsesMultiples': reponsesMultiples,
    'options': options,
    'astuceErreur': astuceErreur,
    if (typeExplicite != null) 'type': typeExplicite,
    if (reponsesAcceptees.isNotEmpty) 'reponsesAcceptees': reponsesAcceptees,
    if (explication != null && explication!.trim().isNotEmpty)
      'explication': explication!.trim(),
  };

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    final rawExp = json['explication'];
    final exp = (rawExp is String && rawExp.trim().isNotEmpty)
        ? rawExp.trim()
        : null;
    final rawType = json['type'];
    return ExerciseModel(
      question: json['question'] as String,
      consigne: json['consigne'] as String,
      reponseAttendue: json['reponseAttendue'] as String? ?? "",
      reponsesMultiples: List<String>.from(json['reponsesMultiples'] ?? []),
      options: List<String>.from(json['options'] ?? []),
      astuceErreur: json['astuceErreur'] as String,
      typeExplicite: rawType is String && rawType.trim().isNotEmpty
          ? rawType.trim()
          : null,
      reponsesAcceptees: List<String>.from(json['reponsesAcceptees'] ?? []),
      explication: exp,
    );
  }
}

class QuizModel {
  final String question;
  final List<String> options;
  final int indexCorrect;

  const QuizModel({
    required this.question,
    required this.options,
    required this.indexCorrect,
  });

  Map<String, dynamic> toJson() => {
    'question': question,
    'options': options,
    'indexCorrect': indexCorrect,
  };

  factory QuizModel.fromJson(Map<String, dynamic> json) => QuizModel(
    question: json['question'] as String,
    options: List<String>.from(json['options']),
    indexCorrect: json['indexCorrect'] as int,
  );
}
