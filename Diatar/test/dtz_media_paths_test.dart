import 'package:diatar_app/src/core/dtz/dtz_media_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stores actual ZIP paths and ignores separate legacy bases', () {
    final DtzMediaPaths paths = DtzMediaPaths(<String>[
      'audio/song.mp3',
      'scores/page.png',
    ]);
    final String local = paths.localize(
      'B C:\\old\\sounds\\\n'
      'Z1234 song.mp3\n'
      'b D:\\old\\photos\\\n'
      'f1234 page.png\n'
      'i1234 3000\n',
    );
    expect(
      local,
      '${DtzMediaPaths.localHeader}\n'
      'Z1234 audio/song.mp3\n'
      'f1234 scores/page.png\n'
      'i1234 3000\n',
    );
  });

  test('does not guess between duplicate filenames', () {
    final DtzMediaPaths paths = DtzMediaPaths(<String>[
      'first/song.mp3',
      'second/song.mp3',
    ]);
    expect(() => paths.resolve('song.mp3'), throwsFormatException);
    expect(paths.resolve('first/song.mp3'), 'first/song.mp3');
    expect(paths.resolve('../first/song.mp3'), isNull);
    expect(paths.resolve('C:/first/song.mp3'), isNull);
  });

  test('a removed local file cannot resolve to a different file', () {
    final DtzMediaPaths paths = DtzMediaPaths(<String>['other/audio/song.mp3']);
    expect(
      paths.localize('${DtzMediaPaths.localHeader}\nz1234 audio/song.mp3\n'),
      '${DtzMediaPaths.localHeader}\n',
    );
  });
}
