/// Route paths aligned with `Golf mobile app design/src/app/routes.tsx`.
abstract final class AppPaths {
  static const welcome = '/';
  static const login = '/login';
  static const register = '/register';
  static const registerPassword = '/register/password';
  /// Guest-readable legal (not under `/app` — avoids auth redirect).
  static const legalTerms = '/legal/terms-of-service';
  static const legalPrivacy = '/legal/privacy-policy';
  static const forgotPassword = '/forgot-password';
  static const forgotPasswordSent = '/forgot-password/sent';
  static const resetPassword = '/reset-password';
  static const resetPasswordSuccess = '/reset-password/success';
  static const onboardingBasic = '/onboarding/basic';
  static const onboardingGolf = '/onboarding/golf';
  static const onboardingPreferences = '/onboarding/preferences';
  static const onboardingPhotos = '/onboarding/photos';
  static const support = '/support';

  static const app = '/app';
  static const appDiscover = '/app/discover';
  static const appGhinder = '/app/ghinder';
  static const appMatches = '/app/matches';
  static const appMessages = '/app/messages';
  static const appProfile = '/app/profile';
  static const appProfileEdit = '/app/profile/edit';
  static const appMembership = '/app/membership';
  static const appSettings = '/app/settings';
  static const appNotifications = '/app/notifications';
  static const appVerification = '/app/verification';
  static const appReportUser = '/app/report-user';
  static const appBlockUser = '/app/block-user';
  static const appPrivacyPolicy = '/app/privacy-policy';
  static const appTerms = '/app/terms-of-service';
  static const appLocationPermission = '/app/location-permission';
  static const appNotificationPermission = '/app/notification-permission';
  static const appError = '/app/error';
  static const appNoConnection = '/app/no-connection';
  static const appCompleteProfile = '/app/complete-profile';
  static const appPremiumDemo = '/app/premium-features-demo';
  static const appEnableLocation = '/app/enable-location';
  static const appLogoutConfirm = '/app/logout-confirm';
  static const appChangePassword = '/app/change-password';
  static const appDeleteAccount = '/app/delete-account';
  static const appViewProfile = '/app/view-profile';
  static const appPrivacySettings = '/app/privacy-settings';
  static const appBlockedUsers = '/app/blocked-users';
  static const appChangeUsername = '/app/change-username';
  static const appChangeEmail = '/app/change-email';
  static const appManagePhotos = '/app/manage-photos';
  static const appPlayerRatings = '/app/player-ratings';
  static const appRatePlayer = '/app/rate-player';
  static const appAccountSuspended = '/app/account-suspended';
  static const appSubscriptionExpired = '/app/subscription-expired';
  static const appManualLocation = '/app/manual-location';

  static String appProfileUser(String id) => '/app/profile/$id';
  static String appMessageThread(String id) => '/app/messages/$id';
}
