import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';

class TaskDetailScreen extends StatefulWidget {
  final ApiClient client;
  final String taskId;
  final String taskTitle;

  const TaskDetailScreen({
    super.key,
    required this.client,
    required this.taskId,
    required this.taskTitle,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final List<Map<String, dynamic>> _logs = [];
  final ScrollController _scrollController = ScrollController();
  final _feedbackController = TextEditingController();
  bool _isWaitingFeedback = false;
  bool _sendingFeedback = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialLogs();
    
    // Escuchar deltas por el WebSocket
    widget.client.wsStream.listen((msg) {
      if (!mounted) return;
      if (msg['type'] == 'log_stream') {
        final log = msg['log'];
        setState(() {
          _logs.add({
            'content': log['content'],
            'level': log['level'],
            'stepIndex': log['stepIndex'],
          });
        });
        _scrollToBottom();
      } else if (msg['type'] == 'tasks_update') {
        final tasks = msg['tasks'] as List<dynamic>;
        final currentTask = tasks.firstWhere((t) => t['id'] == widget.taskId, orElse: () => null);
        if (currentTask != null) {
          setState(() {
            _isWaitingFeedback = currentTask['status'] == 'waiting_feedback';
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialLogs() async {
    try {
      final logs = await widget.client.getLogs();
      setState(() {
        _logs.addAll(logs.cast<Map<String, dynamic>>());
      });
      _scrollToBottom();
    } catch (_) {
      // Manejar error de carga inicial
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendFeedback() async {
    final text = _feedbackController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _sendingFeedback = true;
    });

    final success = await widget.client.sendFeedback(widget.taskId, text);
    if (success) {
      _feedbackController.clear();
      setState(() {
        _isWaitingFeedback = false;
        _sendingFeedback = false;
        _logs.add({
          'content': '>>> [Feedback enviado]: $text',
          'level': 'info',
          'stepIndex': 999
        });
      });
      _scrollToBottom();
    } else {
      setState(() {
        _sendingFeedback = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar feedback al servidor')),
        );
      }
    }
  }

  Color _getLogLevelColor(String level) {
    switch (level) {
      case 'error':
        return AppTheme.error;
      case 'warning':
        return AppTheme.warning;
      default:
        return AppTheme.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.taskTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('ID: ${widget.taskId}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Consola de Logs (Fondo negro terminal)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.terminalBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        'Esperando logs de ejecución...',
                        style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'monospace'),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        final step = log['stepIndex'] != null ? '[Step ${log['stepIndex']}] ' : '';
                        final content = log['content'] ?? '';
                        final level = log['level'] ?? 'info';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Text(
                            '$step$content',
                            style: TextStyle(
                              color: _getLogLevelColor(level),
                              fontFamily: 'monospace',
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          
          // Panel de Feedback interactivo (se expande solo si se requiere aprobación)
          if (_isWaitingFeedback) _buildFeedbackPanel(),
        ],
      ),
    );
  }

  Widget _buildFeedbackPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.warning),
              ),
              const SizedBox(width: 8),
              const Text(
                'EL AGENTE REQUIERE APROBACIÓN O INSTRUCCIONES',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.warning),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _feedbackController,
                  decoration: const InputDecoration(
                    hintText: 'Ej. "Procede con el plan", "Cancela el paso 2"',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _sendingFeedback ? null : _sendFeedback,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  backgroundColor: AppTheme.success,
                ),
                child: _sendingFeedback
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
              )
            ],
          ),
        ],
      ),
    );
  }
}
