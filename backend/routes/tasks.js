// backend/routes/tasks.js
const express = require('express');
const router = express.Router();
const Task = require('../models/Task');
const User = require('../models/User');
const Message = require('../models/Message');
const verifyJWT = require('../middleware/authMiddleware');
const taskController = require('../controllers/taskController'); 
const Joi = require('joi');

// =========================================================
// JOI SCHEMAS (SYNCHRONIZED WITH MULTI-FILE & OPTIONAL BUDGET)
// =========================================================

const createTaskSchema = Joi.object({
  title: Joi.string().min(3).max(200).required(),
  description: Joi.string().min(10).max(5000).required(),
  
  // Budget is optional during initial post (negotiated later)
  budget: Joi.number().min(0).allow(null, '').optional(), 
  
  deadline: Joi.date().required(),
  location: Joi.string().max(200).allow('', null),
  domain: Joi.string().max(200).allow('', null),
  requiredSkills: Joi.array().items(Joi.string().max(100)).default([]),
  company: Joi.string().max(200).allow('', null),
  
  // SUPPORT FOR ATTACHMENTS DURING CREATION
  attachments: Joi.array().items(Joi.string().uri()).default([]),
  attachmentNames: Joi.array().items(Joi.string()).default([]),
  
  clientAgreedToTerms: Joi.boolean().valid(true).required(),
});

const guestTaskSchema = Joi.object({
  title: Joi.string().min(3).max(200).required(),
  description: Joi.string().min(10).max(5000).required(),
  guestName: Joi.string().required(),
  guestMobile: Joi.string().required(),
  guestEmail: Joi.string().email().allow('', null),
  budget: Joi.number().min(0).allow(null, '').optional(),
  deadline: Joi.date().required(),
  domain: Joi.string().allow('', null),
  requiredSkills: Joi.array().items(Joi.string()).default([]),
});

const feedbackSchema = Joi.object({
  feedback: Joi.string().max(2000).allow('', null), 
  text: Joi.string().max(2000).allow('', null),
  score: Joi.number().integer().min(1).max(5).required(),
});

// =========================================================
// 1. DATA RETRIEVAL (DASHBOARD & WORKSPACE)
// =========================================================

/**
 * Provides dynamic filters based on existing DB entries
 */
router.get('/filters', verifyJWT, async (req, res) => {
    try {
        const [locations, domains] = await Promise.all([
            Task.distinct("location"),
            Task.distinct("domain")
        ]);
        res.json({
            locations: locations.filter(Boolean).sort(),
            domains: domains.filter(Boolean).sort()
        });
    } catch (err) {
        res.status(500).json({ message: "Failed to load project filters" });
    }
});

/**
 * Returns tasks actively assigned to the logged-in student
 * MODIFIED: Explicitly selects attachments and studentPayout
 */
router.get('/assigned', verifyJWT, async (req, res) => {
  try {
    const tasks = await Task.find({
      student: req.user.id,
      status: { $in: ['assigned', 'under_review', 'completed', 'declined'] },
    })
    .populate('client', 'name company location')
    // ============================================================
    // FIX: EXPLICITLY SELECT ATTACHMENTS & PAYOUT
    // This ensures students see the project brief and their specific earnings
    // ============================================================
    .select('+attachments +attachmentNames +studentPayout') 
    .sort({ updatedAt: -1 });
    
    res.json(tasks);
  } catch (err) { 
      res.status(500).json({ message: 'Error loading workspace' }); 
  }
});

/**
 * Returns task invitations (Pending Acceptance)
 */
router.get('/requests', verifyJWT, async (req, res) => {
  try {
    const requests = await Task.find({ 
      requestedStudent: req.user.id, 
      assignmentRequestStatus: 'request_sent' 
    }).populate('client', 'name company location');
    res.json(requests);
  } catch (err) { res.status(500).json({ message: 'Error loading invitations' }); }
});

/**
 * Aggregates tasks for the real-time chat inbox
 */
