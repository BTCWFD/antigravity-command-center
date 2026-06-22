import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> saveServerConfig(String host, String token) async {
    await _prefs?.setString('server_host', host);
    await _prefs?.setString('server_token', token);
  }

  static String getServerHost() {
    return _prefs?.getString('server_host') ?? 'http://192.168.1.15:3000';
  }

  static String getServerToken() {
    return _prefs?.getString('server_token') ?? '';
  }

  static Future<void> clear() async {
    await _prefs?.remove('server_host');
    await _prefs?.remove('server_token');
  }
}
