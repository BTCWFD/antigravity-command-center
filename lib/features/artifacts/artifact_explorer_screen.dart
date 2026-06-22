import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';
import 'package:intl/intl.dart';

class ArtifactExplorerScreen extends StatefulWidget {
  final ApiClient client;

  const ArtifactExplorerScreen({super.key, required this.client});

  @override
  State<ArtifactExplorerScreen> createState() => _ArtifactExplorerScreenState();
}

class _ArtifactExplorerScreenState extends State<ArtifactExplorerScreen> {
  List<dynamic> _artifacts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchArtifacts();
  }

  Future<void> _fetchArtifacts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await widget.client.getArtifacts();
      setState(() {
        _artifacts = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Fallo al cargar artefactos del servidor';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visor de Artefactos', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchArtifacts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: AppTheme.error)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchArtifacts,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _artifacts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.article_outlined, size: 64, color: AppTheme.textSecondary.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          const Text(
                            'No se encontraron archivos Markdown',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _artifacts.length,
                      itemBuilder: (context, index) {
                        final art = _artifacts[index];
                        final name = art['name'] ?? 'Archivo';
                        final updated = art['updatedAt'] != null 
                            ? DateTime.parse(art['updatedAt'])
                            : DateTime.now();
                        final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(updated);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ArtifactViewerScreen(
                                    client: widget.client,
                                    artifactId: art['id'],
                                    artifactName: name,
                                  ),
                                ),
                              );
                            },
                            leading: const Icon(Icons.description_rounded, color: AppTheme.accent, size: 36),
                            title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text('Modificado: $formattedDate', style: const TextStyle(fontSize: 12)),
                            trailing: const Icon(Icons.open_in_new, color: AppTheme.textSecondary, size: 20),
                          ),
                        );
                      },
                    ),
    );
  }
}

class ArtifactViewerScreen extends StatefulWidget {
  final ApiClient client;
  final String artifactId;
  final String artifactName;

  const ArtifactViewerScreen({
    super.key,
    required this.client,
    required this.artifactId,
    required this.artifactName,
  });

  @override
  State<ArtifactViewerScreen> createState() => _ArtifactViewerScreenState();
}

class _ArtifactViewerScreenState extends State<ArtifactViewerScreen> {
  String? _content;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchContent();
  }

  Future<void> _fetchContent() async {
    try {
      final res = await widget.client.getArtifactContent(widget.artifactId);
      setState(() {
        _content = res['content'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al leer el contenido del artefacto';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.artifactName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.error)))
              : Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Markdown(
                    data: _content ?? '',
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      h1: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      h2: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      h3: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      code: const TextStyle(
                        color: AppTheme.accent,
                        backgroundColor: AppTheme.terminalBg,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: AppTheme.terminalBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                    ),
                  ),
                ),
    );
  }
}
