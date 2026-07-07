import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/settings/sender_status_policy.dart';
import 'sender_error_debouncer.dart';

class SenderCallbackCoordinator {
  SenderCallbackCoordinator({
    SenderErrorDebouncer? debouncer,
    SenderStatusPolicy? statusPolicy,
  }) : _debouncer = debouncer ?? SenderErrorDebouncer(),
       _statusPolicy = statusPolicy ?? const SenderStatusPolicy();

  final SenderErrorDebouncer _debouncer;
  final SenderStatusPolicy _statusPolicy;

  void invalidatePendingErrors() {
    _debouncer.invalidateAll();
  }

  ValueChanged<bool> buildStatusChangedHandler({
    required void Function(bool connected) setConnected,
    required VoidCallback clearError,
    required Future<void> Function() syncAfterConnect,
    required VoidCallback refreshFlags,
    required VoidCallback notify,
  }) {
    return (bool connected) {
      setConnected(connected);
      if (connected) {
        clearError();
        unawaited(syncAfterConnect());
      }
      refreshFlags();
      notify();
    };
  }

  void Function(String, Map<String, String>) buildTcpErrorHandler({
    required bool Function() isActive,
    required bool Function() isConnected,
    required VoidCallback markHasError,
    required void Function(String code, Map<String, String> params) setStatus,
    required VoidCallback refreshFlags,
    required VoidCallback notify,
  }) {
    return (String code, Map<String, String> params) {
      _debouncer.scheduleTcp(
        isActive: isActive,
        isConnected: isConnected,
        onConfirmed: () {
          markHasError();
          final SenderStatusUpdate status = _statusPolicy.tcpError(code, params);
          setStatus(status.code, status.params);
          refreshFlags();
          notify();
        },
      );
    };
  }

  void Function(String, Map<String, String>) buildMqttErrorHandler({
    required bool Function() isActive,
    required bool Function() isConnected,
    required VoidCallback markHasError,
    required void Function(String code, Map<String, String> params) setStatus,
    required VoidCallback refreshFlags,
    required VoidCallback notify,
  }) {
    return (String code, Map<String, String> params) {
      _debouncer.scheduleMqtt(
        isActive: isActive,
        isConnected: isConnected,
        onConfirmed: () {
          markHasError();
          final SenderStatusUpdate status = _statusPolicy.mqttError(code, params);
          setStatus(status.code, status.params);
          refreshFlags();
          notify();
        },
      );
    };
  }
}