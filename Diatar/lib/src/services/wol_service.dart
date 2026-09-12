import 'dart:io';
import 'dart:typed_data';

class WolTarget {
  const WolTarget({required this.macAddress, this.host, this.port});

  final String macAddress;
  final String? host;
  final int? port;
}

WolTarget? parseWolTarget(String line) {
  final String normalized = line.trim().replaceAll(' ', '');
  if (normalized.isEmpty) {
    return null;
  }
  final int at = normalized.indexOf('@');
  if (at < 0) {
    if (!_isValidMac(normalized)) {
      return null;
    }
    return WolTarget(macAddress: normalized.toUpperCase());
  }
  final String mac = normalized.substring(0, at);
  final String rest = normalized.substring(at + 1);
  if (!_isValidMac(mac)) {
    return null;
  }
  String host = rest;
  int? port;
  final int colon = rest.lastIndexOf(':');
  if (colon > 0 && colon < rest.length - 1) {
    final int? parsedPort = int.tryParse(rest.substring(colon + 1));
    if (parsedPort == null || parsedPort < 1 || parsedPort > 65535) {
      return null;
    }
    port = parsedPort;
    host = rest.substring(0, colon);
  }
  if (!_isIpv4(host)) {
    return null;
  }
  return WolTarget(
    macAddress: mac.toUpperCase(),
    host: host,
    port: port,
  );
}

bool isValidIpv4(String value) {
  return _isIpv4(value.trim());
}

bool _isValidMac(String value) {
  return RegExp(r'^(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$').hasMatch(value);
}

bool _isIpv4(String value) {
  final List<String> parts = value.split('.');
  if (parts.length != 4) {
    return false;
  }
  for (final String part in parts) {
    final int? octet = int.tryParse(part);
    if (octet == null || octet < 0 || octet > 255) {
      return false;
    }
  }
  return true;
}

class WolService {
  static Uint8List buildMagicPacket(String macAddress) {
    final String hex = macAddress.replaceAll(':', '').replaceAll('-', '');
    final Uint8List packet = Uint8List(6 + 16 * 6);
    packet.setAll(0, List<int>.filled(6, 0xFF));
    for (int i = 0; i < 16; ++i) {
      for (int j = 0; j < 6; ++j) {
        packet[6 + i * 6 + j] = int.parse(
          hex.substring(j * 2, j * 2 + 2),
          radix: 16,
        );
      }
    }
    return packet;
  }

  Future<void> sendWakeOnLan(
    List<WolTarget> targets, {
    required String broadcastAddress,
    required int defaultPort,
  }) async {
    final RawDatagramSocket socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
    );
    socket.broadcastEnabled = true;
    try {
      for (final WolTarget target in targets) {
        final InternetAddress address;
        if (target.host == null) {
          address = InternetAddress(broadcastAddress);
        } else {
          address = InternetAddress(target.host!);
        }
        socket.send(
          buildMagicPacket(target.macAddress),
          address,
          target.port ?? defaultPort,
        );
      }
    } finally {
      socket.close();
    }
  }
}