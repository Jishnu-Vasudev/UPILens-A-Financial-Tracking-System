import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F), // Dark-first background
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            // App Logo / Name
            Hero(
              tag: 'app_logo',
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF13131A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: const Icon(
                  Icons.lens_blur,
                  size: 64,
                  color: Color(0xFF7B6EF6),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'UPI Lens',
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Privacy-first wealth tracking',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xFF888899),
              ),
            ),
            const Spacer(flex: 1),
            // Google Sign-In Button
            _GoogleSignInButton(
              onPressed: () async {
                final auth = AuthService();
                final user = await auth.signInWithGoogle();
                if (user != null) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('is_logged_in', true);
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/home');
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('is_logged_in', false); // Guest mode
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/home');
                }
              },
              child: Text(
                'Continue without signing in',
                style: GoogleFonts.inter(
                  color: const Color(0xFF888899),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _GoogleSignInButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
              height: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'Continue with Google',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
