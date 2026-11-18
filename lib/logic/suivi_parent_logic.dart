import 'accueil_logic.dart';
import 'memoire.dart';

class ResumeLeconParent {
  final String matiere;
  final String titre;
  final int totalQuestions;
  final int suivies;
  final int maitrisees;
  final int aRevoir;

  const ResumeLeconParent({
    required this.matiere,
    required this.titre,
    required this.totalQuestions,
    required this.suivies,
    required this.maitrisees,
    required this.aRevoir,
  });

  int get pourcentageMaitrise =>
      totalQuestions == 0 ? 0 : ((maitrisees * 100) / totalQuestions).round();
}

class QuestionRateeParent {
  final String cle;
  final String titreLecon;
  final TypeQuestion type;
  final String texteQuestion;
  final int ratees;
  final int boite;

  const QuestionRateeParent({
    required this.cle,
    required this.titreLecon,
    required this.type,
    required this.texteQuestion,
    required this.ratees,
    required this.boite,
  });
}

String _texteDeRef(RefQuestion r) {
  switch (r.type) {
    case TypeQuestion.astuce:
      return r.lecon.astuces[r.index].question;
    case TypeQuestion.exercice:
      return r.lecon.exercices[r.index].question;
    case TypeQuestion.quiz:
      return r.lecon.quiz[r.index].question;
  }
}

List<ResumeLeconParent> calculerResumesLecons(
  List<LeconRef> lecons,
  Memoire memoire, {
  Set<String> masquees = const {},
}) {
  final res = <ResumeLeconParent>[];
  for (final ref in lecons) {
    final qs = questionsDeLecon(
      ref.lecon,
    ).where((q) => !masquees.contains(q.cle)).toList();
    final maitrisees = qs
        .where((q) => (memoire.etat(q.cle)?.boite ?? 0) >= kBoiteMaitrisee)
        .length;
    res.add(
      ResumeLeconParent(
        matiere: ref.matiere,
        titre: ref.lecon.titre,
        totalQuestions: qs.length,
        suivies: memoire.nombreSuiviesParmi(qs),
        maitrisees: maitrisees,
        aRevoir: memoire.nombreDues(qs),
      ),
    );
  }
  return res;
}

List<QuestionRateeParent> topQuestionsRatees(
  List<LeconRef> lecons,
  Memoire memoire, {
  Set<String> masquees = const {},
  int limite = 5,
}) {
  final liste = <QuestionRateeParent>[];
  for (final ref in lecons) {
    for (final q in questionsDeLecon(ref.lecon)) {
      if (masquees.contains(q.cle)) continue;
      final etat = memoire.etat(q.cle);
      if (etat == null || etat.ratees <= 0) continue;
      liste.add(
        QuestionRateeParent(
          cle: q.cle,
          titreLecon: ref.lecon.titre,
          type: q.type,
          texteQuestion: _texteDeRef(q),
          ratees: etat.ratees,
          boite: etat.boite,
        ),
      );
    }
  }
  liste.sort((a, b) {
    final cmp = b.ratees.compareTo(a.ratees);
    if (cmp != 0) return cmp;
    return a.boite.compareTo(b.boite);
  });
  return liste.take(limite).toList();
}

List<QuestionRateeParent> listerQuestionsMasquees(
  List<LeconRef> lecons,
  Memoire memoire,
  Set<String> masquees,
) {
  if (masquees.isEmpty) return const [];
  final liste = <QuestionRateeParent>[];
  for (final ref in lecons) {
    for (final q in questionsDeLecon(ref.lecon)) {
      if (!masquees.contains(q.cle)) continue;
      final etat = memoire.etat(q.cle);
      liste.add(
        QuestionRateeParent(
          cle: q.cle,
          titreLecon: ref.lecon.titre,
          type: q.type,
          texteQuestion: _texteDeRef(q),
          ratees: etat?.ratees ?? 0,
          boite: etat?.boite ?? 0,
        ),
      );
    }
  }
  return liste;
}
