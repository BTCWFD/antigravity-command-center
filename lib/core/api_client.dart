import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class ApiClient {
  final String baseUrl;
  final String token;
  WebSocketChannel? _wsChannel;
  final _streamController = StreamController<Map<String, dynamic>>.broadcast();

  ApiClient({required this.baseUrl, required this.token});

  Stream<Map<String, dynamic>> get wsStream => _streamController.stream;

  // Realizar llamadas HTTP GET
  Future<dynamic> _get(String path) async {
    final cleanUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final url = Uri.parse('$cleanUrl$path');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error en respuesta del servidor: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Fallo de red al conectar al servidor Antigravity: $e');
    }
  }

  // Realizar llamadas HTTP POST
  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final cleanUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final url = Uri.parse('$cleanUrl$path');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error en respuesta del servidor: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Fallo de red al enviar datos: $e');
    }
  }

  // Endpoints específicos
  Future<Map<String, dynamic>> getStatus() async {
    final data = await _get('/api/status');
    return data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getTasks() async {
    return await _get('/api/tasks');
  }

  Future<List<dynamic>> getLogs() async {
    return await _get('/api/tasks/logs');
  }

  Future<List<dynamic>> getArtifacts() async {
    return await _get('/api/artifacts');
  }

  Future<Map<String, dynamic>> getArtifactContent(String id) async {
    final data = await _get('/api/artifacts/$id');
    return data as Map<String, dynamic>;
  }

  Future<bool> sendCommand(String command) async {
    try {
      final response = await _post('/api/command', {'command': command});
      return response['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendFeedback(String taskId, String feedback) async {
    try {
      final response = await _post('/api/tasks/$taskId/feedback', {'feedback': feedback});
      return response['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // Iniciar conexión WebSocket
  void connectWebSocket() {
    disconnectWebSocket(); // Limpiar previa si existiese

    final cleanUrl = baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
    final wsUri = Uri.parse('$cleanUrl/ws');

    try {
      _wsChannel = WebSocketChannel.connect(wsUri);
      _wsChannel!.stream.listen(
        (message) {
          try {
            final Map<String, dynamic> data = json.decode(message);
            _streamController.add(data);
          } catch (e) {
            // Ignorar errores de decodificación
          }
        },
        onError: (err) {
          _streamController.add({'type': 'connection_error', 'message': err.toString()});
          // Reintentar en 5 segundos
          Future.delayed(const Duration(seconds: 5), () => connectWebSocket());
        },
        onDone: () {
          _streamController.add({'type': 'connection_closed'});
        },
      );
    } catch (e) {
      _streamController.add({'type': 'connection_error', 'message': e.toString()});
    }
  }

  // Desconectar WebSocket
  void disconnectWebSocket() {
    _wsChannel?.sink.close();
    _wsChannel = null;
  }

  void dispose() {
    disconnectWebSocket();
    _streamController.close();
  }
}
