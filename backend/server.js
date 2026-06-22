import express from 'express';
import { createServer } from 'http';
import { WebSocketServer, WebSocket } from 'ws';
import cors from 'cors';
import fs from 'fs';
import path from 'path';
import os from 'os';
import chokidar from 'chokidar';

const app = express();
const port = process.env.PORT || 3050;
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

const ANTIGRAVITY_ROOT = path.join(os.homedir(), '.gemini', 'antigravity');
const BRAIN_DIR = path.join(ANTIGRAVITY_ROOT, 'brain');

let activeConversationId = '';
let transcriptWatcher = null;
let taskWatcher = null;

// Encontrar la conversación activa más reciente
function getMostRecentConversation() {
  try {
    if (!fs.existsSync(BRAIN_DIR)) {
      return '';
    }
    const dirs = fs.readdirSync(BRAIN_DIR)
      .map(name => {
        const fullPath = path.join(BRAIN_DIR, name);
        return { name, stat: fs.statSync(fullPath) };
      })
      .filter(item => item.stat.isDirectory() && !nameStartsWithDot(item.name))
      .sort((a, b) => b.stat.mtimeMs - a.stat.mtimeMs);

    return dirs.length > 0 ? dirs[0].name : '';
  } catch (error) {
    console.error('Error al escanear directorio brain:', error);
    return '';
  }
}

function nameStartsWithDot(name) {
  return name.startsWith('.');
}

// Inicializar la conversación activa
activeConversationId = getMostRecentConversation();
console.log(`Conversación activa detectada: ${activeConversationId}`);

// Buscar periódicamente si hay una nueva conversación activa si no hay ninguna
if (!activeConversationId) {
  const interval = setInterval(() => {
    activeConversationId = getMostRecentConversation();
    if (activeConversationId) {
      console.log(`Conversación activa iniciada dinámicamente: ${activeConversationId}`);
      setupWatchers();
      clearInterval(interval);
    }
  }, 5000);
}

// Websocket Clients
const wssClients = new Set();

// Parsear tareas de task.md
function parseTaskMd(conversationId) {
  if (!conversationId) return [];
  const filePath = path.join(BRAIN_DIR, conversationId, 'task.md');
  if (!fs.existsSync(filePath)) {
    return [];
  }
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n');
    const tasks = [];
    let idCounter = 1;

    for (let line of lines) {
      const trimmed = line.trim();
      if (trimmed.startsWith('- `[ ]`')) {
        tasks.push({
          id: `t_${idCounter++}`,
          title: trimmed.substring(7).trim(),
          status: 'idle',
          progress: 0.0
        });
      } else if (trimmed.startsWith('- `[/]`')) {
        tasks.push({
          id: `t_${idCounter++}`,
          title: trimmed.substring(7).trim(),
          status: 'running',
          progress: 0.5
        });
      } else if (trimmed.startsWith('- `[x]`')) {
        tasks.push({
          id: `t_${idCounter++}`,
          title: trimmed.substring(7).trim(),
          status: 'completed',
          progress: 1.0
        });
      }
    }
    return tasks;
  } catch (error) {
    console.error('Error leyendo task.md:', error);
    return [];
  }
}

