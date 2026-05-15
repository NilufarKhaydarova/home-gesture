import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../shared/models/models.dart';
import '../../core/config/app_constants.dart';

/// Home Assistant WebSocket API service
class HomeAssistantService {
  String? _url;
  String? _token;
  WebSocketChannel? _wsChannel;
  int _messageId = 1;
  bool _isConnected = false;
  bool _isAuthenticated = false;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  final StreamController<HaConnectionState> _stateController =
      StreamController<HaConnectionState>.broadcast();

  final StreamController<HaEntity> _entityUpdateController =
      StreamController<HaEntity>.broadcast();

  final StreamController<List<HaEntity>> _entitiesController =
      StreamController<List<HaEntity>>.broadcast();

  final Map<String, HaEntity> _cachedEntities = {};
  String? _subscriptionId;

  /// Stream of connection state changes
  Stream<HaConnectionState> get stateStream => _stateController.stream;

  /// Stream of entity updates
  Stream<HaEntity> get entityUpdateStream => _entityUpdateController.stream;

  /// Stream of all entities
  Stream<List<HaEntity>> get entitiesStream => _entitiesController.stream;

  /// Current connection state
  HaConnectionState get state => _isAuthenticated
      ? HaConnectionState.authenticated(_url ?? '')
      : _isConnected
          ? HaConnectionState.connected(_url ?? '')
          : HaConnectionState.disconnected();

  /// Whether connected to Home Assistant
  bool get isConnected => _isConnected;

  /// Whether authenticated with Home Assistant
  bool get isAuthenticated => _isAuthenticated;

  /// Cached entities
  List<HaEntity> get entities => _cachedEntities.values.toList();

  /// Initialize service with URL and token
  Future<bool> initialize(String url, String token) async {
    _url = _normalizeUrl(url);
    _token = token;

    return await connect();
  }

