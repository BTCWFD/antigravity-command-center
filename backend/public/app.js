// Antigravity Web Companion logic
document.addEventListener('DOMContentLoaded', () => {
  const statusDot = document.getElementById('statusDot');
  const statusText = document.getElementById('statusText');
  const activeConv = document.getElementById('activeConv');
  const cpuVal = document.getElementById('cpuVal');
  const ramVal = document.getElementById('ramVal');
  const tasksVal = document.getElementById('tasksVal');
  const doneVal = document.getElementById('doneVal');
  const taskList = document.getElementById('taskList');
  const terminalBody = document.getElementById('terminalBody');
  const cmdInput = document.getElementById('cmdInput');
  const cmdBtn = document.getElementById('cmdBtn');
  
  // Feedback panel elements
  const feedbackPanel = document.getElementById('feedbackPanel');
  const feedbackInput = document.getElementById('feedbackInput');
  const feedbackBtnApprove = document.getElementById('feedbackBtnApprove');
  const feedbackBtnSend = document.getElementById('feedbackBtnSend');

  let currentTaskId = '';
  let socket = null;

  // Renderizar iconos
  lucide.createIcons();

  // Función para agregar línea al terminal
  function appendLog(content, level = 'info', stepIndex = null) {
    const line = document.createElement('div');
    line.className = `log-line ${level}`;
    const stepStr = stepIndex !== null ? `[Step ${stepIndex}] ` : '';
    line.textContent = `${stepStr}${content}`;
    terminalBody.appendChild(line);
    
    // Auto-scroll
    terminalBody.scrollTop = terminalBody.scrollHeight;

    // Pruning logs in web browser memory too
    if (terminalBody.childElementCount > 1000) {
      terminalBody.removeChild(terminalBody.firstChild);
    }
  }

  // Cargar datos iniciales vía REST
  async function loadInitialData() {
    try {
      const statusRes = await fetch('/api/status');
      const status = await statusRes.json();
      
      activeConv.textContent = status.activeConversationId || 'Ninguna';
      cpuVal.textContent = status.metrics.cpuUsage;
      ramVal.textContent = status.metrics.memoryUsage;
      
      const tasksRes = await fetch('/api/tasks');
      const tasks = await tasksRes.json();
      renderTasks(tasks);

      const logsRes = await fetch('/api/tasks/logs');
      const logs = await logsRes.json();
      terminalBody.innerHTML = ''; // Limpiar logs de carga estática
      logs.forEach(log => {
        appendLog(log.content, log.level, log.stepIndex);
      });
      
      statusDot.className = 'status-dot online';
      statusText.textContent = status.status === 'running' ? 'Ejecutando' : 'En Espera';
    } catch (err) {
      statusDot.className = 'status-dot offline';
      statusText.textContent = 'Servidor sin respuesta';
      appendLog(`Error conectando con la API: ${err.message}`, 'error');
    }
  }

  // Renderizar lista de tareas en DOM
  function renderTasks(tasks) {
    taskList.innerHTML = '';
    tasksVal.textContent = tasks.length;
    
    const completed = tasks.filter(t => t.status === 'completed').length;
    const running = tasks.filter(t => t.status === 'running');
    
    doneVal.textContent = completed;

    // Si hay alguna tarea activa pidiendo feedback
    const waitingTask = tasks.find(t => t.status === 'waiting_feedback');
    if (waitingTask) {
      currentTaskId = waitingTask.id;
      feedbackPanel.style.display = 'flex';
    } else {
      feedbackPanel.style.display = 'none';
    }

    tasks.forEach(task => {
      const item = document.createElement('div');
      item.className = 'task-item';
      
      let icon = 'circle';
      let iconClass = 'idle';
      if (task.status === 'completed') {
        icon = 'check-circle';
        iconClass = 'completed';
      } else if (task.status === 'running') {
        icon = 'loader';
        iconClass = 'running';
      } else if (task.status === 'waiting_feedback') {
        icon = 'help-circle';
        iconClass = 'warning';
      }

      item.innerHTML = `
        <i data-lucide="${icon}" class="task-icon ${iconClass}"></i>
        <span class="task-title">${task.title}</span>
        <i data-lucide="chevron-right" style="color: var(--text-secondary); width: 16px;"></i>
      `;
      taskList.appendChild(item);
    });

    lucide.createIcons();
  }

  // Conectar WebSocket
  function connectWebSocket() {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${window.location.host}/ws`;
    
    socket = new WebSocket(wsUrl);

    socket.onopen = () => {
      console.log('WebSocket conectado');
      statusDot.className = 'status-dot online';
    };

    socket.onmessage = (event) => {
      try {
        const msg = JSON.parse(event.data);
        if (msg.type === 'init') {
          activeConv.textContent = msg.activeConversationId || 'Ninguna';
          renderTasks(msg.tasks || []);
        } else if (msg.type === 'tasks_update') {
          renderTasks(msg.tasks || []);
        } else if (msg.type === 'log_stream') {
          appendLog(msg.log.content, msg.log.level, msg.log.stepIndex);
        } else if (msg.type === 'status_update') {
          statusText.textContent = msg.status === 'running' ? 'Ejecutando' : 'En Espera';
        }
      } catch (err) {
        console.error('Error parseando mensaje WebSocket:', err);
      }
    };

    socket.onclose = () => {
      console.log('WebSocket cerrado, reintentando...');
      statusDot.className = 'status-dot offline';
      statusText.textContent = 'Desconectado (Reintentando)';
      setTimeout(connectWebSocket, 5000);
    };

    socket.onerror = (err) => {
      console.error('Error en WebSocket:', err);
      socket.close();
    };
  }

  // Enviar comando general
  async function sendCommand() {
    const command = cmdInput.value.trim();
    if (!command) return;

    cmdInput.value = '';
    appendLog(`$ ${command}`, 'prompt');
    
    try {
      const responseRes = await fetch('/api/command', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ command })
      });
      const response = await responseRes.json();
      if (!response.success) {
        appendLog('ERROR: Servidor no procesó el comando.', 'error');
      }
    } catch (err) {
      appendLog(`Error enviando comando: ${err.message}`, 'error');
    }
  }

  // Enviar feedback / aprobación
  async function sendFeedback(text) {
    if (!currentTaskId || !text) return;
    
    feedbackPanel.style.display = 'none';
    appendLog(`>>> [Feedback enviado]: "${text}"`, 'success');

    try {
      const responseRes = await fetch(`/api/tasks/${currentTaskId}/feedback`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ feedback: text })
      });
      const response = await responseRes.json();
      if (!response.success) {
        appendLog('ERROR: Servidor no procesó la respuesta.', 'error');
      }
    } catch (err) {
      appendLog(`Error enviando respuesta: ${err.message}`, 'error');
    }
  }

  // Event Listeners
  cmdBtn.addEventListener('click', sendCommand);
  cmdInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') sendCommand();
  });

  feedbackBtnApprove.addEventListener('click', () => sendFeedback('Procede con el plan'));
  feedbackBtnSend.addEventListener('click', () => {
    const text = feedbackInput.value.trim();
    if (text) {
      sendFeedback(text);
      feedbackInput.value = '';
    }
  });

  // Lanzamiento inicial
  loadInitialData();
  connectWebSocket();
});
