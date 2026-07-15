// backend/routes/files.js
const express = require('express');
const router = express.Router();
const verifyJWT = require('../middleware/authMiddleware');
const upload = require('../middleware/upload');
const fileController = require('../controllers/fileController');

/**
 * POST /api/files/upload
 * PROTECTED: Requires JWT.
 * Used for task deliverables and project attachments once a user is logged in.
 */
router.post('/upload', verifyJWT, upload.single('file'), fileController.handleUploadResponse);

/**
 * POST /api/files/upload-registration
 * PUBLIC: No JWT required.
 * MODIFICATION: Created specifically for the Student Signup process.
 * Allows students to upload their ID Card proof to the VPS Vault without a token.
 */
router.post('/upload-registration', upload.single('file'), fileController.handleUploadResponse);

/**
 * GET /api/files/view/:filename
 * PROTECTED: Requires JWT + Permission Check.
 * Streams the file content securely. This ensures that even if a file was 
 * uploaded publicly, it can only be viewed by authorized roles (Admin/Student/Client).
 */
router.get('/view/:filename', verifyJWT, fileController.streamFile);

module.exports = router;