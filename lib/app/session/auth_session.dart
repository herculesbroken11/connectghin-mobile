import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../router/app_paths.dart';
import '../../core/network/api_client.dart';
import '../../core/profile/profile_setup.dart';
import '../../features/auth/data/auth_api.dart';
import '../../features/profiles/data/profiles_api.dart';

/// Persists access/refresh tokens and cached user id from `GET /auth/me`.
class AuthSession extends ChangeNotifier {
  AuthSession({ApiClient? apiClient}) {
    _apiClient = apiClient ??
        ApiClient(
          baseUrl: ApiConfig.baseUrl,
          getAccessToken: () => accessToken,
          getRefreshToken: () => refreshToken,
          onTokensRefreshed: _persistRefreshedTokens,
          onAuthFailure: _onAuthFailure,
        );
    _authApi = AuthApi(_apiClient);
  }

  late final ApiClient _apiClient;
  late final AuthApi _authApi;

  String? accessToken;
  String? refreshToken;
  String? userId;

  /// Last successful sign-in: `email`, `google`, or `apple` (persisted for signed-in UX).
  String? lastSignInMethod;

  bool? _meIsSuspended;
  String? _lifecycleStatus;

  /// One-shot message after forced sign-out (e.g. suspended while session was active). Cleared via [consumeAuthNotice].
  String? _authNotice;

  String? get authNotice => _authNotice;

  /// Incremented after profile edits so the profile tab can reload.
  int profileRefreshTick = 0;

  /// `null` until first successful `/profiles/me` check; `false` blocks Home until onboarding finishes.
  bool? profileSetupComplete;

  /// Resume path when [profileSetupComplete] is false.
  String onboardingResumePath = AppPaths.onboardingBasic;

  bool get isLoggedIn => accessToken != null && accessToken!.isNotEmpty;

  /// Where to send the user after sign-in / sign-up (Google included).
  /// Completed → Home. Known-incomplete → onboarding. Unknown → Home until status loads.
  String get postAuthLocation {
    if (profileSetupComplete == false) return onboardingResumePath;
    return AppPaths.app;
  }

  void consumeAuthNotice() {
    if (_authNotice == null) return;
    _authNotice = null;
    notifyListeners();
  }

  AuthApi get authApi => _authApi;

  ApiClient get apiClient => _apiClient;

  void bumpProfileRefresh() {
    profileRefreshTick++;
    unawaited(refreshProfileSetupStatus());
    notifyListeners();
  }

