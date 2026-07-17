// backend/controllers/fileController.js
const path = require('path');
const fs = require('fs');
const Task = require('../models/Task');
const User = require('../models/User');

/**
 * Validates if the current user has the right to access a specific file.
 * Logic: 
 * 1. Admin has access to everything.
 * 2. Users can see their own identity documents.
 * 3. Students and Clients can see files linked to their specific tasks.
 */
const checkFileAuthorization = async (user, filename) => {
    // 1. ADMIN OVERRIDE
    if (user.role === 'admin') return true;

    // 2. IDENTITY PROOF CHECK
    const userWithId = await User.findOne({ 
        _id: user.id, 
        idCardUrl: { $regex: filename } 
    });
    if (userWithId) return true;

    // 3. TASK-RELATED FILE CHECK (Deliverables and Attachments)
    const task = await Task.findOne({
        $and: [
            // User must be either the assigned student or the client for the task
            { $or: [{ student: user.id }, { client: user.id }] },
            
            // The filename must exist in the database record for that task
            { $or: [
                // Check new multi-file array
                { "submission.files.url": { $regex: filename } },
                
                // Check legacy single-file string (for backwards compatibility)
                { "submission.fileUrl": { $regex: filename } },
                
                // Check initial task attachments
                { "attachments": { $regex: filename } }
            ]}
        ]
    });

    return !!task;
};

/**
 * Standard response for Multer uploads.
 * Returns the generated filename to the frontend.
 */
exports.handleUploadResponse = (req, res) => {
    if (!req.file) {
        return res.status(400).json({ success: false, message: 'No file received' });
    }

    res.json({
        success: true,
        filename: req.file.filename,
        originalName: req.file.originalname,
        mimeType: req.file.mimetype
    });
};

/**
 * SECURE FILE STREAMER
 * Provides authenticated binary handshakes for private VPS storage.
 * 
 * FIX APPLIED: 
 * 1. Explicit MIME Type mapping (Required for Flutter PDF Rendering).
 * 2. Access-Control-Expose-Headers (Allows Flutter to read metadata).
 * 3. ReadStream piping (Ensures clean binary delivery).
 */
exports.streamFile = async (req, res) => {
    try {
        const { filename } = req.params;
        const user = req.user; // Injected by verifyJWT middleware

        if (!user) {
            return res.status(401).json({ success: false, message: "Authentication required." });
        }

        // 1. SECURITY CHECK: Verify Ownership/Role for this specific file
        const isAuthorized = await checkFileAuthorization(user, filename);
        if (!isAuthorized) {
            return res.status(403).json({ 
                success: false, 
                message: "Access Denied: You are not authorized to view this project file." 
            });
        }

        // Define absolute path to the VPS Secure Vault
        const filePath = path.join(__dirname, '../../storage/vault', filename);

        // 2. EXISTENCE CHECK
        if (!fs.existsSync(filePath)) {
            console.error(`[Vault] File missing: ${filename}`);
            return res.status(404).json({ success: false, message: "The requested file no longer exists in the secure vault." });
        }

        const stat = fs.statSync(filePath);
        const fileSize = stat.size;
        const ext = path.extname(filename).toLowerCase();

        // ============================================================
        // FIX: EXPLICIT MIME-TYPE MAPPING (CRITICAL FOR PDF PREVIEW)
        // This tells the browser/Flutter exactly what type of data is coming.
        // ============================================================
        let contentType = 'application/octet-stream';
        if (ext === '.pdf') contentType = 'application/pdf';
        else if (ext === '.jpg' || ext === '.jpeg') contentType = 'image/jpeg';
        else if (ext === '.png') contentType = 'image/png';
        else if (ext === '.gif') contentType = 'image/gif';
        else if (ext === '.txt') contentType = 'text/plain';
        else if (ext === '.csv') contentType = 'text/csv';

        const range = req.headers.range;

        // 3. STREAMING LOGIC
        // Support for Video/Media Streaming (Partial Content / Byte Ranges)
        if (range) {
            const parts = range.replace(/bytes=/, "").split("-");
            const start = parseInt(parts[0], 10);
            const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
            
            if (start >= fileSize) {
                res.status(416).send('Requested range not satisfiable');
                return;
            }
            
            const chunksize = (end - start) + 1;
            const file = fs.createReadStream(filePath, { start, end });
            const head = {
                'Content-Range': `bytes ${start}-${end}/${fileSize}`,
                'Accept-Ranges': 'bytes',
                'Content-Length': chunksize,
                'Content-Type': contentType,
            };
            
            res.writeHead(206, head);
            file.pipe(res);
        } else {
            // ============================================================
            // FIX: EXPOSE HEADERS FOR FLUTTER/BROWSER HANDSHAKE
            // Without this, the Flutter app cannot "see" the Content-Type
            // across the CORS boundary, which causes rendering to fail.
            // ============================================================
            const head = {
                'Content-Length': fileSize,
                'Content-Type': contentType,
                'Access-Control-Expose-Headers': 'Content-Type, Content-Length',
                'Content-Disposition': `inline; filename="${filename}"`,
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Pragma': 'no-cache',
                'Expires': '0'
            };
            
            res.writeHead(200, head);
            
            // Using a clean ReadStream to pipe binary data directly to the response
            const stream = fs.createReadStream(filePath);
            stream.on('error', (err) => {
                console.error("Stream pipe error:", err);
                if (!res.headersSent) res.status(500).end();
            });
            stream.pipe(res);
        }
    } catch (error) {
        console.error("Critical Vault Stream Error:", error);
        if (!res.headersSent) {
            res.status(500).json({ success: false, message: "Internal server error during file retrieval." });
        }
    }
};