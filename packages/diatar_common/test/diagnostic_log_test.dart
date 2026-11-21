import 'dart:async';
import 'dart:convert';

import 'package:diatar_common/services/diagnostic_log.dart';
import 'package:diatar_common/services/diagnostic_log_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const DiagnosticMetadata _metadata = DiagnosticMetadata(
  version: '12.0.0',
  build: '158',
  os: 'ios',
  osVersion: '18.2',
);

void main() {
  test('logging is opt-in and does not change unrelated preferences', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'Username': 'private-user',
      'MqttPassword': 'private-password',
    });
    final DiagnosticLog log = DiagnosticLog(
      metadataLoader: () async => _metadata,
    );
    await log.initialize(DiagnosticApp.receiver);
    log.record(DiagnosticEvent.mqttConnecting);
    await log.flush();

    expect(log.enabled, isFalse);
    expect(log.hasEntries, isFalse);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), <String>{'Username', 'MqttPassword'});
    log.dispose();
  });

  test('enabled preference and log survive a new service instance', () async {
    final _MemoryStore store = _MemoryStore();
    final DiagnosticLog first = _log(store);
    await first.initialize(DiagnosticApp.receiver);
    expect(await first.setEnabled(true), isTrue);
    first.record(
      DiagnosticEvent.mqttConnectFailed,
      role: DiagnosticRole.mqttReceiver,
      elapsedMs: 30000,
      error: TimeoutException('private-user private-password secret-topic'),
    );
    await first.flush();
    first.dispose();

    final DiagnosticLog second = _log(store);
    await second.initialize(DiagnosticApp.receiver);
    final String text = second.exportText();
    expect(second.enabled, isTrue);
    expect(text, contains('"event":"mqttConnectFailed"'));
    expect(text, contains('"error":"timeout"'));
    expect(text, contains('"version":"12.0.0"'));
    expect(text, contains('"osVersion":"18.2"'));
    expect(text, isNot(contains('private-user')));
    expect(text, isNot(contains('private-password')));
    expect(text, isNot(contains('secret-topic')));
    expect(text, isNot(contains('TimeoutException:')));
    await second.flush();
    second.dispose();
  });

  test('disabling stops new records but preserves logs for sharing', () async {
    final _MemoryStore store = _MemoryStore();
    final DiagnosticLog log = _log(store);
    await log.initialize(DiagnosticApp.sender);
    await log.setEnabled(true);
    log.record(DiagnosticEvent.mqttConnected);
    await log.setEnabled(false);
    final String before = log.exportText();
    log.record(DiagnosticEvent.mqttDisconnected);
    expect(log.exportText(), before);
    log.dispose();

    final DiagnosticLog restarted = _log(store);
    await restarted.initialize(DiagnosticApp.sender);
    expect(restarted.enabled, isFalse);
    expect(restarted.exportText(), before);
    restarted.dispose();
  });

  test(
    'rotation stays bounded and preserves chronological order on reload',
    () async {
      final _MemoryStore store = _MemoryStore();
      final DiagnosticLog log = _log(store);
      await log.initialize(DiagnosticApp.sender);
      await log.setEnabled(true);
      for (int i = 0; i < 12000; i++) {
        log.record(
          DiagnosticEvent.mqttConnectFailed,
          role: DiagnosticRole.mqttSender,
          code: i,
          elapsedMs: 30000,
        );
      }
      await log.flush();
      final String exported = log.exportText();
      expect(
        utf8.encode(exported).length,
        lessThanOrEqualTo(DiagnosticLog.maxBytes),
      );
      expect(store.segments.length, DiagnosticLogStore.segmentCount);
      final List<int> codes = const LineSplitter()
          .convert(exported)
          .map((line) => jsonDecode(line) as Map<String, dynamic>)
          .where((entry) => entry['event'] == 'mqttConnectFailed')
          .map((entry) => entry['code'] as int)
          .toList();
      expect(codes.first, greaterThan(0));
      expect(codes.last, 11999);
      expect(
        codes,
        orderedEquals(List<int>.generate(codes.length, (i) => codes.first + i)),
      );
      log.dispose();

      final DiagnosticLog restarted = _log(store);
      await restarted.initialize(DiagnosticApp.sender);
      expect(restarted.exportText(), contains('"code":11999'));
      expect(
        utf8.encode(restarted.exportText()).length,
        lessThanOrEqualTo(DiagnosticLog.maxBytes),
      );
      await restarted.flush();
      restarted.dispose();
    },
  );

  test(
    'clear is ordered after pending writes and keeps the opt-in flag',
    () async {
      final _MemoryStore store = _MemoryStore();
      final DiagnosticLog log = _log(store);
      await log.initialize(DiagnosticApp.sender);
      await log.setEnabled(true);
      log.record(DiagnosticEvent.mqttConnected);
      final Future<bool> flushing = log.flush();
      final Future<bool> clearing = log.clear();
      await flushing;
      expect(await clearing, isTrue);
      expect(log.hasEntries, isFalse);
      expect(store.segments, isEmpty);
      expect(store.enabled, isTrue);
      log.dispose();
    },
  );

  test('failed initialization can be retried after storage recovers', () async {
    final _MemoryStore store = _MemoryStore()..failReads = true;
    final DiagnosticLog log = _log(store);
    expect(await log.initialize(DiagnosticApp.receiver), isFalse);
    expect(log.initialized, isFalse);
    expect(log.failed, isTrue);

    store.failReads = false;
    expect(await log.initialize(DiagnosticApp.receiver), isTrue);
    expect(log.initialized, isTrue);
    expect(log.failed, isFalse);
    expect(await log.setEnabled(true), isTrue);
    log.dispose();
  });

  test('corrupted stored log can be cleared while preserving opt-in', () async {
    final _MemoryStore store = _MemoryStore()..enabled = true;
    store.segments[0] = 'invalid JSON';
    final DiagnosticLog log = _log(store);
    expect(await log.initialize(DiagnosticApp.receiver), isFalse);
    expect(log.failed, isTrue);
    expect(await log.clear(), isTrue);
    expect(log.initialized, isTrue);
    expect(log.enabled, isTrue);
    expect(log.failed, isFalse);
    expect(log.exportText(), isNot(contains('invalid JSON')));
    await log.flush();
    log.dispose();
  });

  test('failed storage writes are reported and can be retried', () async {
    final _MemoryStore store = _MemoryStore();
    final DiagnosticLog log = _log(store);
    await log.initialize(DiagnosticApp.receiver);
    await log.setEnabled(true);
    store.failWrites = true;
    log.record(DiagnosticEvent.mqttDisconnected);
    expect(await log.flush(), isFalse);
    expect(log.failed, isTrue);

    store.failWrites = false;
    expect(await log.flush(), isTrue);
    expect(log.failed, isFalse);
    expect(store.segments.values.join(), contains('mqttDisconnected'));
    log.dispose();
  });

  test(
    'disabling takes effect even when saving the preference fails',
    () async {
      final _MemoryStore store = _MemoryStore();
      final DiagnosticLog log = _log(store);
      await log.initialize(DiagnosticApp.receiver);
      await log.setEnabled(true);
      store.failWrites = true;
      expect(await log.setEnabled(false), isFalse);
      expect(log.enabled, isFalse);
      final String text = log.exportText();
      log.record(DiagnosticEvent.mqttConnecting);
      expect(log.exportText(), text);
      log.dispose();
    },
  );

  test('clearing preferences removes only diagnostic segments', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{'Port': 1234});
    final DiagnosticLog log = DiagnosticLog(
      metadataLoader: () async => _metadata,
    );
    await log.initialize(DiagnosticApp.receiver);
    await log.setEnabled(true);
    log.record(DiagnosticEvent.mqttConnected);
    await log.flush();
    expect(await log.clear(), isTrue);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), <String>{'Port', 'diagnostics.enabled'});
    expect(prefs.getInt('Port'), 1234);
    expect(prefs.getBool('diagnostics.enabled'), isTrue);
    log.dispose();
  });

  test(
    'missing version metadata is explicit and does not block logging',
    () async {
      final DiagnosticLog log = DiagnosticLog(
        store: _MemoryStore(),
        metadataLoader: () async => throw StateError('unavailable'),
      );
      expect(await log.initialize(DiagnosticApp.sender), isTrue);
      await log.setEnabled(true);
      log.record(DiagnosticEvent.mqttConnecting);
      expect(log.exportText(), contains('"metadataAvailable":false'));
      expect(log.exportText(), contains('"event":"mqttConnecting"'));
      await log.flush();
      log.dispose();
    },
  );

  testWidgets('background lifecycle events trigger persistence', (
    tester,
  ) async {
    final _MemoryStore store = _MemoryStore();
    final DiagnosticLog log = _log(store);
    await log.initialize(DiagnosticApp.receiver);
    await log.setEnabled(true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    log.observeAppLifecycle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    final String saved = store.segments.values.join();
    expect(saved, contains('appInactive'));
    expect(saved, contains('appPaused'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await log.flush();
    log.dispose();
  });
}

DiagnosticLog _log(_MemoryStore store) =>
    DiagnosticLog(store: store, metadataLoader: () async => _metadata);

class _MemoryStore implements DiagnosticLogStore {
  bool enabled = false;
  bool failReads = false;
  bool failWrites = false;
  final Map<int, String> segments = <int, String>{};

  @override
  Future<DiagnosticLogSnapshot> load() async {
    if (failReads) {
      throw StateError('private storage failure details');
    }
    return DiagnosticLogSnapshot(
      enabled: enabled,
      segments: Map<int, String>.of(segments),
    );
  }

  @override
  Future<void> setEnabled(bool value) async {
    _checkWrite();
    enabled = value;
  }

  @override
  Future<void> writeSegment(int index, String value) async {
    _checkWrite();
    segments[index] = value;
  }

  @override
  Future<void> clear() async {
    _checkWrite();
    segments.clear();
  }

  void _checkWrite() {
    if (failWrites) {
      throw StateError('private storage failure details');
    }
  }
}