// Configurar Watchers de Archivos
function setupWatchers() {
  if (transcriptWatcher) transcriptWatcher.close();
  if (taskWatcher) taskWatcher.close();

  if (!activeConversationId) return;

  const conversationPath = path.join(BRAIN_DIR, activeConversationId);
  const transcriptPath = path.join(conversationPath, '.system_generated', 'logs', 'transcript.jsonl');
  const taskPath = path.join(conversationPath, 'task.md');

  // Watch transcript.jsonl
  if (fs.existsSync(transcriptPath)) {
    let fileSize = fs.statSync(transcriptPath).size;

    transcriptWatcher = chokidar.watch(transcriptPath, { usePolling: true, interval: 500 });
    transcriptWatcher.on('change', (filePath) => {
      try {
        const stats = fs.statSync(filePath);
        if (stats.size < fileSize) {
          fileSize = stats.size; // truncado o rotado
          return;
        }
        if (stats.size === fileSize) return;

        const stream = fs.createReadStream(filePath, {
          encoding: 'utf8',
          start: fileSize,
          end: stats.size
        });

        let data = '';
        stream.on('data', chunk => { data += chunk; });
        stream.on('end', () => {
          fileSize = stats.size;
          const lines = data.split('\n').filter(l => l.trim().length > 0);
          for (let line of lines) {
            try {
              const logObj = JSON.parse(line);
              broadcast({
                type: 'log_stream',
                conversationId: activeConversationId,
                log: {
                  content: logObj.content || JSON.stringify(logObj.tool_calls) || 'Acción del Agente',
                  level: logObj.status === 'ERROR' ? 'error' : 'info',
                  timestamp: Date.now(),
                  stepIndex: logObj.step_index
                }
              });
            } catch (e) {
              // No es un json válido o línea incompleta
            }
          }
        });
      } catch (err) {
        console.error('Error leyendo deltas de transcript:', err);
      }
    });
  }

  // Watch task.md
  if (fs.existsSync(taskPath)) {
    taskWatcher = chokidar.watch(taskPath, { usePolling: true, interval: 1000 });
    taskWatcher.on('change', () => {
      const tasks = parseTaskMd(activeConversationId);
      broadcast({
        type: 'tasks_update',
        conversationId: activeConversationId,
        tasks
      });
    });
  }
}

// Setup inicial
if (activeConversationId) {
  setupWatchers();
}

function broadcast(msg) {
  const payload = JSON.stringify(msg);
  for (let client of wssClients) {
    if (client.readyState === WebSocket.OPEN) {
      client.send(payload);
    }
  }
}

// === Endpoints REST ===

// 1. Estado global
app.get('/api/status', (req, res) => {
  const tasks = parseTaskMd(activeConversationId);
  const runningCount = tasks.filter(t => t.status === 'running').length;
  const completedCount = tasks.filter(t => t.status === 'completed').length;

  res.json({
    status: runningCount > 0 ? 'running' : 'idle',
    activeConversationId,
    metrics: {
      totalTasks: tasks.length,
      completedTasks: completedCount,
      runningTasks: runningCount,
      cpuUsage: '12%', // Mock
      memoryUsage: '344 MB' // Mock
    }
  });
});

