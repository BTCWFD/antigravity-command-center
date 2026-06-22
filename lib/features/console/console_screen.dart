import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';

class ConsoleScreen extends StatefulWidget {
  final ApiClient client;

  const ConsoleScreen({super.key, required this.client});

  @override
  State<ConsoleScreen> createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends State<ConsoleScreen> {
  final List<String> _commandHistory = [];
  final _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _commandHistory.add('=== Terminal de Enlace Antigravity iniciada ===');
    
    // Escuchar el websocket para imprimir cualquier log generado
    widget.client.wsStream.listen((msg) {
      if (!mounted) return;
      if (msg['type'] == 'log_stream') {
        final log = msg['log'];
        setState(() {
          _commandHistory.add('>>> ${log['content']}');
        });
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendCommand() async {
    final cmd = _inputController.text.trim();
    if (cmd.isEmpty) return;

    setState(() {
      _isSending = true;
      _commandHistory.add('\$ $cmd');
    });
    _inputController.clear();
    _scrollToBottom();

    final success = await widget.client.sendCommand(cmd);
    
    setState(() {
      _isSending = false;
      if (success) {
        _commandHistory.add('>>> Comando enviado al enjambre de subagentes...');
      } else {
        _commandHistory.add('ERROR: No se pudo enviar el comando. Revisa la red.');
      }
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consola General', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Consola Terminal
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.terminalBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                itemCount: _commandHistory.length,
                itemBuilder: (context, index) {
                  final line = _commandHistory[index];
                  Color color = AppTheme.textPrimary;
                  if (line.startsWith('\$')) {
                    color = AppTheme.primary;
                  } else if (line.startsWith('ERROR')) {
                    color = AppTheme.error;
                  } else if (line.startsWith('===')) {
                    color = AppTheme.accent;
                  } else if (line.startsWith('>>>')) {
                    color = AppTheme.success;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Text(
                      line,
                      style: TextStyle(
                        color: color,
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
          
          // Campo de entrada
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: const InputDecoration(
                      hintText: 'Escribe una instrucción para el enjambre...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => _sendCommand(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isSending ? null : _sendCommand,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    backgroundColor: AppTheme.primary,
                  ),
                  child: _isSending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
