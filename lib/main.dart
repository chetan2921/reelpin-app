import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'repositories/reel_repository.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'viewmodels/home_viewmodel.dart';
import 'viewmodels/map_viewmodel.dart';
import 'viewmodels/search_viewmodel.dart';
import 'screens/app_shell.dart';

void main() {
  runApp(const ReelPinApp());
}

class ReelPinApp extends StatelessWidget {
  const ReelPinApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();
    final repository = ReelRepository(apiService);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => HomeViewModel(repository)..loadReels(),
        ),
        ChangeNotifierProvider(
          create: (_) => MapViewModel(repository)..loadMapReels(),
        ),
        ChangeNotifierProvider(create: (_) => SearchViewModel(repository)),
      ],
      child: MaterialApp(
        title: 'ReelPin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.brutalTheme,
        home: const AppShell(),
      ),
    );
  }
}
