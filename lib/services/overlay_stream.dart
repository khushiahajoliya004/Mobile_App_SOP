import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Single shared broadcast stream for overlay messages.
/// Prevents "Stream has already been listened to" errors.
final Stream<dynamic> overlayBroadcast =
    FlutterOverlayWindow.overlayListener.asBroadcastStream();
