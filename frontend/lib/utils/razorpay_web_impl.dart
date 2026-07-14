// lib/utils/razorpay_web_impl.dart
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js' as js;

/// Actual JavaScript implementation for Razorpay on Web.
/// Uses direct JS evaluation to avoid allowInterop and Expando errors.
void openRazorpayWeb({
  required String key,
  required int amount,
  required String title,
  required String contact,
  required String email,
  required Function onSuccess,
}) {
  // 1. Create a global callback on the window object that Dart can "hear"
  // This replaces the problematic allowInterop
  js.context['onRazorpaySuccess'] = () {
    onSuccess();
  };

  // 2. Sanitize inputs for the JS String
  final String safeTitle = title.replaceAll("'", "").replaceAll('"', "");

  // 3. Execute the native JS SDK code
  // This injects a raw JS script into the browser context
  js.context.callMethod('eval', ["""
    var options = {
      "key": "$key",
      "amount": "$amount",
      "name": "Skilern Platform",
      "description": "$safeTitle",
      "prefill": {
        "contact": "$contact",
        "email": "$email"
      },
      "handler": function(response) {
        // Calls the global Dart function we defined above
        window.onRazorpaySuccess();
      }
    };
    var rzp = new Razorpay(options);
    rzp.open();
  """]);
}