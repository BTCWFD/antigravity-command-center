import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme.dart';
import 'core/storage.dart';
import 'core/api_client.dart';
import 'features/connection/connection_screen.dart';
import 'features/dashboard/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  runApp(const AntigravityApp());
}

class AntigravityApp extends StatelessWidget {
  const AntigravityApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtener configuración guardada
    final initialHost = StorageService.getServerHost();
    final initialToken = StorageService.getServerToken();

    return MaterialApp(
      title: 'Antigravity Command Center',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      // Si ya hay host guardado, intentamos usarlo. Si no, va a conexión.
      home: initialHost.isNotEmpty 
          ? DashboardScreen(client: ApiClient(baseUrl: initialHost, token: initialToken))
          : const ConnectionScreen(),
      routes: {
        '/connection': (context) => const ConnectionScreen(),
      },
    );
  }
}
