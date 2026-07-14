// lib/env.dart

/// Environment configuration for the SKILEN platform.
/// Handles API endpoints and public third-party credentials.
class Env {
  // ============================================================
  // BACKEND CONFIGURATION
  // ============================================================
  
  /// The base URL for the Node.js server.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:'https://api.skilern.com',
    // defaultValue: 'https://skillbid-api.onrender.com',
  );

  // ============================================================
  // RAZORPAY CONFIGURATION (MODIFICATION)
  // ============================================================

  /// The Public Razorpay Key ID.
  /// Used by the Razorpay SDK to open the checkout window.
  /// REPLACEMENT: Paste your 'rzp_test_...' key here.
  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_live_T8b9XvFeSM2xIG', 
  );

  // ============================================================
  // SYSTEM FLAGS
  // ============================================================

  /// Set to true when moving from Test Mode to Live Mode.
  static const bool isProduction = bool.fromEnvironment(
    'IS_PRODUCTION',
    defaultValue: false,
  );
  
  /// Application Version
  static const String appVersion = '1.0.0';
}