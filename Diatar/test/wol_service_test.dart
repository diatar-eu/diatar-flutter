import 'dart:typed_data';

import 'package:diatar_app/src/services/wol_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WolService.buildMagicPacket', () {
    test('builds a 102 byte packet with sync and 16 mac repeats', () {
      final Uint8List packet = WolService.buildMagicPacket('AA:BB:CC:DD:EE:FF');
      expect(packet.length, 102);
      expect(packet.sublist(0, 6), Uint8List.fromList(<int>[0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]));
      for (int i = 0; i < 16; ++i) {
        expect(
          packet.sublist(6 + i * 6, 6 + (i + 1) * 6),
          Uint8List.fromList(<int>[0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]),
        );
      }
    });

    test('accepts dash separated mac', () {
      final Uint8List packet = WolService.buildMagicPacket('aa-bb-cc-dd-ee-ff');
      expect(
        packet.sublist(6, 12),
        Uint8List.fromList(<int>[0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]),
      );
    });
  });

  group('parseWolTarget', () {
    test('parses plain mac for broadcast', () {
      final WolTarget? target = parseWolTarget('aa:bb:cc:dd:ee:ff');
      expect(target, isNotNull);
      expect(target!.macAddress, 'AA:BB:CC:DD:EE:FF');
      expect(target.host, isNull);
      expect(target.port, isNull);
    });

    test('parses mac with unicast host', () {
      final WolTarget? target = parseWolTarget('aa:bb:cc:dd:ee:ff@192.168.1.50');
      expect(target, isNotNull);
      expect(target!.host, '192.168.1.50');
      expect(target.port, isNull);
    });

    test('parses mac with unicast host and port override', () {
      final WolTarget? target = parseWolTarget('aa:bb:cc:dd:ee:ff@192.168.1.50:9');
      expect(target, isNotNull);
      expect(target!.host, '192.168.1.50');
      expect(target.port, 9);
    });

    test('rejects invalid mac', () {
      expect(parseWolTarget('aa:bb:cc:dd:ee'), isNull);
      expect(parseWolTarget('not-a-mac'), isNull);
    });

    test('rejects invalid host or port', () {
      expect(parseWolTarget('aa:bb:cc:dd:ee:ff@300.1.1.1'), isNull);
      expect(parseWolTarget('aa:bb:cc:dd:ee:ff@192.168.1.1:70000'), isNull);
    });
  });

  group('isValidIpv4', () {
    test('accepts valid ipv4', () {
      expect(isValidIpv4('255.255.255.255'), isTrue);
      expect(isValidIpv4('192.168.1.1'), isTrue);
    });

    test('rejects invalid ipv4', () {
      expect(isValidIpv4('256.1.1.1'), isFalse);
      expect(isValidIpv4('1.2.3'), isFalse);
      expect(isValidIpv4('hostname'), isFalse);
    });
  });
}