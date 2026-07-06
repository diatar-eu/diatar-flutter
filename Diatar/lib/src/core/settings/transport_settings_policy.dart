import 'package:flutter/foundation.dart';
import 'package:diatar_common/diatar_common.dart';

class TransportSettingsPolicy {
  const TransportSettingsPolicy();

  bool transportSettingsChanged(AppSettings previous, AppSettings next) {
    return _mqttSettingsChanged(previous, next) ||
        _tcpSettingsChanged(previous, next);
  }

  String tcpTargetsStatusLabel(AppSettings value) {
    if (!value.tcpClientEnabled || value.tcpTargets.isEmpty) {
      return '-';
    }
    final List<String> targets = _normalizedTcpTargets(value);
    if (targets.isEmpty) {
      return '-';
    }
    if (targets.length == 1) {
      return targets.first;
    }
    return '${targets.first} (+${targets.length - 1})';
  }

  bool _mqttSettingsChanged(AppSettings previous, AppSettings next) {
    if (previous.internetRelayEnabled != next.internetRelayEnabled) {
      return true;
    }
    if (!previous.internetRelayEnabled && !next.internetRelayEnabled) {
      return false;
    }
    return previous.mqttUser.trim() != next.mqttUser.trim() ||
        previous.mqttPassword != next.mqttPassword ||
        previous.mqttChannel.trim() != next.mqttChannel.trim();
  }

  bool _tcpSettingsChanged(AppSettings previous, AppSettings next) {
    if (previous.tcpClientEnabled != next.tcpClientEnabled) {
      return true;
    }
    if (!previous.tcpClientEnabled && !next.tcpClientEnabled) {
      return false;
    }
    return !listEquals(
      _normalizedTcpTargets(previous),
      _normalizedTcpTargets(next),
    );
  }

  List<String> _normalizedTcpTargets(AppSettings value) {
    return value.tcpTargets
        .map((String target) => target.trim())
        .where((String target) => target.isNotEmpty)
        .toList();
  }
}
