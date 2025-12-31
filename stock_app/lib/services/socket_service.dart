import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class SocketService {
  WebSocketChannel? _channel;
  final String _url = 'ws://10.0.2.2:8000/ws/stocks'; // Android Emulator
  // final String _url = 'ws://localhost:8000/ws/stocks'; // iOS Simulator / Web

  Stream<dynamic>? get stream => _channel?.stream;

  void connect() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_url));
      print('🔌 WebSocket Connected');
    } catch (e) {
      print('⚠️ WebSocket Error: $e');
    }
  }

  void disconnect() {
    _channel?.sink.close();
    print('🔌 WebSocket Disconnected');
  }

  // Helper để parse dữ liệu JSON từ server
  Map<String, dynamic>? parseData(dynamic message) {
    try {
      return jsonDecode(message);
    } catch (e) {
      print('⚠️ Parse Error: $e');
      return null;
    }
  }
}
