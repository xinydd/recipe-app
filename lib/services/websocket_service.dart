import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum WebSocketEventType {
  recipeAdded,
  recipeUpdated,
  recipeDeleted,
  recipeFavoriteToggled,
  userPresence,
  newComment,
  recipeRatingUpdated,
}

class WebSocketEvent {
  final WebSocketEventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  WebSocketEvent({
    required this.type,
    required this.data,
    required this.timestamp,
  });

  factory WebSocketEvent.fromJson(Map<String, dynamic> json) {
    return WebSocketEvent(
      type: WebSocketEventType.values.firstWhere(
        (e) => e.toString() == 'WebSocketEventType.${json['type']}',
        orElse: () => WebSocketEventType.recipeUpdated,
      ),
      data: json['data'] as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class WebSocketService {
  static WebSocketService? _instance;
  WebSocketChannel? _channel;
  final StreamController<WebSocketEvent> _eventController = StreamController.broadcast();
  Timer? _reconnectTimer;
  bool _isConnected = false;
  String? _currentUserId;

  WebSocketService._internal();

  static WebSocketService get instance {
    _instance ??= WebSocketService._internal();
    return _instance!;
  }

  Stream<WebSocketEvent> get events => _eventController.stream;

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('Cannot connect WebSocket: User not authenticated');
      return;
    }

    _currentUserId = user.uid;
    final token = await user.getIdToken();
    final wsUrl = 'wss://your-websocket-url.com/ws?token=$token'; // Replace with your WebSocket URL

    try {
      _channel = IOWebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      
      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          print('WebSocket error: $error');
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          print('WebSocket connection closed');
          _isConnected = false;
          _scheduleReconnect();
        },
      );

      // Send presence update
      sendPresence(true);
    } catch (e) {
      print('Failed to connect WebSocket: $e');
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final Map<String, dynamic> json = jsonDecode(message as String);
      final event = WebSocketEvent.fromJson(json);
      _eventController.add(event);
    } catch (e) {
      print('Error parsing WebSocket message: $e');
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected) {
        connect();
      }
    });
  }

  void sendMessage(WebSocketEvent event) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(event.toJson()));
    }
  }

  void sendPresence(bool isOnline) {
    sendMessage(WebSocketEvent(
      type: WebSocketEventType.userPresence,
      data: {
        'userId': _currentUserId,
        'isOnline': isOnline,
        'timestamp': DateTime.now().toIso8601String(),
      },
      timestamp: DateTime.now(),
    ));
  }

  void notifyRecipeAdded(Map<String, dynamic> recipeData) {
    sendMessage(WebSocketEvent(
      type: WebSocketEventType.recipeAdded,
      data: recipeData,
      timestamp: DateTime.now(),
    ));
  }

  void notifyRecipeUpdated(Map<String, dynamic> recipeData) {
    sendMessage(WebSocketEvent(
      type: WebSocketEventType.recipeUpdated,
      data: recipeData,
      timestamp: DateTime.now(),
    ));
  }

  void notifyRecipeDeleted(String recipeId) {
    sendMessage(WebSocketEvent(
      type: WebSocketEventType.recipeDeleted,
      data: {'recipeId': recipeId},
      timestamp: DateTime.now(),
    ));
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    if (_channel != null) {
      sendPresence(false);
      _channel!.sink.close();
      _channel = null;
    }
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}