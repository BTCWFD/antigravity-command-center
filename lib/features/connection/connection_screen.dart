import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../core/api_client.dart';
import '../dashboard/dashboard_screen.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> with SingleTickerProviderStateMixin {
  final _hostController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _hostController.text = StorageService.getServerHost();
    _tokenController.text = StorageService.getServerToken();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _tokenController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final host = _hostController.text.trim();
    final token = _tokenController.text.trim();

    if (host.isEmpty) {
      setState(() => _errorMessage = 'Por favor, introduce el host del servidor');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = ApiClient(baseUrl: host, token: token);
      // Validar conexión contra el endpoint status
      final status = await client.getStatus();
      
      // Guardar configuraciones válidas
      await StorageService.saveServerConfig(host, token);
      
      if (!mounted) return;
      
      // Ir al Dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardScreen(client: client)),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error de conexión: Verifica la IP y que el servidor puente esté encendido.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.background,
              Color(0xFF0F172A),
              Color(0xFF020617),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo animado con brillo de neón
                  AnimatedBuilder(
                    animation: _glowController,
                    builder: (context, child) {
                      return Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accent.withOpacity(0.2 + (_glowController.value * 0.25)),
                              blurRadius: 15 + (_glowController.value * 15),
                              spreadRadius: 2 + (_glowController.value * 3),
                            ),
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.1 + (_glowController.value * 0.15)),
                              blurRadius: 30,
                              spreadRadius: 5,
                            )
                          ],
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, AppTheme.accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(
                          Icons.radar_rounded,
                          size: 44,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  // Título principal
                  Text(
                    'ANTIGRAVITY',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          letterSpacing: 4,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                  ),
                  Text(
                    'COMMAND CENTER',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          letterSpacing: 2,
                          color: AppTheme.accent,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Caja contenedora con efecto Glassmorphism
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: AppTheme.glassDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Conectar con Servidor Puente',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _hostController,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: 'IP del Servidor (Host)',
                            hintText: 'ej. http://192.168.1.15:3000',
                            prefixIcon: Icon(Icons.dns, color: AppTheme.accent),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _tokenController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Token de Seguridad (Opcional)',
                            hintText: 'Introduce tu token API',
                            prefixIcon: Icon(Icons.lock_outline, color: AppTheme.accent),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 20),
                        
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppTheme.error, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        ElevatedButton(
                          onPressed: _isLoading ? null : _connect,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('ESTABLECER ENLACE'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Asegúrate de que el backend NodeJS local esté activo y que compartan la misma red Wi-Fi o túnel.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