  /// Normalize URL (add protocol if missing, remove trailing slash)
  String _normalizeUrl(String url) {
    String normalized = url.trim();

    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }

    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    return normalized;
  }

  /// Convert HTTP URL to WebSocket URL
  String _getWsUrl() {
    if (_url == null) throw Exception('URL not set');

    String wsUrl = _url!;
    wsUrl = wsUrl.replaceFirst('http://', 'ws://');
    wsUrl = wsUrl.replaceFirst('https://', 'wss://');

    return '$wsUrl${AppConstants.haWebSocketPath}';
  }

  /// Connect to Home Assistant via WebSocket
  Future<bool> connect() async {
    if (_url == null || _token == null) {
      _stateController.add(const HaConnectionState.error(
        'URL and token must be set',
      ));
      return false;
    }

    try {
      _isConnected = false;
      _isAuthenticated = false;
      _stateController.add(const HaConnectionState.connecting());

      // Close existing connection
      await disconnect();

      // Create WebSocket connection
      final wsUrl = _getWsUrl();
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Listen for messages
      _wsChannel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: false,
      );

      // Wait for auth message
      final authCompleted = await _waitForAuth();
      if (!authCompleted) {
        await disconnect();
        return false;
      }

      _isConnected = true;
      _isAuthenticated = true;
      _stateController.add(HaConnectionState.authenticated(_url!));

      // Start heartbeat
      _startHeartbeat();

      // Subscribe to entity updates
      await _subscribeToEvents();

      // Fetch initial entities
      await _fetchEntities();

      return true;
    } catch (e) {
      _stateController.add(HaConnectionState.error('Connection failed: $e'));
      _scheduleReconnect();
      return false;
    }
  }

  /// Wait for authentication to complete
  Future<bool> _waitForAuth() async {
    final completer = Completer<bool>();
    Timer? timeout;

    void authListener(HaConnectionState state) {
      if (state is HaConnectionStateAuthenticated) {
        timeout?.cancel();
        completer.complete(true);
      } else if (state is HaConnectionStateError) {
        timeout?.cancel();
        completer.complete(false);
      }
    }

    final subscription = stateStream.listen(authListener);

    timeout = Timer(const Duration(seconds: 10), () {
      subscription.cancel();
      completer.complete(false);
    });

    return completer.future;
  }

  /// Handle incoming WebSocket message
  void _handleMessage(dynamic message) {
    if (message is! String) return;

    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final type = data['type'] as String?;
      final success = data['success'] as bool? ?? false;

      switch (type) {
        case 'auth_required':
          _sendAuth();
          break;

        case 'auth_ok':
          _isConnected = true;
          _stateController.add(HaConnectionState.authenticated(_url ?? ''));
          break;

        case 'auth_invalid':
          _stateController.add(const HaConnectionState.error(
            'Authentication failed. Please check your token.',
          ));
          break;

        case 'event':
          _handleEvent(data);
          break;

        case 'result':
          _handleResult(data);
          break;

        case 'pong':
          // Heartbeat response
          break;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling message: $e');
      }
    }
  }

  /// Send authentication message
  void _sendAuth() {
    if (_wsChannel == null || _token == null) return;

    final authMessage = jsonEncode({
      'type': 'auth',
      'access_token': _token,
    });

    _wsChannel!.sink.add(authMessage);
  }

  /// Handle event message
  void _handleEvent(Map<String, dynamic> data) {
    final event = data['event'] as Map<String, dynamic>?;
    if (event == null) return;

    final eventType = event['event_type'] as String?;
    if (eventType != 'state_changed') return;

    final eventData = event['data'] as Map<String, dynamic>?;
    if (eventData == null) return;

    final entityId = eventData['entity_id'] as String?;
    final newState = eventData['new_state'] as Map<String, dynamic>?;
    if (entityId == null || newState == null) return;

    // Update cached entity
    final entity = HaEntity.fromJson({
      'entityId': entityId,
      'name': entityId,
      'domain': entityId.split('.').first,
      'state': newState['state'] ?? 'unknown',
      'attributes': newState['attributes'],
      'lastChanged': DateTime.parse(newState['last_changed'] ?? DateTime.now().toIso8601String()),
      'lastUpdated': DateTime.parse(newState['last_updated'] ?? DateTime.now().toIso8601String()),
    });

    _cachedEntities[entityId] = entity;
    _entityUpdateController.add(entity);
  }

  /// Handle result message
  void _handleResult(Map<String, dynamic> data) {
    final success = data['success'] as bool? ?? false;
    final id = data['id'] as int?;
    final result = data['result'] as List<dynamic>?;

    if (!success || id == null) return;

    // Handle entity list response
    if (result != null) {
      for (final item in result) {
        if (item is Map<String, dynamic>) {
          final entityId = item['entity_id'] as String?;
          if (entityId != null) {
            _cachedEntities[entityId] = HaEntity.fromJson({
              'entityId': entityId,
              'name': entityId,
              'domain': entityId.split('.').first,
              'state': item['state'] ?? 'unknown',
              'attributes': item['attributes'],
              'lastChanged': DateTime.parse(
                item['last_changed'] ?? DateTime.now().toIso8601String(),
              ),
              'lastUpdated': DateTime.parse(
                item['last_updated'] ?? DateTime.now().toIso8601String(),
              ),
            });
          }
        }
      }
      _entitiesController.add(entities);
    }
  }

  /// Handle WebSocket error
  void _handleError(error) {
    _stateController.add(HaConnectionState.error('Connection error: $error'));
  }

  /// Handle WebSocket disconnect
  void _handleDisconnect() {
    _isConnected = false;
    _isAuthenticated = false;
    _stateController.add(const HaConnectionState.disconnected());
    _scheduleReconnect();
  }

  /// Subscribe to state change events
  Future<void> _subscribeToEvents() async {
    if (_wsChannel == null || !_isAuthenticated) return;

    final subscriptionId = _messageId++;
    _subscriptionId = subscriptionId.toString();

    final message = jsonEncode({
      'id': subscriptionId,
      'type': 'subscribe_events',
      'event_type': 'state_changed',
    });

    _wsChannel!.sink.add(message);
  }

  /// Fetch all entities
  Future<void> _fetchEntities() async {
    if (_wsChannel == null || !_isAuthenticated) return;

    final messageId = _messageId++;

    final message = jsonEncode({
      'id': messageId,
      'type': 'get_states',
    });

    _wsChannel!.sink.add(message);
  }

  /// Call a Home Assistant service
  Future<bool> callService(
    String domain,
    String service,
    Map<String, dynamic> data,
  ) async {
    if (_wsChannel == null || !_isAuthenticated) return false;

    final messageId = _messageId++;

    final message = jsonEncode({
      'id': messageId,
      'type': 'call_service',
      'domain': domain,
      'service': service,
      'service_data': data,
    });

    try {
      _wsChannel!.sink.add(message);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get lock entities
  List<HaEntity> getLockEntities() {
    return entities
        .where((e) => e.domain == 'lock')
        .toList();
  }

  /// Lock a lock entity
  Future<bool> lockEntity(String entityId) async {
    return await callService(
      'lock',
      'lock',
      {'entity_id': entityId},
    );
  }

  /// Unlock a lock entity
  Future<bool> unlockEntity(String entityId) async {
    return await callService(
      'lock',
      'unlock',
      {'entity_id': entityId},
    );
  }

  /// Get current state of an entity via HTTP API (backup method)
  Future<HaEntity?> getEntityState(String entityId) async {
    if (_url == null || _token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_url/api/states/$entityId'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: AppConstants.haConnectionTimeout),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return HaEntity.fromJson({
          'entityId': data['entity_id'],
          'name': data['entity_id'],
          'domain': entityId.split('.').first,
          'state': data['state'],
          'attributes': data['attributes'],
          'lastChanged': DateTime.parse(data['last_changed']),
          'lastUpdated': DateTime.parse(data['last_updated']),
        });
      }
    } catch (e) {
      // Return null on error
    }
    return null;
  }

  /// Test connection via HTTP API
  Future<bool> testConnection() async {
    if (_url == null || _token == null) return false;

    try {
      final response = await http.get(
        Uri.parse('$_url/api/'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: AppConstants.haConnectionTimeout),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Start heartbeat timer
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_wsChannel != null && _isAuthenticated) {
        final message = jsonEncode({
          'id': _messageId++,
          'type': 'ping',
        });
        _wsChannel!.sink.add(message);
      }
    });
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      Duration(seconds: AppConstants.haReconnectDelay),
      () async {
        if (!isConnected) {
          await connect();
        }
      },
    );
  }

  /// Disconnect from Home Assistant
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();

    if (_wsChannel != null) {
      await _wsChannel!.sink.close();
      _wsChannel = null;
    }

    _isConnected = false;
    _isAuthenticated = false;
    _cachedEntities.clear();
  }

  /// Dispose resources
  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
    await _entityUpdateController.close();
    await _entitiesController.close();
  }
}

/// Home Assistant connection state
sealed class HaConnectionState {
  const HaConnectionState();

  const factory HaConnectionState.disconnected() = HaConnectionStateDisconnected;
  const factory HaConnectionState.connecting() = HaConnectionStateConnecting;
  const factory HaConnectionState.connected(String url) = HaConnectionStateConnected;
  const factory HaConnectionState.authenticated(String url) = HaConnectionStateAuthenticated;
  const factory HaConnectionState.error(String message) = HaConnectionStateError;
}

class HaConnectionStateDisconnected extends HaConnectionState {
  const HaConnectionStateDisconnected();
}

class HaConnectionStateConnecting extends HaConnectionState {
  const HaConnectionStateConnecting();
}

class HaConnectionStateConnected extends HaConnectionState {
  final String url;
  const HaConnectionStateConnected(this.url);
}

class HaConnectionStateAuthenticated extends HaConnectionState {
  final String url;
  const HaConnectionStateAuthenticated(this.url);
}

class HaConnectionStateError extends HaConnectionState {
  final String message;
  const HaConnectionStateError(this.message);
}
