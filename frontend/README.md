SkillBid Infrastructure: Master Setup Guide
1. Firebase Project & Storage Setup
A. Creating the Account & Project
Go to the Firebase Console.
Log in with your Google Account.
Click "Add project".
Enter Project Name: SkillBid.
(Optional) Enable Google Analytics and click Create Project.
B. Creating the Storage Bucket
In the Firebase left sidebar, click Build -> Storage.
Click Get Started.
Security Rules: Select "Start in test mode" for now (we will overwrite these later).
Location: Choose a region close to your users (e.g., asia-south1 for India).
Click Done.
Your Bucket ID is now visible at the top (e.g., skillbid-xxxx.firebasestorage.app).
C. Applying Custom Security Rules
Since SkillBid handles authentication via a custom Node.js server (not Firebase Auth), we must tell Firebase to allow our app to upload files.
Inside the Storage dashboard, click the Rules tab.
Delete everything and paste these specific rules:
code
JavaScript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allows public upload for ID cards, submissions, and chat
    // Security is managed via unique filenames and Node.js logic
    match /student_ids/{allPaths=**} { allow read, write: if true; }
    match /task_attachments/{allPaths=**} { allow read, write: if true; }
    match /subs/{allPaths=**} { allow read, write: if true; }
    match /chat_attachments/{allPaths=**} { allow read, write: if true; }
  }
}
Click Publish.
☁️ 2. Google Cloud & CORS Configuration
CORS (Cross-Origin Resource Sharing) is mandatory to allow web browsers to display images from Firebase.
A. Connect to Google Cloud Shell
In the Firebase Console, click the Project Settings (gear icon) -> Usage and Billing -> Details & Settings.
Click the link to open the Google Cloud Console.
At the top right of the Google Cloud screen, click the Activate Cloud Shell icon (>_).
B. Applying the CORS Fix
In the terminal that opens at the bottom, create a new file:
code
Bash
nano cors.json
Paste this exact code:
code
JSON
[
  {
    "origin": ["*"],
    "method": ["GET", "POST", "PUT", "DELETE"],
    "responseHeader": ["Content-Type", "Authorization"],
    "maxAgeSeconds": 3600
  }
]
Press Ctrl + O, then Enter to save. Press Ctrl + X to exit.
Run the following command (Replace YOUR_BUCKET_ID with the ID from Step 1B):
code
Bash
gsutil cors set cors.json gs://YOUR_BUCKET_ID
📲 3. Firebase Cloud Messaging (FCM) Setup
A. Linking Backend to Firebase
Go to Project Settings -> Service accounts.
Click "Generate new private key". This downloads a .json file.
Open this file in a text editor. You need to turn this entire file into a single line string.
Go to your Render.com Dashboard -> Environment Variables.
Add a key named FCM_SERVICE_ACCOUNT_JSON and paste that long string as the value.
B. Flutter Firebase Configuration
Install the Firebase CLI on your computer.
Run flutterfire configure in your project terminal.
This generates a firebase_options.dart file in your lib/ folder. This connects your app to the project.
🔑 4. Database & Admin Account Creation
A. Connecting Node.js to MongoDB
Go to MongoDB Atlas.
Create a cluster and click Connect.
Choose "Connect your application" and copy the Connection String.
Paste this in your backend .env or Render environment:
MONGO_URI=mongodb+srv://admin:password@cluster.mongodb.net/skillbid
B. Creating the Admin User
Since passwords must be hashed, do not type a plain password into the DB.
Use a Bcrypt Generator to hash your password.
Example: Admin@12345 becomes $2a$10$7Z8bUjE6G3v1K7vY7H5Z1.r6E8G3v1K7vY7H5Z1.r6E8G3v1K7vY7
Go to MongoDB Browse Collections -> users -> Insert Document.
Paste this template:
code
JSON
{
  "name": "Admin Name",
  "email": "admin@skilen.com",
  "password": "PASTE_THE_HASHED_STRING_HERE",
  "role": "admin",
  "location": "Headquarters",
  "isApproved": true,
  "mobile": "1234567890"
}
💳 5. Razorpay Integration
A. Credentials
Log in to Razorpay Dashboard.
Settings -> API Keys -> Generate Test Key.
Add RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET to your Backend .env.
Add razorpayKeyId to your Flutter lib/env.dart.
B. Webhook Setup (The Real-Time Bridge)
In Razorpay, go to Settings -> Webhooks.
URL: https://your-api.onrender.com/api/payments/webhook.
Secret: Create a password and add it to backend .env as RAZORPAY_WEBHOOK_SECRET.
Events: Select payment.captured.
📝 6. Summary of Connections
Connection	Protocol	Required Credential
Flutter ↔ Backend	HTTP / Socket.io	apiBaseUrl in env.dart
Backend ↔ MongoDB	Mongoose	MONGO_URI in .env
Backend ↔ Firebase	Firebase Admin SDK	FCM_SERVICE_ACCOUNT_JSON
Flutter ↔ Firebase	Firebase SDK	google-services.json / firebase_options.dart
Flutter ↔ Razorpay	MethodChannel	razorpayKeyId in env.dart
Your SkillBid project is now fully configured for professional, dynamic, and secure operation.