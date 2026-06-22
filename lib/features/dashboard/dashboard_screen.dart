import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../tasks/task_detail_screen.dart';
import '../console/console_screen.dart';
import '../artifacts/artifact_explorer_screen.dart';

class DashboardScreen extends StatefulWidget {
  final ApiClient client;

  const DashboardScreen({super.key, required this.client});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _agentStatus = 'Conectando...';
  String _activeConversationId = 'Desconocida';
  List<dynamic> _tasks = [];
  Map<String, dynamic> _metrics = {
    'totalTasks': 0,
    'completedTasks': 0,
    'runningTasks': 0,
    'cpuUsage': '0%',
    'memoryUsage': '0 MB'
  };
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    widget.client.connectWebSocket();
    widget.client.wsStream.listen(_handleWebSocketMessage);
  }

  @override
  void dispose() {
    widget.client.disconnectWebSocket();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    try {
      final status = await widget.client.getStatus();
      final tasks = await widget.client.getTasks();
      
      setState(() {
        _isConnected = true;
        _agentStatus = status['status'] == 'running' ? 'Ejecutando' : 'En Espera';
        _activeConversationId = status['activeConversationId'] ?? 'Ninguna';
        _metrics = status['metrics'] ?? _metrics;
        _tasks = tasks;
      });
    } catch (_) {
      setState(() {
        _isConnected = false;
        _agentStatus = 'Desconectado';
      });
    }
  }

  void _handleWebSocketMessage(Map<String, dynamic> msg) {
    if (!mounted) return;

    setState(() {
      _isConnected = true;
    });

    if (msg['type'] == 'init') {
      setState(() {
        _activeConversationId = msg['activeConversationId'] ?? _activeConversationId;
        _tasks = msg['tasks'] ?? [];
        _updateMetricsFromTasks();
      });
    } else if (msg['type'] == 'tasks_update') {
      setState(() {
        _tasks = msg['tasks'] ?? [];
        _updateMetricsFromTasks();
      });
    } else if (msg['type'] == 'status_update') {
      setState(() {
        _agentStatus = msg['status'] == 'running' ? 'Ejecutando' : 'En Espera';
      });
    } else if (msg['type'] == 'connection_closed' || msg['type'] == 'connection_error') {
      setState(() {
        _isConnected = false;
        _agentStatus = 'Reconectando...';
      });
    }
  }

  void _updateMetricsFromTasks() {
    final runningCount = _tasks.filter(t => t['status'] == 'running').length;
    final completedCount = _tasks.filter(t => t['status'] == 'completed').length;
    
    setState(() {
      _metrics['totalTasks'] = _tasks.length;
      _metrics['completedTasks'] = completedCount;
      _metrics['runningTasks'] = runningCount;
      _metrics['cpuUsage'] = runningCount > 0 ? '45%' : '8%';
      _metrics['memoryUsage'] = runningCount > 0 ? '512 MB' : '280 MB';
      _agentStatus = runningCount > 0 ? 'Ejecutando' : 'En Espera';
    });
  }

  Color _getStatusColor() {
    if (!_isConnected) return AppTheme.error;
    if (_agentStatus == 'Ejecutando') return AppTheme.success;
    return AppTheme.warning;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getStatusColor(),
                boxShadow: [
                  BoxShadow(
                    color: _getStatusColor().withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                Text(
                  _isConnected ? 'Enlace En Línea' : 'Intento de reconexión...',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textPrimary),
            onPressed: _fetchInitialData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.error),
            onPressed: () async {
              await StorageService.clear();
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/connection');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Tarjeta de Estado de Conversación Activa
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.glassDecoration(
                color: AppTheme.surface.withOpacity(0.5),
                borderRadius: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CONVERSACIÓN ACTIVA',
                    style: TextStyle(fontSize: 10, color: AppTheme.accent, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _activeConversationId,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniMetric('CPU', _metrics['cpuUsage']),
                      _buildMiniMetric('RAM', _metrics['memoryUsage']),
                      _buildMiniMetric('TAREAS', '${_metrics['completedTasks']}/${_metrics['totalTasks']}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'COLA DE TRABAJO (TASK.MD)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            
            // Listado de tareas
            Expanded(
              child: _tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.checklist_rounded, size: 64, color: AppTheme.textSecondary.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          const Text(
                            'No se encontraron tareas registradas',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        return _buildTaskItem(task);
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
    IconData icon;
    Color statusColor;

    switch (task['status']) {
      case 'completed':
        icon = Icons.check_circle;
        statusColor = AppTheme.success;
        break;
      case 'running':
        icon = Icons.hourglass_top_rounded;
        statusColor = AppTheme.accent;
        break;
      default:
        icon = Icons.radio_button_unchecked;
        statusColor = AppTheme.textSecondary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetailScreen(
                client: widget.client,
                taskId: task['id'],
                taskTitle: task['title'],
              ),
            ),
          );
        },
        leading: Icon(icon, color: statusColor),
        title: Text(
          task['title'],
          style: TextStyle(
            color: Colors.white,
            fontWeight: task['status'] == 'running' ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.dashboard_rounded, 'Dashboard', true, () {}),
          _buildNavItem(Icons.terminal_rounded, 'Terminal', false, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ConsoleScreen(client: widget.client)),
            );
          }),
          _buildNavItem(Icons.folder_copy_rounded, 'Archivos', false, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ArtifactExplorerScreen(client: widget.client)),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppTheme.accent : AppTheme.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? AppTheme.accent : AppTheme.textSecondary,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Extensión para simplificar el filtrado de listas en dart antiguo/básico
extension ListFilter<T> on List<T> {
  List<T> filter(bool Function(T element) test) {
    final result = <T>[];
    for (var element in this) {
      if (test(element)) {
        result.add(element);
      }
    }
    return result;
  }
}
