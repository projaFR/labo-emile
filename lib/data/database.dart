import '../models/lesson_model.dart';

class InitialDatabase {
  static final Map<String, List<LessonModel>> data = {
    'Mathématiques': [
      LessonModel(
        titre: 'Stratégies Multiplications',
        astuces: [
          const FlashcardModel(
            question: '14 x 4',
            reponse: 'On fait (10 x 4) + (4 x 4) = 40 + 16 = 56.',
          ),
        ],
        exercices: [
          // ✅ ExerciseType.numericBlanks → reponsesMultiples renseigné, options vide
          const ExerciseModel(
            question: '14 x 4 = ([?] x 4) + ([?] x 4)',
            consigne: 'Décompose le nombre 14 :',
            reponsesMultiples: ['10', '4'],
            astuceErreur: "14 c'est 10 + 4.",
          ),
        ],
        quiz: [
          const QuizModel(
            question: 'Combien font 5 x 5 ?',
            options: ['20', '25', '30'],
            indexCorrect: 1,
          ),
        ],
      ),
    ],
    'Français': [
      LessonModel(
        titre: 'Pluriel en -OU',
        astuces: [
          const FlashcardModel(
            question: 'Hibou',
            reponse: 'Exception : il prend un -X (des hiboux).',
          ),
        ],
        exercices: [
          // ✅ ExerciseType.textQcm → options renseigné, reponsesMultiples vide
          const ExerciseModel(
            question: 'Un [?] vole dans la nuit.',
            consigne: 'Choisis le bon mot :',
            options: ['hibou', 'hiboux', 'chou', 'pneu'],
            reponseAttendue: 'hibou',
            astuceErreur: 'Au singulier, on ne met pas de X !',
          ),
        ],
        quiz: [],
      ),
    ],
  };
}
