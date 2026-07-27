import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../session/auth_session.dart';
import '../../features/auth/auth_screens.dart';
import '../../features/auth/register_password_screen.dart';
import '../../features/auth/password_recovery_screens.dart';
import '../../features/discover/discover_screen.dart';
import '../../features/ghinder/ghinder_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/matches/matches_screen.dart';
import '../../features/messages/messages_screens.dart';
import '../../features/location/enable_location_screen.dart';
import '../../features/location/set_location_screen.dart';
import '../../features/misc/misc_screens.dart';
import '../../features/misc/no_connection_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/settings/account_change_screens.dart';
import '../../features/settings/account_suspended_screen.dart';
import '../../features/settings/blocked_users_screen.dart';
import '../../features/settings/help_support_screen.dart';
import '../../features/settings/delete_account_flow_screen.dart';
import '../../features/settings/manage_photos_screen.dart';
import '../../features/settings/privacy_policy_screen.dart';
import '../../features/settings/privacy_settings_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/verification/ghin_verification_screen.dart';
import '../../features/onboarding/onboarding_screens.dart';
import '../../features/profile/profile_screens.dart';
import '../../features/player_ratings/player_ratings_screens.dart';
import '../../features/shell/main_shell.dart';
import '../../features/welcome/welcome_screen.dart';
import 'app_paths.dart';

