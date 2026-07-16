// backend/middleware/authMiddleware.js
const jwt = require('jsonwebtoken');
const User = require('../models/User'); 

module.exports = async (req, res, next) => {
  // ============================================================
  // 1. CORS PRE-FLIGHT BYPASS
  // ============================================================
  // Browsers send an OPTIONS request before the actual request.
  // These pre-flight requests do NOT contain the Authorization header.
  if (req.method === 'OPTIONS') {
    return next();
  }

  try {
    // ============================================================
    // 2. HEADER EXTRACTION
    // ============================================================
    const authHeader = req.headers.authorization || req.headers.Authorization;

    // DEBUG: Uncomment the line below to see incoming headers in your VPS logs (pm2 logs)
    // console.log(`[AUTH DEBUG] Path: ${req.originalUrl} | Header: ${authHeader ? 'Received' : 'MISSING'}`);

    if (!authHeader) {
      return res.status(401).json({
        success: false,
        message: 'Authorization header missing',
      });
    }

    const [scheme, token] = authHeader.split(' ');

    if (scheme !== 'Bearer' || !token) {
      return res.status(401).json({
        success: false,
        message: 'Invalid authorization format. Use: Bearer <token>',
      });
    }

    // ============================================================
    // 3. JWT VERIFICATION
    // ================= scheme.token
    if (!process.env.JWT_SECRET) {
      console.error('CRITICAL: JWT_SECRET environment variable is not configured on VPS.');
      return res.status(500).json({
        success: false,
        message: 'Server configuration error',
      });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // ============================================================
    // 4. DATABASE VALIDATION (REAL-TIME SECURITY)
    // ============================================================
    // Logic: Ensure the user still exists and hasn't been banned/deactivated.
    const user = await User.findById(decoded.id).select('_id isApproved role');

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'This account no longer exists.',
        code: 'USER_DELETED'
      });
    }

    if (!user.isApproved) {
      return res.status(403).json({
        success: false,
        message: 'Your account is currently suspended. Please contact support.',
        code: 'USER_BANNED'
      });
    }

    // Attach decoded data to request object for use in controllers
    req.user = decoded;

    return next();

  } catch (error) {
    console.error('authMiddleware error:', error.message);

    // Explicit error categorization for better Frontend feedback
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        message: 'Your session has expired. Please login again.',
        code: 'TOKEN_EXPIRED'
      });
    }

    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        success: false,
        message: 'Security token is invalid or malformed.',
        code: 'INVALID_TOKEN'
      });
    }

    return res.status(401).json({
      success: false,
      message: 'Authentication failed',
    });
  }
};