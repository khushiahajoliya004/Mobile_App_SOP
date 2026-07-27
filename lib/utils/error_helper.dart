import 'dart:convert';
import 'package:dio/dio.dart';

/// Extracts a user-friendly error message from any exception.
/// Handles DioException responses from the backend properly.
String extractErrorMessage(
  dynamic error, {
  String fallback = 'Something went wrong',
}) {
  if (error is DioException) {
    // Network/timeout errors
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Check your internet.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Cannot connect to server. Check your internet.';
    }

    // Server responded with an error
    var data = error.response?.data;
    final statusCode = error.response?.statusCode;

    // Parse JSON string response
    if (data is String && data.startsWith('{')) {
      try {
        data = jsonDecode(data);
      } catch (_) {}
    }

    // Extract message from backend response
    if (data is Map) {
      final msg = data['message'];
      if (msg is List && msg.isNotEmpty) return msg.join(', ');
      if (msg is String && msg.isNotEmpty) return msg;
      if (data['error'] is String &&
          data['error'] != 'Bad Request' &&
          data['error'] != 'Internal Server Error') {
        return data['error'];
      }
    } else if (data is String && data.isNotEmpty && data.length < 200) {
      return data;
    }

    // Fallback to status code based messages
    if (statusCode != null) {
      switch (statusCode) {
        case 400:
          return 'Invalid request. Please check your input.';
        case 401:
          return 'Session expired. Please login again.';
        case 403:
          return 'You do not have permission for this action.';
        case 404:
          return 'Not found.';
        case 409:
          return 'This record already exists.';
        case 413:
          return 'File is too large.';
        case 500:
          return 'Server error. Please try again later.';
        default:
          return 'Request failed (Error $statusCode).';
      }
    }
  }

  // Non-Dio errors
  final str = error.toString();
  if (str.length < 100) return str;
  return fallback;
}
