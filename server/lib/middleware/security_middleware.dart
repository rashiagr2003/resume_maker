import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';

class RateLimiter {
  final int maxRequests;
  final Duration window;
  final Map<String, List<DateTime>> _requestLogs = {};

  RateLimiter({
    this.maxRequests = 30,
    this.window = const Duration(minutes: 1),
  });

  bool isAllowed(String clientIp) {
    final now = DateTime.now();
    final cutoff = now.subtract(window);

    final timestamps = _requestLogs.putIfAbsent(clientIp, () => []);
    timestamps.removeWhere((t) => t.isBefore(cutoff));

    if (timestamps.length >= maxRequests) {
      return false;
    }

    timestamps.add(now);
    return true;
  }
}

Middleware createSecurityMiddleware({
  RateLimiter? rateLimiter,
  int maxBodyBytes = 2 * 1024 * 1024, // 2 MB
}) {
  final limiter = rateLimiter ?? RateLimiter();

  return (Handler innerHandler) {
    return (Request request) async {
      // 1. Client IP rate limiting
      final ip = _getClientIp(request);
      if (!limiter.isAllowed(ip)) {
        return Response(
          429,
          headers: {'Content-Type': 'application/json', 'Retry-After': '60'},
          body: jsonEncode({
            'error': 'Too many requests. Please slow down and try again in a moment.',
          }),
        );
      }

      // 2. Request body size check
      final contentLength = request.contentLength;
      if (contentLength != null && contentLength > maxBodyBytes) {
        return Response(
          413,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'error': 'Payload Too Large. Maximum allowed request size is ${maxBodyBytes ~/ (1024 * 1024)} MB.',
          }),
        );
      }

      // 3. Process request and attach standard security headers
      try {
        final response = await innerHandler(request);
        return response.change(
          headers: {
            'X-Content-Type-Options': 'nosniff',
            'X-Frame-Options': 'DENY',
            'X-XSS-Protection': '1; mode=block',
            'Referrer-Policy': 'no-referrer',
            'Cache-Control': 'no-store, no-cache, must-revalidate, private',
            'Pragma': 'no-cache',
            ...response.headers,
          },
        );
      } catch (e) {
        // Redact internal error specifics to prevent information leakage
        return Response(
          500,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'error': 'An internal server error occurred. Please try again.',
          }),
        );
      }
    };
  };
}

String _getClientIp(Request request) {
  final forwarded = request.headers['x-forwarded-for'];
  if (forwarded != null && forwarded.isNotEmpty) {
    return forwarded.split(',').first.trim();
  }
  final realIp = request.headers['x-real-ip'];
  if (realIp != null && realIp.isNotEmpty) {
    return realIp.trim();
  }
  final connectionInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
  return connectionInfo?.remoteAddress.address ?? 'unknown';
}
