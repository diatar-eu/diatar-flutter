class MqttUser {
  MqttUser({
    required this.username,
    this.email = '',
    List<String>? channels,
    this.sendersGroup = false,
    this.sentForDetails = false,
  }) : channels = channels ?? List<String>.filled(10, '');

  final String username;
  String email;
  final List<String> channels;
  bool sendersGroup;
  bool sentForDetails;
}
