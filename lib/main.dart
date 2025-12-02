import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/services/notification_service.dart';
import 'package:perfit/core/services/setting_service.dart';
import 'package:perfit/core/theme/app_theme.dart';
import 'package:perfit/data/models/assessment_model.dart';
import 'package:perfit/data/models/basket_provider_model.dart';
import 'package:perfit/data/models/meal_provider.dart';
import 'package:perfit/firebase_options.dart';
import 'package:perfit/screens/main_navigation.dart';
import 'package:perfit/screens/splash_screen.dart';
import 'package:provider/provider.dart';

ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.init();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final savedTheme = await SettingService().loadThemeMode();
  themeNotifier.value = savedTheme;

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AssessmentModel()),
        ChangeNotifierProvider(create: (_) => BasketProvider()),
        ChangeNotifierProvider(create: (_) => MealProvider()),
      ],
      child: SafeArea(
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, currentMode, _) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: currentMode,
              home: StreamBuilder(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (_, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  if (snapshot.hasData) {
                    return MainNavigation();
                  }

                  return SplashScreen();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
