import 'package:flutter/material.dart';

import '../theme/redl_spacing.dart';
import '../widgets/redl_buttons.dart';
import '../widgets/redl_logo.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: RedlSpacing.screenPadding),
          child: Column(
            children: [
              const SizedBox(height: RedlSpacing.safeTopOnboarding),
              const RedlLockup(),
              const Spacer(),
              RedlPrimaryButton(
                label: 'Create Account',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
              ),
              const SizedBox(height: 12),
              RedlSecondaryButton(
                label: 'Log In',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
