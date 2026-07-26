String webDiaVetitoUrl(String username) {
  return Uri.https('web.diatar.eu', '/diavetito/', <String, String>{
    'mqtt': username.trim(),
  }).toString();
}
