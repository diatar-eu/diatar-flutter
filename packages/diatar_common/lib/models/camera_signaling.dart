import 'dart:convert';
import 'dart:typed_data';

enum CameraSignalKind { request, offer, answer, ice, stop }

class CameraSignal {
  const CameraSignal({required this.kind, this.sdp, this.candidate, this.sdpMid, this.sdpMLineIndex});

  final CameraSignalKind kind;
  final String? sdp;
  final String? candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': kind.name,
      if (sdp != null) 'sdp': sdp,
      if (candidate != null) 'candidate': candidate,
      if (sdpMid != null) 'sdpMid': sdpMid,
      if (sdpMLineIndex != null) 'sdpMLineIndex': sdpMLineIndex,
    };
  }

  factory CameraSignal.fromJson(Map<String, dynamic> json) {
    final CameraSignalKind kind = CameraSignalKind.values.firstWhere(
      (CameraSignalKind k) => k.name == json['kind'],
      orElse: () => CameraSignalKind.stop,
    );
    return CameraSignal(
      kind: kind,
      sdp: json['sdp'] as String?,
      candidate: json['candidate'] as String?,
      sdpMid: json['sdpMid'] as String?,
      sdpMLineIndex: json['sdpMLineIndex'] as int?,
    );
  }
}

Uint8List encodeCameraSignal(CameraSignal signal) {
  return Uint8List.fromList(utf8.encode(jsonEncode(signal.toJson())));
}

CameraSignal decodeCameraSignal(Uint8List body) {
  return CameraSignal.fromJson(jsonDecode(utf8.decode(body)) as Map<String, dynamic>);
}
