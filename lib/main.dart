import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_shell.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/onboarding/sign_in_screen.dart';
import 'services/rule_classifier.dart';
import 'services/sms_service.dart';
import 'services/transaction_processor.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialise rule classifier from assets
  await RuleClassifier().initialize();

  // Check state
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;
  final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  
  // Also check actual firebase state
  final isFirebaseLoggedIn = AuthService().currentUser != null;

  runApp(
    ProviderScope(
      child: UpiLensApp(
        showOnboarding: !onboardingDone,
        isLoggedIn: isLoggedIn || isFirebaseLoggedIn,
      ),
    ),
  );
}

class UpiLensApp extends StatefulWidget {
  final bool showOnboarding;
  final bool isLoggedIn;
  const UpiLensApp({
    super.key, 
    required this.showOnboarding,
    required this.isLoggedIn,
  });

  @override
  State<UpiLensApp> createState() => _UpiLensAppState();
}

class _UpiLensAppState extends State<UpiLensApp> {
  @override
  void initState() {
    super.initState();
    // Start listening for live SMS once the app is live
    if (!widget.showOnboarding && widget.isLoggedIn) {
      _startLiveSmsListener();
    }
  }

  void _startLiveSmsListener() {
    SmsService().liveSmStream.listen((rawSms) async {
      await TransactionProcessor().process(rawSms);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UPI Lens',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, // Dark-first design
      darkTheme: _buildDarkTheme(),
      initialRoute: widget.showOnboarding 
          ? '/onboarding' 
          : (widget.isLoggedIn ? '/home' : '/signin'),
      routes: {
        '/onboarding': (_) => const OnboardingScreen(),
        '/signin': (_) => const SignInScreen(),
        '/home': (_) => const MainShell(),
      },
    );
  }

  ThemeData _buildDarkTheme() {
    const primaryAccent = Color(0xFF7B6EF6);
    const background = Color(0xFF0A0A0F);
    const surface = Color(0xFF13131A);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primaryAccent,
        surface: surface,
        onSurface: Colors.white,
        onPrimary: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
        headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
        titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: GoogleFonts.inter(color: Colors.white),
        bodyMedium: GoogleFonts.inter(color: const Color(0xFF888899)),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x08FFFFFF)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        indicatorColor: primaryAccent.withOpacity(0.1),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryAccent);
          }
          return const IconThemeData(color: Color(0xFF888899));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              color: primaryAccent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return GoogleFonts.inter(
            color: const Color(0xFF888899),
            fontSize: 12,
          );
        }),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
