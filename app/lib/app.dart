import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/repositories/auth_repository.dart';
import 'core/repositories/bike_repository.dart';
import 'core/repositories/ride_repository.dart';
import 'core/route_observer.dart';
import 'core/token_storage.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'state/auth_provider.dart';
import 'theme/redl_colors.dart';
import 'theme/redl_theme.dart';

class RedlApp extends StatelessWidget {
  const RedlApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient();
    final tokenStorage = TokenStorage();
    final authRepository = AuthRepository(apiClient);

    return MultiProvider(
      providers: [
        Provider.value(value: apiClient),
        Provider.value(value: authRepository),
        Provider(create: (_) => BikeRepository(apiClient)),
        Provider(create: (_) => RideRepository(apiClient)),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(apiClient: apiClient, authRepository: authRepository, tokenStorage: tokenStorage)
            ..restore(),
        ),
      ],
      child: MaterialApp(
        title: 'REDL',
        debugShowCheckedModeBanner: false,
        theme: RedlTheme.dark,
        darkTheme: RedlTheme.dark,
        navigatorObservers: [appRouteObserver],
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthProvider>().status;

    switch (status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator(color: RedlColors.accent)));
      case AuthStatus.authenticated:
        return const HomeShell();
      case AuthStatus.unauthenticated:
        return const OnboardingScreen();
    }
  }
}
