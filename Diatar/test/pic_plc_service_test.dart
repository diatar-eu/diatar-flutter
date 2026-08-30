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
}