router.get('/chat-tasks', verifyJWT, async (req, res) => {
  try {
    const userId = req.user.id;
    const taskIds = await Message.distinct('task', { $or: [{ sender: userId }, { receiver: userId }] });
    const tasks = await Task.find({
      $or: [{ student: userId }, { requestedStudent: userId }, { _id: { $in: taskIds } }]
    }).populate('client', 'name company').sort({ updatedAt: -1 });
    res.json(tasks);
  } catch (err) { res.status(500).json({ message: 'Error loading chat list' }); }
});

/**
 * Returns tasks posted by the logged-in client
 */
router.get('/mine', verifyJWT, async (req, res) => {
  try {
    const tasks = await Task.find({ client: req.user.id })
      .select('+attachments +attachmentNames')
      .sort({ createdAt: -1 });
    res.json(tasks);
  } catch (err) { res.status(500).json({ message: 'Error loading tasks' }); }
});

// =========================================================
// 2. CREATION, UPDATE & SUBMISSION
// =========================================================

router.post('/create', verifyJWT, taskController.createTask);
router.post('/guest-create', taskController.createGuestTask);

/**
 * MODIFICATION: ADDED UPDATE ROUTE (Resolves 404 on Client Edit)
 */
router.post('/:id/update', verifyJWT, taskController.updateTask);

/**
 * MODIFICATION: SUBMIT WORK (Now handles multi-file array)
 */
router.post('/:id/submit', verifyJWT, taskController.submitWork);

// =========================================================
// 3. WORKFLOW ACTIONS
// =========================================================

/**
 * Transitions task from Invite -> Active
 */
router.post('/:id/accept-request', verifyJWT, async (req, res) => {
  try {
    const task = await Task.findById(req.params.id);
    if (!task || task.requestedStudent?.toString() !== req.user.id) {
      return res.status(404).json({ message: 'Invite not found' });
    }

    task.student = req.user.id;
    task.studentAgreedToTerms = true;
    task.status = 'assigned'; 
    task.assignedAt = new Date();
    task.requestedStudent = null;
    task.assignmentRequestStatus = null;

    await task.save();
    
    const io = req.app.get('socketio');
    if (io) {
        io.to('admin_room').emit('task_update', { taskId: task._id });
        io.to(`${task._id}_client`).emit('task_update', { taskId: task._id });
    }

    res.json({ message: 'Task assigned and active', task });
  } catch (err) { res.status(500).json({ message: 'Acceptance failed' }); }
});

/**
 * Approves student deliverables
 */
router.post('/:id/approve', verifyJWT, taskController.approveWork);

/**
 * MODIFICATION: Client requests revision (Triggers instruction box)
 */
router.post('/:id/decline', verifyJWT, taskController.declineWork);

/**
 * Final Feedback and Rating
 */
router.post('/:id/feedback', verifyJWT, async (req, res, next) => {
  const { error } = feedbackSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });
  return taskController.rateStudent(req, res);
});

// =========================================================
// 4. GENERAL RETRIEVAL & DELETION
// =========================================================

router.get('/:id', verifyJWT, async (req, res) => {
  try {
    const task = await Task.findById(req.params.id)
      .populate('client student')
      .select('+attachments +attachmentNames +studentPayout');
    if (!task) return res.status(404).json({ message: 'Task not found' });
    res.json(task);
  } catch (err) { res.status(404).json({ message: 'Not found' }); }
});

router.delete('/:id', verifyJWT, async (req, res) => {
  try {
    const task = await Task.findById(req.params.id);
    if (!task) return res.status(404).json({ message: 'Task not found' });
    if (task.client.toString() !== req.user.id) return res.status(403).json({ message: 'Denied' });
    
    await Task.deleteOne({ _id: req.params.id });
    res.json({ message: 'Task deleted' });
  } catch (err) { res.status(500).json({ message: 'Deletion failed' }); }
});

module.exports = router;