// backend/controllers/fileController.js
const path = require('path');
const fs = require('fs');
const Task = require('../models/Task');
const User = require('../models/User');

/**
 * Validates if the current user has the right to access a specific file.
 * Logic: 
 * 1. Admin has access to everything.
 * 2. If it's a Student ID, only that Student and Admin can see it.
 * 3. If it's a Task file, only the assigned Student and the Client can see it.
 */
const checkFileAuthorization = async (user, filename) => {
    // 1. ADMIN OVERRIDE
    if (user.role === 'admin') return true;

    // 2. IDENTITY PROOF CHECK
    // Logic: Users can only see their own ID cards
    const userWithId = await User.findOne({ 
        _id: user.id, 
        idCardUrl: { $regex: filename } 
    });
    if (userWithId) return true;

    // 3. TASK-RELATED FILE CHECK (Deliverables and Attachments)
    // Logic: User must be the Client or the Student for the task
    // and the filename must exist in the Task record.
    const task = await Task.findOne({
        $and: [
            // Permission scope: User must be part of the task
            { $or: [{ student: user.id }, { client: user.id }] },
            
            // Resource scope: Requested file must be linked to this task
            { $or: [
                // A: New Multi-file submission array
                { "submission.files.url": { $regex: filename } },
                
                // B: Legacy Single-file submission string
                { "submission.fileUrl": { $regex: filename } },
                
                // C: Project setup attachments (briefs, samples)
                { "attachments": { $regex: filename } }
            ]}
        ]
    });

    return !!task;
};

/**
 * Standard response for Multer uploads.
 * Used for both Registration IDs and Task Deliverables.
 */
exports.handleUploadResponse = (req, res) => {
    if (!req.file) {
        return res.status(400).json({ success: false, message: 'No file received' });
    }

    // Logic: We return only the filename. 
    // The frontend constructs the protected URL: /api/files/view/:filename
    res.json({
        success: true,
        filename: req.file.filename,
        originalName: req.file.originalname,
        mimeType: req.file.mimetype
    });
};

/**
 * SECURE FILE STREAMER
 * Provides authenticated handshakes for private VPS storage.
 * FIX: Explicit MIME mapping and Header Exposure for Flutter PDF/Image rendering.
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
        // Support for Video/Media Streaming (Partial Content)
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
            // This ensures the frontend can see the type and size
            // ============================================================
            const head = {
                'Content-Length': fileSize,
                'Content-Type': contentType,
                'Access-Control-Expose-Headers': 'Content-Type, Content-Length',
                'Content-Disposition': `inline; filename="${filename}"`,
                'Cache-Control': 'no-cache'
            };
            res.writeHead(200, head);
            
            // Using a clean ReadStream to prevent memory bottlenecks on VPS
            const stream = fs.createReadStream(filePath);
            stream.pipe(res);
        }
    } catch (error) {
        console.error("Critical File Streaming Error:", error);
        res.status(500).json({ success: false, message: "Internal server error during file retrieval." });
    }
};