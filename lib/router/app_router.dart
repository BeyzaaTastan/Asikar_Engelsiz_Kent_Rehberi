import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/user_type_screen.dart';
import '../screens/interests_screen.dart';
import '../screens/accessibility_prefs_screen.dart';
import '../screens/volunteer_status_screen.dart';
import '../screens/volunteer_skills_screen.dart';
import '../screens/registration_complete_screen.dart';
import '../screens/route_screen.dart';
import '../screens/venue/add_venue_screen.dart';
import '../screens/venue/venue_detail_screen.dart';
import '../main_wrapper.dart';

/// Uygulamadaki tüm route isimlerini barındıran sabit sınıf.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String mainWrapper = '/main';
  static const String profile = '/profile';
  static const String userType = '/user-type';
  static const String interests = '/interests';
  static const String accessibilityPrefs = '/accessibility-prefs';
  static const String volunteerStatus = '/volunteer-status';
  static const String volunteerSkills = '/volunteer-skills';
  static const String registrationComplete = '/registration-complete';
  static const String routeScreen = '/route';
  static const String addVenue = '/add-venue';
  static const String venueDetail = '/venue-detail';
}

/// Merkezi route üretici — MaterialApp.onGenerateRoute ile kullanılır.
class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case AppRoutes.register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());

      case AppRoutes.mainWrapper:
        return MaterialPageRoute(builder: (_) => const MainWrapper());

      case AppRoutes.profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());

      case AppRoutes.userType:
        return MaterialPageRoute(builder: (_) => const UserTypeScreen());

      case AppRoutes.interests:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => InterestsScreen(userType: args['userType'] as String),
        );

      case AppRoutes.accessibilityPrefs:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => AccessibilityPrefsScreen(
            userType: args['userType'] as String,
            selectedInterests: args['selectedInterests'] as Set<String>,
          ),
        );

      case AppRoutes.volunteerStatus:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => VolunteerStatusScreen(
            userType: args['userType'] as String,
            selectedInterests: args['selectedInterests'] as Set<String>,
          ),
        );

      case AppRoutes.volunteerSkills:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => VolunteerSkillsScreen(
            userType: args['userType'] as String,
            selectedInterests: args['selectedInterests'] as Set<String>,
          ),
        );

      case AppRoutes.registrationComplete:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => RegistrationCompleteScreen(
            isVolunteer: args['isVolunteer'] as bool,
          ),
        );

      case AppRoutes.routeScreen:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => RouteScreen(
            destinationName: args['destinationName'] as String,
            destinationLocation: args['destinationLocation'] as dynamic,
          ),
        );

      case AppRoutes.addVenue:
        return MaterialPageRoute(builder: (_) => const AddVenueScreen());

      case AppRoutes.venueDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => VenueDetailScreen(
            venueId: args['venueId'] as String,
          ),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('Route bulunamadı: ${settings.name}'),
            ),
          ),
        );
    }
  }
}
