import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/services/lecteur_son.dart';
import 'package:myapp/services/ouvrir_lien.dart';

void main() {
  test('moteur de son : winmm sous Windows, audioplayers ailleurs', () {
    expect(choisirMoteurSon(windows: true), MoteurSon.winmm);
    expect(choisirMoteurSon(windows: false), MoteurSon.audioplayers);
  });

  test('lien Claude accepté par cmd start', () {
    const url =
        'https://claude.ai/new?q=Le%C3%A7on%20pour%20le%20Labo%20d%27%C3%89mile';
    expect(lienSurPourCmd(url), isTrue);
    expect(argumentsCmdStart(url), ['/c', 'start', '', url]);
  });

  test('liens dangereux ou non http refusés', () {
    expect(lienSurPourCmd('https://a.fr/x&calc'), isFalse);
    expect(lienSurPourCmd('https://a.fr/x y'), isFalse);
    expect(lienSurPourCmd('file:///c:/windows/notepad.exe'), isFalse);
    expect(lienSurPourCmd('calc'), isFalse);
  });
}