/// GoRouter graph aligned with `Golf mobile app design/src/app/routes.tsx`.
GoRouter createAppRouter(AuthSession auth) {
  // Keep navigator key scoped to router instance to avoid duplicate-key
  // collisions if a new router is created during app lifecycle/restart.
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppPaths.welcome,
    refreshListenable: auth,
    redirect: (context, state) {
      if (state.uri.path == '/app/home') return AppPaths.app;
      final path = state.matchedLocation;
      final authed = auth.isLoggedIn;
      final needsAuth = path.startsWith('/app/') || path == '/app';
      final isAuthPage =
          path == AppPaths.login || path == AppPaths.register || path == AppPaths.registerPassword;
      final isOnboarding = path.startsWith('/onboarding');
      final isSetupExempt = isOnboarding ||
          path == AppPaths.support ||
          path == AppPaths.legalTerms ||
          path == AppPaths.legalPrivacy ||
          path == AppPaths.appManagePhotos ||
          path == AppPaths.appProfileEdit ||
          path == AppPaths.appCompleteProfile ||
          path == AppPaths.appLogoutConfirm ||
          path == AppPaths.appDeleteAccount ||
          path == AppPaths.appChangePassword ||
          path == AppPaths.appChangeEmail ||
          path == AppPaths.appChangeUsername ||
          path == AppPaths.appEnableLocation ||
          path == AppPaths.appManualLocation ||
          path == AppPaths.appLocationPermission ||
          path == AppPaths.appNotificationPermission ||
          path == AppPaths.appNoConnection ||
          path == AppPaths.appError ||
          path == AppPaths.appAccountSuspended;

      if (needsAuth && !authed) return AppPaths.login;
      if (authed && isAuthPage) {
        return auth.postAuthLocation;
      }
      if (authed && path == AppPaths.welcome) {
        return auth.postAuthLocation;
      }
      // Incomplete profiles cannot use the main shell (Home included), even after Google sign-in.
      if (authed && auth.profileSetupComplete != true && needsAuth && !isSetupExempt) {
        return auth.onboardingResumePath;
      }
      // Already complete — never force onboarding again on later sign-ins.
      if (authed && auth.profileSetupComplete == true && isOnboarding) {
        return AppPaths.app;
      }

      return null;
    },
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
    GoRoute(path: AppPaths.welcome, builder: (_, __) => const WelcomeScreen()),
    GoRoute(
      path: AppPaths.login,
      builder: (context, state) => LoginScreen(magicToken: state.uri.queryParameters['magicToken']),
    ),
    GoRoute(path: AppPaths.register, builder: (_, __) => const RegisterScreen()),
    GoRoute(
      path: AppPaths.registerPassword,
      builder: (context, state) {
        final extra = state.extra;
        if (extra is RegisterPasswordArgs) {
          return RegisterPasswordScreen(args: extra);
        }
        return const RegisterScreen();
      },
    ),
    GoRoute(path: AppPaths.legalTerms, builder: (_, __) => const TermsOfServiceScreen()),
    GoRoute(path: AppPaths.legalPrivacy, builder: (_, __) => const PrivacyPolicyScreen()),
    GoRoute(path: AppPaths.forgotPassword, builder: (_, __) => const ForgotPasswordScreen()),
    GoRoute(
      path: AppPaths.forgotPasswordSent,
      builder: (context, state) {
        final extra = state.extra;
        final email = extra is String ? extra : '';
        return ForgotPasswordSentScreen(email: email);
      },
    ),
    GoRoute(
      path: AppPaths.resetPassword,
      builder: (context, state) => ResetPasswordScreen(resetToken: state.uri.queryParameters['token']),
    ),
    GoRoute(path: AppPaths.resetPasswordSuccess, builder: (_, __) => const ResetPasswordSuccessScreen()),
    GoRoute(path: AppPaths.onboardingBasic, builder: (_, __) => const OnboardingBasicScreen()),
    GoRoute(path: AppPaths.onboardingGolf, builder: (_, __) => const OnboardingGolfScreen()),
    GoRoute(path: AppPaths.onboardingPreferences, builder: (_, __) => const OnboardingPreferencesScreen()),
    GoRoute(path: AppPaths.onboardingPhotos, builder: (_, __) => const OnboardingPhotosScreen()),
    GoRoute(path: AppPaths.support, builder: (_, __) => const HelpSupportScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppPaths.app,
              pageBuilder: (context, state) => NoTransitionPage<void>(
                key: state.pageKey,
                child: const HomeScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppPaths.appDiscover,
              pageBuilder: (context, state) => NoTransitionPage<void>(
                key: state.pageKey,
                child: const DiscoverScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppPaths.appGhinder,
              pageBuilder: (context, state) => NoTransitionPage<void>(
                key: state.pageKey,
                child: const GhinderScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppPaths.appMatches,
              pageBuilder: (context, state) => NoTransitionPage<void>(
                key: state.pageKey,
                child: const MatchesScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppPaths.appSettings,
              pageBuilder: (context, state) => NoTransitionPage<void>(
                key: state.pageKey,
                child: const SettingsScreen(),
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: AppPaths.appProfileEdit,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/app/profile/:userId',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        String? milesHint;
        final ex = state.extra;
        if (ex is Map) {
          final m = ex['distanceMilesHint'];
          if (m != null) milesHint = m.toString();
        }
        return ViewProfileScreen(
          userId: state.pathParameters['userId']!,
          distanceMilesHint: milesHint,
        );
      },
    ),
    GoRoute(
      path: AppPaths.appMessages,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const MessagesScreen(),
      routes: [
        GoRoute(
          path: ':id',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => ChatThreadScreen(
            conversationId: state.pathParameters['id']!,
            peerUserId: state.uri.queryParameters['peer'],
            initialPeerName: state.uri.queryParameters['name'],
            matchedAtIso: state.uri.queryParameters['matchedAt'],
          ),
        ),
      ],
    ),
    GoRoute(
      path: AppPaths.appMembership,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const MembershipScreen(),
    ),
    GoRoute(
      path: AppPaths.appProfile,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const ProfileScreen(),
    ),
    GoRoute(
      path: AppPaths.appNotifications,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const NotificationsScreen(),
    ),
    GoRoute(
      path: AppPaths.appVerification,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const GhinVerificationScreen(),
    ),
    GoRoute(
      path: AppPaths.appReportUser,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => ReportUserScreen(targetUserId: state.uri.queryParameters['userId']),
    ),
    GoRoute(
      path: AppPaths.appBlockUser,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => BlockUserScreen(targetUserId: state.uri.queryParameters['userId']),
    ),
    GoRoute(
      path: AppPaths.appPrivacyPolicy,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: AppPaths.appTerms,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const TermsOfServiceScreen(),
    ),
    GoRoute(
      path: AppPaths.appLocationPermission,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const LocationPermissionScreen(),
    ),
    GoRoute(
      path: AppPaths.appNotificationPermission,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const NotificationPermissionScreen(),
    ),
    GoRoute(
      path: AppPaths.appError,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const ErrorScreen(),
    ),
    GoRoute(
      path: AppPaths.appNoConnection,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const NoConnectionScreen(),
    ),
    GoRoute(
      path: AppPaths.appCompleteProfile,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const CompleteProfileScreen(),
    ),
    GoRoute(
      path: AppPaths.appPremiumDemo,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const PremiumFeaturesDemoScreen(),
    ),
    GoRoute(
      path: AppPaths.appEnableLocation,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const EnableLocationScreen(),
    ),
    GoRoute(
      path: AppPaths.appLogoutConfirm,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const LogoutConfirmScreen(),
    ),
    GoRoute(
      path: AppPaths.appChangePassword,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const ChangePasswordScreen(),
    ),
    GoRoute(
      path: AppPaths.appDeleteAccount,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const DeleteAccountFlowScreen(),
    ),
    GoRoute(
      path: AppPaths.appViewProfile,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => ViewProfileAliasScreen(
        userId: state.uri.queryParameters['userId'],
      ),
    ),
    GoRoute(
      path: AppPaths.appPrivacySettings,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const PrivacySettingsScreen(),
    ),
    GoRoute(
      path: AppPaths.appBlockedUsers,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const BlockedUsersScreen(),
    ),
    GoRoute(
      path: AppPaths.appChangeUsername,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const ChangeUsernameScreen(),
    ),
    GoRoute(
      path: AppPaths.appChangeEmail,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const ChangeEmailScreen(),
    ),
    GoRoute(
      path: AppPaths.appManagePhotos,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const ManagePhotosScreen(),
    ),
    GoRoute(
      path: AppPaths.appPlayerRatings,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => PlayerRatingsScreen(
        userId: state.uri.queryParameters['userId'] ?? '',
      ),
    ),
    GoRoute(
      path: AppPaths.appRatePlayer,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => SubmitPlayerRatingScreen(
        userId: state.uri.queryParameters['userId'] ?? '',
      ),
    ),
    GoRoute(
      path: AppPaths.appAccountSuspended,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const AccountSuspendedScreen(),
    ),
    GoRoute(
      path: AppPaths.appSubscriptionExpired,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const SubscriptionExpiredScreen(),
    ),
    GoRoute(
      path: AppPaths.appManualLocation,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const SetLocationScreen(),
    ),
  ],
  );
}
