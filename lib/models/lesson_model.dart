// ✅ FIX : Ajout d'un enum ExerciseType pour distinguer clairement les 3 modes
//          d'exercice au lieu de deviner via les champs remplis.
enum ExerciseType {
  numericBlanks, // Maths à trous : [?] → champ numérique
  textQcm, // Français QCM  : options textuelles
  singleInput, // Trou unique texte libre
}

class LessonModel {
  final String titre;
  final List<FlashcardModel> astuces;
  final List<ExerciseModel> exercices;
  final List<QuizModel> quiz;

  const LessonModel({
    required this.titre,
    required this.astuces,
    required this.exercices,
    required this.quiz,
  });
}

class FlashcardModel {
  final String question;
  final String reponse;

  const FlashcardModel({required this.question, required this.reponse});
}

class ExerciseModel {
  final String question;
  final String consigne;
  final String reponseAttendue;
  final List<String> reponsesMultiples;
  final List<String> options;
  final String astuceErreur;

  const ExerciseModel({
    required this.question,
    required this.consigne,
    this.reponseAttendue = "",
    this.reponsesMultiples = const [],
    this.options = const [],
    required this.astuceErreur,
  });

  // ✅ FIX : Getter qui détermine le type de façon explicite et centralisée.
  //          Plus besoin de répliquer cette logique dans chaque vue.
  ExerciseType get type {
    if (options.isNotEmpty) return ExerciseType.textQcm;
    if (reponsesMultiples.isNotEmpty) return ExerciseType.numericBlanks;
    return ExerciseType.singleInput;
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
}
