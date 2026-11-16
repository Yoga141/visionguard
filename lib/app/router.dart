import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/forgot_password_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/calibration/presentation/calibration_page.dart';
import '../features/credits/presentation/credits_page.dart';
import '../features/monitoring/presentation/dashboard_page.dart';
import '../features/onboarding/presentation/privacy_onboarding_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/stats/presentation/statistics_page.dart';
import 'main_shell.dart';

/// Nama rute, sesuai kode layar pada SRS Tabel 3.
class Routes {
  static const splash = '/'; // auto-login dari sesi tersimpan
  static const login = '/login'; // S-01
  static const forgotPassword = '/forgot-password'; // S-01, UC-03
  static const onboarding = '/onboarding'; // S-02
  static const calibration = '/calibration'; // S-03
  static const dashboard = '/dashboard'; // S-04
  static const statistics = '/statistics'; // S-08
  static const credits = '/credits'; // S-09
  static const settings = '/settings'; // S-10

  /// Rute yang boleh dibuka tanpa login.
  static const public = {splash, login, forgotPassword};
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.splash,
    redirect: (context, state) {
      // Guard: halaman selain splash/login/lupa sandi wajib sudah login.
      final loggedIn = ref.read(authControllerProvider).isLoggedIn;
      if (!loggedIn && !Routes.public.contains(state.matchedLocation)) return Routes.login;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (context, state) => ForgotPasswordPage(initialEmail: state.uri.queryParameters['email']),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const PrivacyOnboardingPage(),
      ),
      GoRoute(
        path: Routes.calibration,
        builder: (context, state) => const CalibrationPage(),
      ),
      // Menu utama (DOCS_SPEC §7.4); tiap tab mempertahankan state-nya.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.dashboard, builder: (context, state) => const DashboardPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.statistics, builder: (context, state) => const StatisticsPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.credits, builder: (context, state) => const CreditsPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.settings, builder: (context, state) => const SettingsPage()),
          ]),
        ],
      ),
    ],
  );
});
