import 'package:flutter/material.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/register_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/item/item_form_screen.dart';
import '../presentation/screens/item/item_details_screen.dart';
import '../presentation/screens/profile/profile_screen.dart';
import '../presentation/screens/splash_screen.dart';
import '../presentation/screens/home/match_details_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String itemForm = '/item-form';
  static const String itemDetails = '/item-details';
  static const String profile = '/profile';
  static const String matchDetails = '/match-details';

  static Map<String, WidgetBuilder> get routes => {
    splash: (_) => const SplashScreen(),
    login: (_) => const LoginScreen(),
    register: (_) => const RegisterScreen(),
    home: (_) => const HomeScreen(),
    itemForm: (_) => const ItemFormScreen(),
    itemDetails: (_) => const ItemDetailsScreen(),
    profile: (_) => const ProfileScreen(),
    matchDetails: (_) => const MatchDetailsScreen(),
  };
}