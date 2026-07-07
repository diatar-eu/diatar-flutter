import 'package:flutter/foundation.dart';
import 'package:diatar_common/diatar_common.dart';

class TransportRuntimeState {
  const TransportRuntimeState({
    required this.mqttUser,
    required this.tcpTargets,
    required this.mqttActive,
    required this.tcpConfigured,
    required this.mqttConnectAttemptAt,
    required this.tcpConnectAttemptAt,
  });

  final String mqttUser;
  final List<String> tcpTargets;
  final bool mqttActive;
  final bool tcpConfigured;
  final DateTime? mqttConnectAttemptAt;
  final DateTime? tcpConnectAttemptAt;
}

class TransportSettingsPolicy {
  const TransportSettingsPolicy();

  bool transportSettingsChanged(AppSettings previous, AppSettings next) {
    return _mqttSettingsChanged(previous, next) ||
        _tcpSettingsChanged(previous, next);
  }

  String normalizedMqttUser(AppSettings value) {
    return value.mqttUser.trim();
  }

  List<String> normalizedTcpTargets(AppSettings value) {
    return _normalizedTcpTargets(value);
  }

  bool isMqttActive(AppSettings value) {
    return value.internetRelayEnabled && normalizedMqttUser(value).isNotEmpty;
  }

  bool isTcpConfigured(AppSettings value) {
    return value.tcpClientEnabled && _normalizedTcpTargets(value).isNotEmpty;
  }

  TransportRuntimeState runtimeState(
    AppSettings value, {
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();
    final String mqttUser = normalizedMqttUser(value);
    final List<String> tcpTargets = _normalizedTcpTargets(value);
    final bool mqttActive = value.internetRelayEnabled && mqttUser.isNotEmpty;
    final bool tcpConfigured = value.tcpClientEnabled && tcpTargets.isNotEmpty;
    return TransportRuntimeState(
      mqttUser: mqttUser,
      tcpTargets: tcpTargets,
      mqttActive: mqttActive,
      tcpConfigured: tcpConfigured,
      mqttConnectAttemptAt: mqttActive ? timestamp : null,
      tcpConnectAttemptAt: tcpConfigured ? timestamp : null,
    );
  }

  String tcpTargetsStatusLabel(AppSettings value) {
    if (!isTcpConfigured(value)) {
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
    return normalizedMqttUser(previous) != normalizedMqttUser(next) ||
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
