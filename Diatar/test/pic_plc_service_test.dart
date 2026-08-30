import 'package:diatar_app/src/services/pic_plc_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes both PICPLC LED states and their checksum', () {
    expect(PicPlcService.ledCommand(led1: true, led2: true), <int>[
      0x21,
      0,
      0x03,
      0x03,
    ]);
  });

  test('encodes a disabled PICPLC LED output', () {
    expect(PicPlcService.ledCommand(led1: false, led2: false), <int>[
      0x21,
      0,
      0,
      0,
    ]);
  });

  test('repeats only navigation PICPLC actions', () {
    expect(
      PicPlcService.isRepeatableAction(PicPlcButtonAction.previousVerse),
      isTrue,
    );
    expect(
      PicPlcService.isRepeatableAction(PicPlcButtonAction.nextVerse),
      isTrue,
    );
    expect(
      PicPlcService.isRepeatableAction(PicPlcButtonAction.previousSong),
      isTrue,
    );
    expect(
      PicPlcService.isRepeatableAction(PicPlcButtonAction.nextSong),
      isTrue,
    );
    expect(PicPlcService.isRepeatableAction(PicPlcButtonAction.step), isTrue);
    expect(
      PicPlcService.isRepeatableAction(PicPlcButtonAction.toggleProjection),
      isFalse,
    );
    expect(
      PicPlcService.isRepeatableAction(PicPlcButtonAction.toggleDirection),
      isFalse,
    );
  });
}
