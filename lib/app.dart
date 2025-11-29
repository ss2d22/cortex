import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/cactus_service.dart';
import 'shared/theme.dart';
import 'features/onboarding/loading_screen.dart';

class CortexApp extends StatelessWidget {
  const CortexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CactusService(),
      child: MaterialApp(
        title: 'Cortex',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const LoadingScreen(),
      ),
    );
  }
}
