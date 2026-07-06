class SenderStatusUpdate {
  const SenderStatusUpdate({
    required this.code,
    this.params = const <String, String>{},
  });

  final String code;
  final Map<String, String> params;
}

class SenderStatusPolicy {
  const SenderStatusPolicy();

  SenderStatusUpdate tcpError(String errorCode, Map<String, String> params) {
    switch (errorCode) {
      case 'senderTcpError':
        return SenderStatusUpdate(
          code: 'statusSenderTcpError',
          params: <String, String>{'error': params['error'] ?? ''},
        );
      case 'senderOpenPortFailed':
        return SenderStatusUpdate(
          code: 'statusSenderOpenPortFailed',
          params: <String, String>{
            'port': params['port'] ?? '0',
            'error': params['error'] ?? '',
          },
        );
      default:
        return SenderStatusUpdate(
          code: 'statusSenderError',
          params: <String, String>{'message': errorCode},
        );
    }
  }

  SenderStatusUpdate mqttError(String errorCode, Map<String, String> params) {
    switch (errorCode) {
      case 'senderMqttConnectFailed':
        return const SenderStatusUpdate(code: 'statusSenderMqttConnectFailed');
      case 'senderMqttError':
        return SenderStatusUpdate(
          code: 'statusSenderMqttError',
          params: <String, String>{'error': params['error'] ?? ''},
        );
      default:
        return SenderStatusUpdate(
          code: 'statusSenderError',
          params: <String, String>{'message': errorCode},
        );
    }
  }
}