  /// Loads `/profiles/me` and updates [profileSetupComplete] / [onboardingResumePath].
  Future<void> refreshProfileSetupStatus() async {
    final t = accessToken;
    if (t == null || t.isEmpty) {
      profileSetupComplete = null;
      onboardingResumePath = AppPaths.onboardingBasic;
      notifyListeners();
      return;
    }
    try {
      final me = await ProfilesApi(_apiClient).getMe(t);
      profileSetupComplete = isProfileSetupComplete(me);
      onboardingResumePath = suggestedOnboardingPath(me);
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kProfileSetupComplete, profileSetupComplete!);
    } catch (_) {
      /* keep previous / cached flags when offline */
    }
    notifyListeners();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    accessToken = p.getString(_kAccess);
    refreshToken = p.getString(_kRefresh);
    userId = p.getString(_kUserId);
    lastSignInMethod = p.getString(_kLastSignIn);
    if (p.containsKey(_kProfileSetupComplete)) {
      profileSetupComplete = p.getBool(_kProfileSetupComplete);
    }
    _meIsSuspended = null;
    _lifecycleStatus = null;
    notifyListeners();
    if (accessToken != null && accessToken!.isNotEmpty) {
      await _refreshAccountFromMe();
      if (isLoggedIn) await refreshProfileSetupStatus();
    }
  }

  void _applyMe(Map<String, dynamic> me) {
    _meIsSuspended = me['isSuspended'] == true;
    _lifecycleStatus = me['lifecycleStatus'] as String?;
  }

  Future<void> _syncSignInMethodFromMe(Map<String, dynamic> me) async {
    final raw = me['authProvider'];
    if (raw is! String) return;
    final m = raw.toLowerCase();
    if (!_isAllowedSignInMethod(m)) return;
    lastSignInMethod = m;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLastSignIn, m);
  }

  bool _restrictedFromAppliedMe() {
    if (_meIsSuspended == true) return true;
    final s = _lifecycleStatus;
    if (s != null && s != 'ACTIVE') return true;
    return false;
  }

  /// Suspended / non-ACTIVE: clear session (same outcome as logout). Login is already blocked for those users.
  Future<void> _logoutIfRestrictedAfterMe() async {
    if (!_restrictedFromAppliedMe()) return;
    _authNotice =
        'Your account is suspended or inactive. You have been signed out. Contact support if you need help.';
    await clear(keepAuthNotice: true);
  }

  Future<void> _refreshAccountFromMe() async {
    final t = accessToken;
    if (t == null || t.isEmpty) return;
    try {
      final me = await _authApi.me(t);
      userId = me['id'] as String?;
      _applyMe(me);
      await _syncSignInMethodFromMe(me);
      if (userId != null) {
        final p = await SharedPreferences.getInstance();
        await p.setString(_kUserId, userId!);
      }
      if (_restrictedFromAppliedMe()) {
        await _logoutIfRestrictedAfterMe();
        return;
      }
    } catch (_) {
      /* offline or expired token — leave flags null */
    }
    notifyListeners();
  }

  Future<void> setTokens({
    required String access,
    required String refresh,
    String? signInMethod,
  }) async {
    accessToken = access;
    refreshToken = refresh;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAccess, access);
    await p.setString(_kRefresh, refresh);
    if (signInMethod != null && _isAllowedSignInMethod(signInMethod)) {
      lastSignInMethod = signInMethod;
      await p.setString(_kLastSignIn, signInMethod);
    }
    try {
      final me = await _authApi.me(access);
      userId = me['id'] as String?;
      _applyMe(me);
      await _syncSignInMethodFromMe(me);
      if (userId != null) {
        await p.setString(_kUserId, userId!);
      }
      if (_restrictedFromAppliedMe()) {
        await _logoutIfRestrictedAfterMe();
        return;
      }
    } catch (_) {
      userId = null;
      _meIsSuspended = null;
      _lifecycleStatus = null;
      await p.remove(_kUserId);
    }
    if (isLoggedIn) {
      await refreshProfileSetupStatus();
      // New Google / email accounts often have almost no profile yet — never leave status unknown after auth.
      if (profileSetupComplete == null) {
        profileSetupComplete = false;
        onboardingResumePath = AppPaths.onboardingBasic;
        notifyListeners();
      }
    } else {
      notifyListeners();
    }
  }

  Future<void> _persistRefreshedTokens(String access, String refresh) async {
    accessToken = access;
    refreshToken = refresh;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAccess, access);
    await p.setString(_kRefresh, refresh);
    notifyListeners();
    // Defer /auth/me until after the in-flight refresh Future completes (avoids nested refresh deadlock).
    Future<void>.delayed(Duration.zero, () {
      if (accessToken == access) {
        unawaited(_refreshAccountFromMe());
      }
    });
  }

  /// Session refresh failed or JWT was invalidated — clear local auth so the user can sign in again.
  Future<void> _onAuthFailure(String reason) async {
    if (!isLoggedIn) return;
    await forceSignOut(
      notice: reason == 'session_invalidated'
          ? 'Your session ended. Please sign in again.'
          : 'Your session expired. Please sign in again.',
    );
  }

  Future<void> forceSignOut({required String notice}) async {
    _authNotice = notice;
    await clear(keepAuthNotice: true);
  }

  /// Clears local session and invalidates refresh token on the server when possible.
  Future<void> logout() async {
    final t = accessToken;
    if (t != null && t.isNotEmpty) {
      try {
        await _authApi.logout(t);
      } catch (_) {
        /* offline — still clear locally */
      }
    }
    await clear();
  }

  Future<void> clear({bool keepAuthNotice = false}) async {
    accessToken = null;
    refreshToken = null;
    userId = null;
    _meIsSuspended = null;
    _lifecycleStatus = null;
    profileSetupComplete = null;
    onboardingResumePath = AppPaths.onboardingBasic;
    if (!keepAuthNotice) {
      _authNotice = null;
    }
    final p = await SharedPreferences.getInstance();
    await p.remove(_kAccess);
    await p.remove(_kRefresh);
    await p.remove(_kUserId);
    await p.remove(_kLastSignIn);
    await p.remove(_kProfileSetupComplete);
    lastSignInMethod = null;
    notifyListeners();
  }

  static const _kAccess = 'cg_access_token';
  static const _kRefresh = 'cg_refresh_token';
  static const _kUserId = 'cg_user_id';
  static const _kLastSignIn = 'cg_last_sign_in_method';
  static const _kProfileSetupComplete = 'cg_profile_setup_complete';
}

bool _isAllowedSignInMethod(String v) {
  return v == 'email' || v == 'google' || v == 'apple';
}
