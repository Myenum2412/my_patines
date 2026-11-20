import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/patient_session.dart';

/// Owns the signed-in [PatientSession] for the whole app.
///
/// The clinic API issues short-lived JWTs (24h by default) and exposes a
/// sliding-session endpoint (`POST /api/clinics/auth/refresh`). Without it the
/// token quietly expires and every request starts returning 401, which users
/// see as being "logged out" even though they never tapped Logout.
///
/// This manager keeps a single session in memory, persists refreshes, and
/// coalesces concurrent refresh attempts so a burst of 401s rotates the token
/// only once (the backend revokes the previous token on every rotation).
class SessionManager {
  SessionManager({http.Client? client}) : _client = client ?? http.Client();

  static final SessionManager instance = SessionManager();

  /// Refresh when the token has less than this much life left.
  static const _refreshWindow = Duration(hours: 12);

  /// A forced refresh (triggered by a 401) is skipped if another refresh
  /// succeeded this recently — in-flight requests can all be holding the same
  /// stale token and must not rotate it more than once.
  static const _recentRefreshWindow = Duration(seconds: 10);

  /// Don't retry a failed slide on every request; the patient may be offline.
  static const _retryCooldown = Duration(minutes: 2);

  static const _refreshTimeout = Duration(seconds: 10);

  final http.Client _client;

  PatientSession? _session;
  Future<PatientSession?>? _refreshing;
  DateTime? _lastRefreshAt;
  DateTime? _lastAttemptAt;

  /// Called after the stored session is proven invalid (refresh was rejected).
  /// The app uses this to send the user back to the login screen.
  void Function()? onExpired;

  PatientSession? get session => _session;

  bool get isSignedIn => _session != null;

  /// Stores the freshly created session after login.
  Future<void> bind(PatientSession session) async {
    _session = session;
    _lastRefreshAt = null;
    _lastAttemptAt = null;
    await SessionStorage.save(session);
  }

  /// Loads the persisted session and slides it forward if it is close to
  /// expiring. Returns null when there is no usable session.
  Future<PatientSession?> restore() async {
    _lastAttemptAt = null;
    final saved = await SessionStorage.load();
    if (saved == null) {
      _session = null;
      return null;
    }
    _session = saved;

    final expiresAt = _expiryOf(saved);
    final needsRefresh =
        expiresAt == null ||
        expiresAt.isBefore(DateTime.now().add(_refreshWindow));
    if (!needsRefresh) return saved;

    // A refresh rejected by the server means the saved token is dead; the
    // caller should show the login screen. Network trouble keeps the session.
    final refreshed = await _refresh(notify: false);
    return refreshed;
  }

  /// Refreshes when the session is within [_refreshWindow] of expiry.
  /// Safe to call on every app launch/resume; it is a no-op most of the time.
  Future<PatientSession?> maybeRefresh() async {
    final current = _session;
    if (current == null) return null;
    final expiresAt = _expiryOf(current);
    if (expiresAt != null &&
        expiresAt.isAfter(DateTime.now().add(_refreshWindow))) {
      return current;
    }
    final lastAttempt = _lastAttemptAt;
    if (lastAttempt != null &&
        DateTime.now().difference(lastAttempt) < _retryCooldown) {
      return current;
    }
    return _refresh();
  }

  /// Forces a token rotation. Used when an API call comes back 401.
  Future<PatientSession?> refresh() => _refresh();

  /// The token every API call should send. Falls back to [fallback] when no
  /// session is bound (unit tests construct services directly).
  String tokenFor(PatientSession fallback) {
    final current = _session;
    if (current != null && current.clinicId == fallback.clinicId) {
      return current.token;
    }
    return fallback.token;
  }

  /// Signs out locally (and revokes the token server-side when possible).
  Future<void> logout({bool notifyServer = true}) async {
    final current = _session;
    _session = null;
    _lastRefreshAt = null;
    _lastAttemptAt = null;
    await SessionStorage.clear();

    if (notifyServer && current != null) {
      // Fire-and-forget: a failed revoke must never block the local logout.
      unawaited(_revoke(current.token));
    }
  }

  Future<PatientSession?> _refresh({bool notify = true}) {
    return _refreshing ??= _doRefresh(notify: notify).whenComplete(() {
      _refreshing = null;
    });
  }

  Future<PatientSession?> _doRefresh({required bool notify}) async {
    final current = _session;
    if (current == null) return null;

    final lastRefresh = _lastRefreshAt;
    if (lastRefresh != null &&
        DateTime.now().difference(lastRefresh) < _recentRefreshWindow) {
      return current;
    }

    _lastAttemptAt = DateTime.now();

    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.backendUrl}/api/clinics/auth/refresh'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'token': current.token}),
          )
          .timeout(_refreshTimeout);

      // 400/401/403 = the token is expired, revoked or malformed. Anything
      // else (5xx, gateway hiccup) is treated as transient so a backend blip
      // never signs the patient out.
      if (response.statusCode == 400 ||
          response.statusCode == 401 ||
          response.statusCode == 403) {
        await _expire(notify: notify);
        return null;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return current;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return current;
      final token = decoded['token'];
      if (token is! String || token.trim().isEmpty) return current;

      final ttlSeconds = _asInt(decoded['tokenExpiresInSeconds']);
      final updated = current.copyWith(
        token: token.trim(),
        expiresAt: ttlSeconds != null && ttlSeconds > 0
            ? DateTime.now().add(Duration(seconds: ttlSeconds))
            : jwtExpiry(token.trim()),
      );

      _session = updated;
      _lastRefreshAt = DateTime.now();
      await SessionStorage.save(updated);
      return updated;
    } catch (_) {
      // Offline / timeout / malformed response: keep the current session so a
      // network failure never looks like an automatic logout.
      return current;
    }
  }

  Future<void> _expire({required bool notify}) async {
    _session = null;
    _lastRefreshAt = null;
    _lastAttemptAt = null;
    await SessionStorage.clear();
    if (notify) onExpired?.call();
  }

  Future<void> _revoke(String token) async {
    try {
      await _client
          .post(
            Uri.parse('${AppConfig.backendUrl}/api/clinics/auth/logout'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: '{}',
          )
          .timeout(_refreshTimeout);
    } catch (_) {
      // Best effort only.
    }
  }

  DateTime? _expiryOf(PatientSession session) {
    return session.expiresAt ?? jwtExpiry(session.token);
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
