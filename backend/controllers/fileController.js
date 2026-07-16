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

        // 3. STREAMING LOGIC
        // Using ReadStream for high-performance delivery of videos and large project files.
        const stat = fs.statSync(filePath);
        const fileSize = stat.size;
        const range = req.headers.range;

        // Logic: Support for Video/Media Streaming (Partial Content)
        if (range) {
            const parts = range.replace(/bytes=/, "").split("-");
            const start = parseInt(parts[0], 10);
            const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
            
            if (start >= fileSize) {
                res.status(416).send('Requested range not satisfiable\n' + start + ' >= ' + fileSize);
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
            // Logic: Standard file delivery
            const head = {
                'Content-Length': fileSize,
                'Content-Type': 'application/octet-stream', // Flutter/Browser will identify via filename extension
                'Content-Disposition': `attachment; filename="${filename}"`
            };
            res.writeHead(200, head);
            fs.createReadStream(filePath).pipe(res);
        }
    } catch (error) {
        console.error("Critical File Streaming Error:", error);
        res.status(500).json({ success: false, message: "Internal server error during file retrieval." });
    }
};