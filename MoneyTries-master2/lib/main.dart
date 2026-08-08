import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'core/session/session_manager.dart';
import 'routes/app_routes.dart';
import 'utils/responsive.dart';
import 'services/push_notification_service.dart';
import 'services/audio/interaction_feedback.dart';
import 'viewmodels/plan/plan_viewmodel.dart';
import 'viewmodels/history/history_viewmodel.dart';
import 'views/splash/splash_screen.dart';
import 'views/onboarding/onboarding_screen.dart';
import 'views/auth/login_screen.dart';
import 'views/auth/register_screen.dart';
import 'views/auth/security_pin_screen.dart';
import 'views/auth/set_password_screen.dart';
import 'views/auth/app_pin_screen.dart';
import 'views/home/home_screen.dart';
import 'views/plan/plan_screen.dart';
import 'views/plan/investment_amount_screen.dart';
import 'views/plan/plan_comparison_screen.dart';
import 'views/plan/terms_screen.dart';
import 'views/plan/configure_investment_screen.dart';
import 'views/plan/active_plan_screen.dart';
import 'views/history/history_screen.dart';
import 'views/support/support_screen.dart';
import 'views/profile/profile_screen.dart';
import 'views/referral/referral_screen.dart';
import 'views/deposit/deposit_screen.dart';
import 'views/withdrawal/withdrawal_screen.dart';
import 'views/kyc/kyc_verification_screen.dart';
import 'views/profile/notifications_view.dart';
import 'views/profile/plan_details_view.dart';
import 'widgets/animations/app_page_route.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Preload every UI sound + read the saved sound/haptics toggle before
  // the first frame, so the very first interaction (e.g. login) already
  // has zero-delay audio available. Non-fatal if it fails — the app
  // still runs fine with sounds silently disabled (see AppSoundService).
  unawaited(InteractionFeedback.init());

  runApp(const MoneytriesApp());

  // IMPORTANT: PushNotificationService.initialize() calls
  // FirebaseMessaging.requestPermission(), which on Android triggers the
  // native POST_NOTIFICATIONS runtime dialog. That dialog requires the
  // Activity's window to already have focus — if requested before the
  // first frame is drawn (as it previously was, ahead of runApp()),
  // Android silently drops the request with no error and no dialog ever
  // shown. Emulators are usually fast enough to win that race; many real
  // devices are not, which is why push worked in the emulator but silently
  // never got permission on physical hardware. Waiting for the first
  // rendered frame guarantees the window is focused before we ask.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    PushNotificationService.instance.initialize();
  });
}

class MoneytriesApp extends StatelessWidget {
  const MoneytriesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlanViewModel()),
        ChangeNotifierProvider(create: (_) => HistoryViewModel()),
      ],
      child: MaterialApp(
        title: 'Moneytries',
        debugShowCheckedModeBanner: false,
        navigatorKey: SessionManager.instance.navigatorKey,
        theme: AppTheme.lightTheme,
        builder: (context, child) {
          // ResponsiveAppShell handles:
          //   • ResponsiveConfig.instance.update(context) — scales .w/.h/.sp/.r
          //   • clamping the system text scaler to 0.9–1.25
          //   • centering + constraining content on tablets (maxWidth 640)
          //
          // The inner Builder re-reads context after ResponsiveAppShell has
          // updated ResponsiveConfig so that AppTheme.themeFor() picks up the
          // correct .sp values for Theme.of(context).textTheme consumers.
          return ResponsiveAppShell(
            child: Builder(
              builder: (ctx) => Theme(
                data: AppTheme.themeFor(ctx),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          );
        },
        initialRoute: AppRoutes.splash,
        // Every named route is resolved through onGenerateRoute so the
        // whole app gets the same premium fade + slide transition
        // (AppPageRoute) with zero per-screen changes. The widget map
        // below is identical in spirit to the old `routes:` table — only
        // *how* each entry becomes a Route changed, not which screen
        // maps to which path, so existing pushNamed/arguments calls
        // throughout the app keep working unmodified.
        onGenerateRoute: (settings) {
          final Map<String, WidgetBuilder> screens = {
            AppRoutes.splash: (_) => const SplashScreen(),
            AppRoutes.onboarding: (_) => const OnboardingScreen(),
            AppRoutes.login: (_) => const LoginScreen(),
            AppRoutes.register: (_) => const RegisterScreen(),
            AppRoutes.securityPin: (_) => const SecurityPinScreen(),
            AppRoutes.setPassword: (_) => const SetPasswordScreen(),
            AppRoutes.appPin: (_) => const AppPinScreen(),
            AppRoutes.home: (_) => const HomeScreen(),
            AppRoutes.plan: (_) => const PlanScreen(),
            AppRoutes.investmentAmount: (_) => const InvestmentAmountScreen(),
            AppRoutes.planComparison: (_) => const PlanComparisonScreen(),
            AppRoutes.terms: (_) => const TermsScreen(),
            AppRoutes.configure: (_) => const ConfigureInvestmentScreen(),
            AppRoutes.activePlan: (_) => const ActivePlanScreen(),
            AppRoutes.history: (_) => const HistoryScreen(),
            AppRoutes.support: (_) => const SupportScreen(),
            AppRoutes.profile: (_) => const ProfileScreen(),
            AppRoutes.referral: (_) => const ReferralScreen(),
            AppRoutes.deposit: (_) => const DepositScreen(),
            AppRoutes.withdrawal: (_) => const WithdrawalScreen(),
            AppRoutes.kyc: (_) => const KycVerificationScreen(),
            AppRoutes.notifications: (_) => const NotificationScreen(),
            AppRoutes.planDetails: (_) => const PlanDetailsView(),
          };
          final builder = screens[settings.name];
          if (builder == null) return null;
          return AppPageRoute(
            page: Builder(builder: builder),
            settings: settings,
          );
        },
      ),
    );
  }
}