// 2. Lista de conversaciones disponibles
app.get('/api/conversations', (req, res) => {
  try {
    if (!fs.existsSync(BRAIN_DIR)) {
      return res.json([]);
    }
    const conversations = fs.readdirSync(BRAIN_DIR)
      .map(name => {
        const fullPath = path.join(BRAIN_DIR, name);
        const stat = fs.statSync(fullPath);
        return { id: name, lastModified: stat.mtime };
      })
      .filter(item => fs.statSync(path.join(BRAIN_DIR, item.id)).isDirectory() && !item.id.startsWith('.'))
      .sort((a, b) => b.lastModified - a.lastModified);

    res.json(conversations);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 3. Seleccionar conversación
app.post('/api/conversations/select', (req, res) => {
  const { conversationId } = req.body;
  if (!conversationId) {
    return res.status(400).json({ error: 'Falta conversationId' });
  }
  const fullPath = path.join(BRAIN_DIR, conversationId);
  if (!fs.existsSync(fullPath) || !fs.statSync(fullPath).isDirectory()) {
    return res.status(404).json({ error: 'Conversación no encontrada' });
  }

  activeConversationId = conversationId;
  setupWatchers();
  console.log(`Cambio manual de conversación activa a: ${activeConversationId}`);
  res.json({ success: true, activeConversationId });
});

// 4. Lista de tareas de la conversación activa
app.get('/api/tasks', (req, res) => {
  const tasks = parseTaskMd(activeConversationId);
  res.json(tasks);
});

// 5. Historial completo de logs (lectura inicial de transcript.jsonl)
app.get('/api/tasks/logs', (req, res) => {
  if (!activeConversationId) {
    return res.json([]);
  }
  const transcriptPath = path.join(BRAIN_DIR, activeConversationId, '.system_generated', 'logs', 'transcript.jsonl');
  if (!fs.existsSync(transcriptPath)) {
    return res.json([]);
  }
  try {
    const content = fs.readFileSync(transcriptPath, 'utf8');
    const lines = content.split('\n').filter(l => l.trim().length > 0);
    const logs = lines.map((line, idx) => {
      try {
        const logObj = JSON.parse(line);
        return {
          id: idx,
          content: logObj.content || JSON.stringify(logObj.tool_calls) || 'Paso del Agente',
          level: logObj.status === 'ERROR' ? 'error' : 'info',
          timestamp: Date.now(), // Fallback
          stepIndex: logObj.step_index
        };
      } catch (e) {
        return null;
      }
    }).filter(l => l !== null);

    res.json(logs);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 6. Enviar comandos rápidos
app.post('/api/command', (req, res) => {
  const { command } = req.body;
  console.log(`Comando recibido de la app móvil: ${command}`);
  // Aquí se podrían inyectar comandos directamente en el transcriptor o cola de entrada si existiese.
  // De momento simulamos la recepción e informamos por consola local.
  broadcast({
    type: 'log_stream',
    conversationId: activeConversationId,
    log: {
      content: `[Móvil] Comando enviado: "${command}"`,
      level: 'info',
      timestamp: Date.now(),
      stepIndex: 999
    }
  });
  res.json({ success: true, message: 'Comando recibido en el servidor puente' });
});

// 7. Listar artefactos (Markdown)
app.get('/api/artifacts', (req, res) => {
  if (!activeConversationId) return res.json([]);
  const dirPath = path.join(BRAIN_DIR, activeConversationId);
  try {
    const files = fs.readdirSync(dirPath)
      .filter(file => file.endsWith('.md'))
      .map(file => ({
        id: file,
        name: file,
        filepath: path.join(dirPath, file),
        updatedAt: fs.statSync(path.join(dirPath, file)).mtime
      }));
    res.json(files);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// 8. Leer contenido de un artefacto
app.get('/api/artifacts/:id', (req, res) => {
  if (!activeConversationId) return res.status(400).json({ error: 'No active conversation' });
  const fileId = req.params.id;
  const filePath = path.join(BRAIN_DIR, activeConversationId, fileId);

  // Validación de seguridad para evitar saltarse directorios
  if (!filePath.startsWith(path.join(BRAIN_DIR, activeConversationId))) {
    return res.status(403).json({ error: 'Acceso no permitido' });
  }

  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: 'Artefacto no encontrado' });
  }
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    res.json({ id: fileId, content });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// === Configuración Servidor HTTP & WebSocket ===
const server = createServer(app);
const wss = new WebSocketServer({ server });

wss.on('connection', (ws) => {
  console.log('App móvil conectada vía WebSockets');
  wssClients.add(ws);

  // Enviar estado inicial y lista de tareas
  const tasks = parseTaskMd(activeConversationId);
  ws.send(JSON.stringify({
    type: 'init',
    activeConversationId,
    tasks
  }));

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      if (data.type === 'ping') {
        ws.send(JSON.stringify({ type: 'pong' }));
      }
    } catch (e) {
      console.error('Error parseando mensaje WS recibido:', e);
    }
  });

  ws.on('close', () => {
    console.log('App móvil desconectada de WebSockets');
    wssClients.delete(ws);
  });
});

server.listen(port, '0.0.0.0', () => {
  console.log(`Servidor puente de Antigravity corriendo en:`);
  console.log(`- Local: http://localhost:${port}`);
  console.log(`- Red:   http://0.0.0.0:${port}`);
});
