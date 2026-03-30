import 'dart:async';
import 'package:flutter/services.dart';

/// CallStateService: Listens to native phone call state changes via EventChannel.
///
/// Events emitted:
///   { "state": "ringing"|"offhook"|"idle", "number": "...", "callType": "incoming"|"outgoing"|"unknown" }
///
/// Call state flow:
///   Incoming: idle -> ringing -> offhook -> idle
///   Outgoing: idle -> offhook -> idle
///
/// Usage:
///   final service = CallStateService();
///   service.callStateStream.listen((event) {
///     print('State: ${event.state}, Type: ${event.callType}');
///   });
///   // Don't forget to dispose when done
///   service.dispose();
class CallStateService {
  static const _eventChannel = EventChannel('com.callrecorder/call_state');

  StreamSubscription? _subscription;
  final _controller = StreamController<CallStateEvent>.broadcast();

  /// Broadcast stream of call state events.
  Stream<CallStateEvent> get callStateStream => _controller.stream;

  CallStateService() {
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final callEvent = CallStateEvent(
            state: event['state'] as String? ?? 'unknown',
            number: event['number'] as String? ?? '',
            callType: event['callType'] as String? ?? 'unknown',
          );
          _controller.add(callEvent);
        }
      },
      onError: (error) {
        // MissingPluginException happens in overlay engine — safe to ignore
        if (error.toString().contains('MissingPlugin')) return;
        print('CallStateService error: $error');
      },
    );
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}

/// Represents a phone call state change event.
class CallStateEvent {
  /// Current state: "ringing", "offhook", or "idle"
  final String state;

  /// Phone number (may be empty if unavailable)
  final String number;

  /// Call direction: "incoming", "outgoing", or "unknown"
  final String callType;

  CallStateEvent({
    required this.state,
    required this.number,
    required this.callType,
  });

  bool get isRinging => state == 'ringing';
  bool get isActive => state == 'offhook';
  bool get isIdle => state == 'idle';
  bool get isIncoming => callType == 'incoming';
  bool get isOutgoing => callType == 'outgoing';

  @override
  String toString() => 'CallStateEvent(state: $state, number: $number, callType: $callType)';
}
