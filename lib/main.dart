import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'routes/app_routes.dart';
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
import 'views/plan/plan_payment_screen.dart';
import 'views/history/history_screen.dart';
import 'views/support/support_screen.dart';
import 'views/profile/profile_screen.dart';
import 'views/referral/referral_screen.dart';
import 'views/deposit/deposit_screen.dart';
import 'views/withdrawal/withdrawal_screen.dart';
import 'views/kyc/kyc_verification_screen.dart';
import 'views/profile/notifications_view.dart';
import 'views/profile/plan_details_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MoneytriesApp());
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
        theme: AppTheme.lightTheme,
        initialRoute: AppRoutes.splash,
        routes: {
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
          AppRoutes.planPayment: (_) => const PlanPaymentScreen(),
          AppRoutes.history: (_) => const HistoryScreen(),
          AppRoutes.support: (_) => const SupportScreen(),
          AppRoutes.profile: (_) => const ProfileScreen(),
          AppRoutes.referral: (_) => const ReferralScreen(),
          AppRoutes.deposit: (_) => const DepositScreen(),
          AppRoutes.withdrawal: (_) => const WithdrawalScreen(),
          AppRoutes.kyc: (_) => const KycVerificationScreen(),
          AppRoutes.notifications: (_) => const NotificationScreen(),
          AppRoutes.planDetails: (_) => const PlanDetailsView(),
        },
      ),
    );
  }
}