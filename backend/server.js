// backend/server.js
const express = require('express');
const cors = require('cors');
const http = require('http'); 
const { Server } = require('socket.io'); 
const path = require('path'); // Required for serving frontend build
require('dotenv').config();

const connectDB = require('./config/db');

const app = express();
const server = http.createServer(app); 

// =============================================================================
// 1. GLOBAL CORS CONFIGURATION (CRITICAL FIX)
// =============================================================================
const corsOptions = {
  origin: ["https://skilern.com", "https://api.skilern.com"],
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization", "Accept", "X-Requested-With"],
  credentials: true,
  preflightContinue: false,
  optionsSuccessStatus: 204
};

// Apply CORS middleware immediately
app.use(cors(corsOptions));

// Explicitly handle pre-flight OPTIONS requests for all routes
app.options('*', cors(corsOptions));

// =============================================================================
// 2. GHOST SIGNATURE MIDDLEWARE (SECRET DEV MARK)
// =============================================================================
app.use((req, res, next) => {
  // Invisible logic: Adds a custom hex header to every response
  // 42 68... is Hex for "Bhavesh Balaram"
  res.setHeader('X-Powered-By-Engine', 'SK-CORE-V1');
  res.setHeader('X-Context-Signature', '42 68 61 76 65 73 68 20 42 61 6c 61 72 61 6d');
  next();
});

// =============================================================================
// 3. REAL-TIME ENGINE (SOCKET.IO)
// =============================================================================
const io = new Server(server, {
  cors: corsOptions
});

app.set('socketio', io);

io.on('connection', (socket) => {
  console.log('A user connected:', socket.id);

  socket.on('join_task', (taskId) => {
    socket.join(taskId);
    console.log(`User joined task room: ${taskId}`);
  });

  socket.on('join_user', (userId) => {
    socket.join(userId);
    console.log(`User joined private room: ${userId}`);
  });

  socket.on('disconnect', () => {
    console.log('User disconnected');
  });
});

/*
=====================================
4. DATA PARSERS
=====================================
*/
// Webhook must be raw for signature verification
app.use('/api/payments/webhook', express.raw({ type: 'application/json' }));

app.use(express.json({ limit: '15mb' }));
app.use(express.urlencoded({ extended: true, limit: '15mb' }));

/*
=====================================
SAFE ROUTE LOADER
=====================================
*/
function loadRoute(modulePath, label) {
  try {
    const loaded = require(modulePath);
    const candidate = loaded && typeof loaded === 'object' && loaded.default && typeof loaded.default === 'function' ? loaded.default : loaded;
    if (typeof candidate !== 'function') {
      throw new TypeError(`Route "${label}" is not a middleware function.`);
    }
    console.log(`Loaded route: ${label}`);
    return candidate;
  } catch (err) {
    console.error(`Failed to load route "${label}":`, err);
    throw err;
  }
}

/*
=====================================
5. API ROUTES
=====================================
*/
app.use('/api/notifications', loadRoute('./routes/stats', 'statsRoutes')); // Note: Check if paths match your files
const statsRoutes = loadRoute('./routes/stats', 'statsRoutes');
const authRoutes = loadRoute('./routes/auth', 'authRoutes');
const userRoutes = loadRoute('./routes/user', 'userRoutes');
const taskRoutes = loadRoute('./routes/tasks', 'taskRoutes');
const paymentRoutes = loadRoute('./routes/payments', 'paymentRoutes');
const messageRoutes = loadRoute('./routes/messages', 'messageRoutes');
const skillRoutes = loadRoute('./routes/skills', 'skillRoutes');
const adminRoutes = loadRoute('./routes/admin', 'adminRoutes');
const studentsRoutes = loadRoute('./routes/students', 'studentsRoutes');
const notificationsRoutes = loadRoute('./routes/notifications', 'notificationsRoutes');
const fileRoutes = loadRoute('./routes/files', 'fileRoutes');

app.use('/api/notifications', notificationsRoutes);
app.use('/api/stats', statsRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/tasks', taskRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api/skills', skillRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/students', studentsRoutes);
app.use('/api/files', fileRoutes);

/*
=====================================
6. FRONTEND HOSTING (VPS BUILD)
=====================================
*/
// Serve the static files from the Flutter build/web directory
app.use(express.static(path.join(__dirname, '../build/web')));

// Catch-all for SPA: Send all non-API requests to index.html
app.get(/^(?!\/api).*$/, (req, res) => {
  res.sendFile(path.join(__dirname, '../build/web/index.html'));
});

/*
=====================================
GLOBAL ERROR HANDLER
=====================================
*/
app.use((err, req, res, next) => {
  console.error('GLOBAL ERROR:', err.message);
  if (res.headersSent) return next(err);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal Server Error'
  });
});

/*
=====================================
SERVER LIFECYCLE
=====================================
*/
const PORT = Number(process.env.PORT) || 10000;
let activeServer = null;

async function startServer() {
  try {
    await connectDB();
    activeServer = server.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 Skilern Secure Node running on port ${PORT}`);
    });
  } catch (err) {
    console.error('Failed to start:', err);
    process.exit(1);
  }
}

async function shutdown(signal) {
  console.log(`${signal} received. Closing...`);
  if (activeServer) {
    activeServer.close(() => process.exit(0));
  } else {
    process.exit(0);
  }
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

startServer();

module.exports = app;