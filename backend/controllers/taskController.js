// backend/controllers/taskController.js
const Task = require('../models/Task');
const User = require('../models/User');
const Message = require('../models/Message'); 
const { sendNotification } = require('../utils/fcm'); 

/**
 * Global Normalization Helper
 * Standardizes Title Case for domains and skills
 */
function normalizeString(str) {
  if (!str || typeof str !== 'string') return '';
  return str
    .trim()
    .toLowerCase()
    .split(' ')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

/**
 * Global Real-time Broadcast Helper
 */
const emitUpdate = (req, room, event, data) => {
  const io = req.app.get('socketio');
  if (io) {
    io.to(room).emit(event, data);
    io.emit('admin_stats_update', { timestamp: new Date() });
  }
};

/**
 * CREATE TASK (Registered Client)
 */
exports.createTask = async (req, res) => {
  try {
    if (!req.user || req.user.role !== 'client') {
      return res.status(403).json({ message: 'Only clients can create tasks' });
    }

    const {
      title, description, deadline, location,
      domain, company, requiredSkills, attachments, attachmentNames,
    } = req.body;

    if (!title || !description || !deadline) {
      return res.status(400).json({ message: 'Missing required project details' });
    }

    const cleanDomain = normalizeString(domain || 'General');
    const cleanSkills = (requiredSkills || []).map(s => normalizeString(s)).filter(s => s.length > 0);

    const task = await Task.create({
      title: title.trim(),
      description: description.trim(),
      budget: null, 
      studentPayout: 0, // Initialized as 0
      deadline: new Date(deadline),
      location: String(location || '').trim(),
      domain: cleanDomain,
      company: String(company || '').trim(),
      requiredSkills: cleanSkills,
      attachments: Array.isArray(attachments) ? attachments : [],
      attachmentNames: Array.isArray(attachmentNames) ? attachmentNames : [],
      client: req.user.id,
      isGuestTask: false,
      status: 'open'
    });

    emitUpdate(req, 'admin_room', 'task_created', { taskId: task._id });

    const admin = await User.findOne({ role: 'admin' });
    if (admin) {
        await sendNotification(admin._id.toString(), {
            title: "New Task Posted",
            body: `A client posted a new requirement: ${task.title}`,
            data: { type: "task_update", taskId: task._id.toString() }
        }, req);
    }

    return res.status(201).json({ message: 'Task created successfully', task });
  } catch (err) {
    console.error('Create Task Error:', err);
    return res.status(500).json({ message: 'Failed to create task' });
  }
};

/**
 * UPDATE TASK (Edit Feature for Clients)
 * Allows the creator to modify details of an active task.
 */
exports.updateTask = async (req, res) => {
    try {
      const { id } = req.params;
      const {
        title, description, deadline, location,
        domain, requiredSkills, attachments, attachmentNames
      } = req.body;
  
      const task = await Task.findById(id);
  
      if (!task) {
        return res.status(404).json({ message: "Task not found" });
      }
  
      // SECURITY: Ensure only the Client who created the task can edit it
      if (task.client.toString() !== req.user.id) {
        return res.status(403).json({ message: "Unauthorized to edit this task" });
      }
  
      // Apply field updates
      if (title) task.title = title.trim();
      if (description) task.description = description.trim();
      if (deadline) task.deadline = new Date(deadline);
      if (location) task.location = location.trim();
      if (domain) task.domain = normalizeString(domain);
      if (requiredSkills) task.requiredSkills = requiredSkills;
      
      // Update attachments if they were modified in the UI
      if (attachments) task.attachments = attachments;
      if (attachmentNames) task.attachmentNames = attachmentNames;
  
      await task.save();
  
      // Refresh UI for Admin, Client, and Assigned Student
      emitUpdate(req, 'admin_room', 'task_update', { taskId: task._id });
      emitUpdate(req, `${task._id}_client`, 'task_update', { taskId: task._id });
      
      if (task.student) {
        emitUpdate(req, `${task._id}_student_${task.student}`, 'task_update', { taskId: task._id });
      }
  
      return res.json({ message: "Task updated successfully", task });
    } catch (err) {
      console.error("Update Task Error:", err);
      return res.status(500).json({ message: "Failed to update task details" });
    }
  };

/**
 * FINALIZE BUDGET (Split Financials Logic)
 * MODIFIED: Handles separate Client Budget and Student Payout.
 */
exports.finalizeTaskBudget = async (req, res) => {
    try {
      const { taskId } = req.params;
      const { clientBudget, studentPayout } = req.body;
      
      const task = await Task.findById(taskId);
      if (!task) return res.status(404).json({ message: "Task not found" });
  
      // Only update if the 플랫폼 hasn't received payment yet
      if (task.adminReceivedPayment) {
        return res.status(400).json({ message: "Finances cannot be changed after payment verification." });
      }
  
      if (clientBudget) task.budget = Number(clientBudget);
      if (studentPayout) task.studentPayout = Number(studentPayout);
      
      task.budgetFinalized = true; 
      await task.save();
  
      // PRIVACY SYNC: Send only relevant data to each room
      // Notify Client of the total cost they need to pay
      emitUpdate(req, `${taskId}_client`, 'task_update', { 
          taskId, 
          budget: task.budget, 
          budgetFinalized: true 
      });
  
      // Notify Student of their earnings ONLY (Hide Client Budget)
      if (task.student) {
          emitUpdate(req, `${taskId}_student_${task.student}`, 'task_update', { 
              taskId, 
              studentPayout: task.studentPayout, 
              budgetFinalized: true 
          });
      }
      
      res.json({ message: "Budgets Finalized and Locked.", task });
    } catch (error) { 
        console.error("Budget Finalization Error:", error);
        res.status(500).json({ message: "Server Error" }); 
    }
};

/**
 * STUDENT SUBMIT WORK (Multi-file)
 */
exports.submitWork = async (req, res) => {
  try {
    const { files, notes } = req.body;
    const task = await Task.findById(req.params.taskId || req.params.id);

    if (!task || task.student?.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Unauthorized' });
    }

    if (!files || !Array.isArray(files) || files.length === 0) {
      return res.status(400).json({ message: 'Deliverable files are required' });
    }

    task.submission = {
      student: req.user.id,
      files: files.map(f => ({
        url: String(f.url || '').trim(),
        name: String(f.name || 'Untitled').trim()
      })),
      notes: String(notes || '').trim(),
      approved: false,
      submittedAt: new Date(),
    };

    task.status = 'under_review';
    task.clientCanViewSubmission = true; 
    task.clientCanDownload = false; 
    task.modificationNotes = ''; 

    await task.save();

    emitUpdate(req, `${task._id}_client`, 'task_update', { taskId: task._id });
    emitUpdate(req, 'admin_room', 'task_update', { taskId: task._id });

    const admin = await User.findOne({ role: 'admin' });
    if (admin) {
        await sendNotification(admin._id.toString(), {
            title: "Work Submitted",
            body: `Student delivered work for: ${task.title}.`,
            data: { type: "task_submitted", taskId: task._id.toString() }
        }, req);
    }

    return res.json({ message: 'Work submitted for review', task });
  } catch (err) { return res.status(500).json({ message: 'Submission failed' }); }
};

/**
 * CLIENT APPROVE WORK
 */
exports.approveWork = async (req, res) => {
  try {
    const task = await Task.findById(req.params.taskId || req.params.id);
    if (!task || (task.client && task.client.toString() !== req.user.id)) {
      return res.status(403).json({ message: 'Not authorized' });
    }

    task.submission.approved = true;
    task.submission.clientApprovedAt = new Date();
    task.status = 'completed';
    await task.save();

    const student = await User.findById(task.student);
    if (student) {
      student.tasksCompleted = (student.tasksCompleted || 0) + 1;
      await student.save();
      
      await sendNotification(student._id.toString(), {
          title: "Deliverables Approved!",
          body: `Client finalized your project: ${task.title}.`,
          data: { type: "task_assigned", taskId: task._id.toString() }
      }, req);
    }

    emitUpdate(req, `${task._id}_client`, 'task_update', { taskId: task._id });
    emitUpdate(req, 'admin_room', 'task_update', { taskId: task._id });

    return res.json({ message: 'Work approved.', task });
  } catch (err) { return res.status(500).json({ message: 'Approval failed' }); }
};

/**
 * CLIENT DECLINE / MODIFY
 */
exports.declineWork = async (req, res) => {
  try {
    const { reason } = req.body; 
    const task = await Task.findById(req.params.taskId || req.params.id);
    
    if (!task || (task.client && task.client.toString() !== req.user.id)) {
      return res.status(403).json({ message: 'Not authorized' });
    }

    task.attemptCount = (task.attemptCount || 0) + 1;
    task.submission = null; 
    task.status = 'assigned'; 
    task.modificationNotes = String(reason || '').trim();

    await task.save();

    const admin = await User.findOne({ role: 'admin' });
    if (admin && task.student) {
        await Message.create({
            task: task._id, sender: admin._id, receiver: task.student, 
            student: task.student, 
            text: `⚠️ REVISION REQUIRED:\n"${reason}"`
        });
    }

    if (task.student) {
      emitUpdate(req, `${task._id}_student_${task.student}`, 'task_update', { taskId: task._id });
      await sendNotification(task.student.toString(), {
          title: "Revision Required",
          body: `Client requested changes for: ${task.title}.`,
          data: { type: "task_declined", taskId: task._id.toString() }
      }, req);
    }
    
    emitUpdate(req, `${task._id}_client`, 'task_update', { taskId: task._id });

    return res.json({ message: 'Revision requested', task });
  } catch (err) { return res.status(500).json({ message: 'Request failed' }); }
};

/**
 * DATA RETRIEVAL
 */
exports.getAllTasks = async (req, res) => {
  try {
    const { clientId, domain } = req.query;
    const query = {};
    if (clientId) query.client = clientId;
    else query.status = 'open';
    if (domain) query.domain = normalizeString(domain);

    const tasks = await Task.find(query).populate('client', 'name email company').sort({ createdAt: -1 });
    return res.json(tasks);
  } catch (err) { return res.status(500).json({ message: 'Fetch failed' }); }
};

exports.getTaskById = async (req, res) => {
  try {
    const task = await Task.findById(req.params.taskId || req.params.id)
      .populate('client', 'name email company mobile')
      .populate('student', 'name email mobile skills tasksCompleted bankAccountHolderName bankAccountNumber ifscCode totalScore totalScoreCount')
      .select('+attachments +attachmentNames +studentPayout'); // CRITICAL FOR VIEWING ASSETS
    if (!task) return res.status(404).json({ message: 'Task not found' });
    return res.json(task);
  } catch (err) { return res.status(500).json({ message: 'Error fetching task' }); }
};

exports.getStudentTasks = async (req, res) => {
  try {
    const tasks = await Task.find({
      student: req.user.id,
      status: { $in: ['assigned', 'under_review', 'completed', 'declined'] },
    }).sort({ updatedAt: -1 });
    return res.json(tasks);
  } catch (err) { return res.status(500).json({ message: 'Load failed' }); }
};

exports.getClientTasks = async (req, res) => {
    try {
      const tasks = await Task.find({ client: req.user.id }).sort({ createdAt: -1 });
      return res.json(tasks);
    } catch (err) { return res.status(500).json({ message: 'Fetch failed' }); }
};