// backend/controllers/fileController.js
const path = require('path');
const fs = require('fs');
const Task = require('../models/Task');
const User = require('../models/User');

/**
 * Validates if the current user has the right to access a specific file.
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
            { $or: [{ student: user.id }, { client: user.id }] },
            { $or: [
                { "submission.files.url": { $regex: filename } },
                { "submission.fileUrl": { $regex: filename } },
                { "attachments": { $regex: filename } }
            ]}
        ]
    });

    return !!task;
};

/**
 * Standard response for Multer uploads.
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
 * Provides authenticated handshakes for private VPS storage.
 */
exports.streamFile = async (req, res) => {
    try {
        const { filename } = req.params;
        const user = req.user; 

        if (!user) {
            return res.status(401).json({ success: false, message: "Authentication required." });
        }

        // 1. SECURITY CHECK
        const isAuthorized = await checkFileAuthorization(user, filename);
        if (!isAuthorized) {
            return res.status(403).json({ 
                success: false, 
                message: "Access Denied: You are not authorized to view this project file." 
            });
        }

        const filePath = path.join(__dirname, '../../storage/vault', filename);

        // 2. EXISTENCE CHECK
        if (!fs.existsSync(filePath)) {
            return res.status(404).json({ success: false, message: "File missing in secure vault." });
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

        // Support for Video/Media Streaming (Partial Content)
        if (range) {
            const parts = range.replace(/bytes=/, "").split("-");
            const start = parseInt(parts[0], 10);
            const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
            
            if (start >= fileSize) {
                res.status(416).send('Range not satisfiable');
                return;
            }
            
            const chunksize = (end - start) + 1;
            const file = fs.createReadStream(filePath, { start, end });
            const head = {
                'Content-Range': `bytes ${start}-${end}/${fileSize}`,
                'Accept-Ranges': 'bytes',
                'Content-Length': chunksize,
                'Content-Type': 'application/octet-stream',
            };
            
            res.writeHead(206, head);
            file.pipe(res);
        } else {
            // ============================================================
            // FIX: EXPOSE HEADERS FOR FLUTTER HANDSHAKE
            // ============================================================
            const head = {
                'Content-Length': fileSize,
                'Content-Type': contentType,
                'Access-Control-Expose-Headers': 'Content-Type, Content-Length',
                'Content-Disposition': `inline; filename="${filename}"`
            };
            res.writeHead(200, head);
            fs.createReadStream(filePath).pipe(res);
        }
    } catch (error) {
        console.error("Vault Stream Error:", error);
        res.status(500).json({ success: false, message: "Internal server error during file retrieval." });
    }
};