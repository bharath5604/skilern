// import 'package:flutter/material.dart';
// import '../../services/auth_service.dart';
// import '../../services/user_service.dart';

// class StudentWithdrawalScreen extends StatefulWidget {
//   const StudentWithdrawalScreen({Key? key}) : super(key: key);

//   @override
//   State<StudentWithdrawalScreen> createState() => _StudentWithdrawalScreenState();
// }

// class _StudentWithdrawalScreenState extends State<StudentWithdrawalScreen>
//     with SingleTickerProviderStateMixin {
//   final _amountController = TextEditingController();
//   final UserService _userService = UserService();
//   bool _loading = false;
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;
//   late Animation<Offset> _slideAnimation;

//   // Updated color palette to match landing page
//   static const Color primaryPurple = Color(0xFF6A11CB);
//   static const Color secondaryPurple = Color(0xFF2575FC);
//   static const Color textDark = Color(0xFF111827);
//   static const Color textMuted = Color(0xFF6B7280);
//   static const Color backgroundColor = Color(0xFFF5F7FB);

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       duration: const Duration(milliseconds: 800),
//       vsync: this,
//     );
//     _fadeAnimation = CurvedAnimation(
//       parent: _animationController,
//       curve: Curves.easeOutCubic,
//     );
//     _slideAnimation = Tween<Offset>(
//       begin: const Offset(0, 0.3),
//       end: Offset.zero,
//     ).animate(CurvedAnimation(
//       parent: _animationController,
//       curve: Curves.easeOutCubic,
//     ));
//     _animationController.forward();
//   }

//   @override
//   void dispose() {
//     _amountController.dispose();
//     _animationController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final user = AuthService.currentUser!;
//     final balance = user.wallet;

//     return Scaffold(
//       backgroundColor: backgroundColor,
//       appBar: AppBar(
//         elevation: 0,
//         backgroundColor: Colors.white,
//         surfaceTintColor: Colors.white,
//         centerTitle: false,
//         title: ShaderMask(
//           shaderCallback: (bounds) => const LinearGradient(
//             colors: [primaryPurple, secondaryPurple],
//           ).createShader(bounds),
//           child: const Text(
//             'Withdraw Funds',
//             style: TextStyle(
//               fontWeight: FontWeight.w700,
//               fontSize: 18,
//               color: Colors.white,
//             ),
//           ),
//         ),
//         leading: IconButton(
//           icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryPurple),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: FadeTransition(
//         opacity: _fadeAnimation,
//         child: SlideTransition(
//           position: _slideAnimation,
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.all(20),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Balance Card
//                 TweenAnimationBuilder(
//                   tween: Tween<double>(begin: 0, end: 1),
//                   duration: const Duration(milliseconds: 500),
//                   curve: Curves.easeOutCubic,
//                   builder: (context, value, child) {
//                     return Opacity(
//                       opacity: value,
//                       child: Transform.scale(
//                         scale: value,
//                         child: child,
//                       ),
//                     );
//                   },
//                   child: Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.all(24),
//                     decoration: BoxDecoration(
//                       gradient: const LinearGradient(
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                         colors: [primaryPurple, secondaryPurple],
//                       ),
//                       borderRadius: BorderRadius.circular(24),
//                       boxShadow: [
//                         BoxShadow(
//                           color: primaryPurple.withOpacity(0.25),
//                           blurRadius: 20,
//                           offset: const Offset(0, 10),
//                         ),
//                       ],
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           children: [
//                             Container(
//                               padding: const EdgeInsets.all(8),
//                               decoration: BoxDecoration(
//                                 color: Colors.white.withOpacity(0.15),
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                               child: const Icon(
//                                 Icons.account_balance_wallet_outlined,
//                                 color: Colors.white,
//                                 size: 24,
//                               ),
//                             ),
//                             const SizedBox(width: 12),
//                             const Text(
//                               'Withdrawable Balance',
//                               style: TextStyle(
//                                 fontSize: 14,
//                                 color: Colors.white70,
//                                 letterSpacing: 0.5,
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 16),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           crossAxisAlignment: CrossAxisAlignment.end,
//                           children: [
//                             Text(
//                               '₹${balance.toStringAsFixed(0)}',
//                               style: const TextStyle(
//                                 fontSize: 32,
//                                 fontWeight: FontWeight.w800,
//                                 color: Colors.white,
//                                 letterSpacing: -1,
//                               ),
//                             ),
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 10,
//                                 vertical: 5,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: Colors.white.withOpacity(0.15),
//                                 borderRadius: BorderRadius.circular(20),
//                               ),
//                               child: const Text(
//                                 'Available',
//                                 style: TextStyle(
//                                   fontSize: 11,
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 28),

//                 // Enter Amount Section
//                 TweenAnimationBuilder(
//                   tween: Tween<double>(begin: 0, end: 1),
//                   duration: const Duration(milliseconds: 600),
//                   curve: Curves.easeOutCubic,
//                   builder: (context, value, child) {
//                     return Opacity(
//                       opacity: value,
//                       child: Transform.translate(
//                         offset: Offset(0, 20 * (1 - value)),
//                         child: child,
//                       ),
//                     );
//                   },
//                   child: Container(
//                     padding: const EdgeInsets.all(20),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(20),
//                       border: Border.all(color: primaryPurple.withOpacity(0.08)),
//                       boxShadow: [
//                         BoxShadow(
//                           color: primaryPurple.withOpacity(0.06),
//                           blurRadius: 16,
//                           offset: const Offset(0, 6),
//                         ),
//                       ],
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           children: [
//                             Container(
//                               width: 3,
//                               height: 18,
//                               decoration: BoxDecoration(
//                                 gradient: const LinearGradient(
//                                   colors: [primaryPurple, secondaryPurple],
//                                 ),
//                                 borderRadius: BorderRadius.circular(2),
//                               ),
//                             ),
//                             const SizedBox(width: 10),
//                             const Text(
//                               'Enter Amount',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.w700,
//                                 fontSize: 15,
//                                 color: textDark,
//                               ),
//                             ),
//                             const SizedBox(width: 8),
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 8,
//                                 vertical: 3,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: Colors.amber.withOpacity(0.1),
//                                 borderRadius: BorderRadius.circular(20),
//                               ),
//                               child: const Text(
//                                 'Min ₹500',
//                                 style: TextStyle(
//                                   fontSize: 10,
//                                   fontWeight: FontWeight.w600,
//                                   color: Colors.amber,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 20),
//                         TextField(
//                           controller: _amountController,
//                           keyboardType: TextInputType.number,
//                           style: const TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.w600,
//                           ),
//                           decoration: InputDecoration(
//                             hintText: 'Enter amount to withdraw',
//                             prefixIcon: Icon(Icons.currency_rupee, color: primaryPurple),
//                             border: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(14),
//                               borderSide: BorderSide(
//                                 color: primaryPurple.withOpacity(0.2),
//                               ),
//                             ),
//                             enabledBorder: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(14),
//                               borderSide: BorderSide(
//                                 color: primaryPurple.withOpacity(0.2),
//                               ),
//                             ),
//                             focusedBorder: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(14),
//                               borderSide: const BorderSide(
//                                 color: primaryPurple,
//                                 width: 2,
//                               ),
//                             ),
//                             filled: true,
//                             fillColor: Colors.white,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 20),

//                 // Transfer Details Section
//                 TweenAnimationBuilder(
//                   tween: Tween<double>(begin: 0, end: 1),
//                   duration: const Duration(milliseconds: 700),
//                   curve: Curves.easeOutCubic,
//                   builder: (context, value, child) {
//                     return Opacity(
//                       opacity: value,
//                       child: Transform.translate(
//                         offset: Offset(0, 20 * (1 - value)),
//                         child: child,
//                       ),
//                     );
//                   },
//                   child: Container(
//                     padding: const EdgeInsets.all(20),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(20),
//                       border: Border.all(color: primaryPurple.withOpacity(0.08)),
//                       boxShadow: [
//                         BoxShadow(
//                           color: primaryPurple.withOpacity(0.06),
//                           blurRadius: 16,
//                           offset: const Offset(0, 6),
//                         ),
//                       ],
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           children: [
//                             Container(
//                               width: 3,
//                               height: 18,
//                               decoration: BoxDecoration(
//                                 gradient: const LinearGradient(
//                                   colors: [primaryPurple, secondaryPurple],
//                                 ),
//                                 borderRadius: BorderRadius.circular(2),
//                               ),
//                             ),
//                             const SizedBox(width: 10),
//                             const Text(
//                               'Transferring to',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.w700,
//                                 fontSize: 15,
//                                 color: textDark,
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 16),
//                         Container(
//                           padding: const EdgeInsets.all(16),
//                           decoration: BoxDecoration(
//                             gradient: LinearGradient(
//                               begin: Alignment.topLeft,
//                               end: Alignment.bottomRight,
//                               colors: [
//                                 primaryPurple.withOpacity(0.04),
//                                 secondaryPurple.withOpacity(0.02),
//                               ],
//                             ),
//                             borderRadius: BorderRadius.circular(16),
//                             border: Border.all(
//                               color: primaryPurple.withOpacity(0.1),
//                             ),
//                           ),
//                           child: Row(
//                             children: [
//                               Container(
//                                 padding: const EdgeInsets.all(10),
//                                 decoration: BoxDecoration(
//                                   gradient: const LinearGradient(
//                                     colors: [primaryPurple, secondaryPurple],
//                                   ),
//                                   borderRadius: BorderRadius.circular(12),
//                                 ),
//                                 child: const Icon(
//                                   Icons.account_balance,
//                                   color: Colors.white,
//                                   size: 22,
//                                 ),
//                               ),
//                               const SizedBox(width: 14),
//                               Expanded(
//                                 child: Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     Text(
//                                       user.bankName.isEmpty
//                                           ? 'No Bank Added'
//                                           : user.bankName,
//                                       style: const TextStyle(
//                                         fontSize: 14,
//                                         fontWeight: FontWeight.w700,
//                                         color: textDark,
//                                       ),
//                                     ),
//                                     const SizedBox(height: 4),
//                                     Text(
//                                       user.bankAccountNumber.isEmpty
//                                           ? 'Update profile to add bank details'
//                                           : 'Account: ****${user.bankAccountNumber.length > 4 ? user.bankAccountNumber.substring(user.bankAccountNumber.length - 4) : user.bankAccountNumber}',
//                                       style: TextStyle(
//                                         fontSize: 12,
//                                         color: textMuted,
//                                       ),
//                                     ),
//                                     if (user.ifscCode.isNotEmpty)
//                                       Padding(
//                                         padding: const EdgeInsets.only(top: 4),
//                                         child: Text(
//                                           'IFSC: ${user.ifscCode}',
//                                           style: TextStyle(
//                                             fontSize: 11,
//                                             color: primaryPurple,
//                                             fontWeight: FontWeight.w500,
//                                           ),
//                                         ),
//                                       ),
//                                   ],
//                                 ),
//                               ),
//                               if (user.bankAccountNumber.isEmpty)
//                                 Container(
//                                   padding: const EdgeInsets.all(6),
//                                   decoration: BoxDecoration(
//                                     color: Colors.amber.withOpacity(0.1),
//                                     borderRadius: BorderRadius.circular(8),
//                                   ),
//                                   child: const Icon(
//                                     Icons.warning_amber_rounded,
//                                     color: Colors.amber,
//                                     size: 16,
//                                   ),
//                                 ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 30),

//                 // Withdrawal Info Card
//                 TweenAnimationBuilder(
//                   tween: Tween<double>(begin: 0, end: 1),
//                   duration: const Duration(milliseconds: 800),
//                   curve: Curves.easeOutCubic,
//                   builder: (context, value, child) {
//                     return Opacity(
//                       opacity: value,
//                       child: Transform.translate(
//                         offset: Offset(0, 20 * (1 - value)),
//                         child: child,
//                       ),
//                     );
//                   },
//                   child: Container(
//                     padding: const EdgeInsets.all(16),
//                     decoration: BoxDecoration(
//                       color: primaryPurple.withOpacity(0.04),
//                       borderRadius: BorderRadius.circular(16),
//                       border: Border.all(
//                         color: primaryPurple.withOpacity(0.12),
//                       ),
//                     ),
//                     child: Row(
//                       children: [
//                         Icon(
//                           Icons.info_outline,
//                           size: 20,
//                           color: primaryPurple,
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Text(
//                             'Withdrawal requests are processed within 2-3 business days. Funds will be transferred to your registered bank account.',
//                             style: TextStyle(
//                               fontSize: 12,
//                               color: textMuted,
//                               height: 1.4,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 30),

//                 // Submit Button
//                 TweenAnimationBuilder(
//                   tween: Tween<double>(begin: 0, end: 1),
//                   duration: const Duration(milliseconds: 900),
//                   curve: Curves.easeOutCubic,
//                   builder: (context, value, child) {
//                     return Opacity(
//                       opacity: value,
//                       child: Transform.scale(
//                         scale: value,
//                         child: child,
//                       ),
//                     );
//                   },
//                   child: SizedBox(
//                     width: double.infinity,
//                     child: _loading
//                         ? Container(
//                             padding: const EdgeInsets.symmetric(vertical: 16),
//                             decoration: BoxDecoration(
//                               borderRadius: BorderRadius.circular(16),
//                               gradient: const LinearGradient(
//                                 colors: [primaryPurple, secondaryPurple],
//                               ),
//                             ),
//                             child: const Center(
//                               child: CircularProgressIndicator(
//                                 color: Colors.white,
//                                 strokeWidth: 2,
//                               ),
//                             ),
//                           )
//                         : Container(
//                             decoration: BoxDecoration(
//                               borderRadius: BorderRadius.circular(16),
//                               gradient: const LinearGradient(
//                                 colors: [primaryPurple, secondaryPurple],
//                               ),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: primaryPurple.withOpacity(0.3),
//                                   blurRadius: 16,
//                                   offset: const Offset(0, 6),
//                                 ),
//                               ],
//                             ),
//                             child: ElevatedButton(
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.transparent,
//                                 foregroundColor: Colors.white,
//                                 elevation: 0,
//                                 padding: const EdgeInsets.symmetric(vertical: 16),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(16),
//                                 ),
//                               ),
//                               onPressed: _submitRequest,
//                               child: const Row(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(Icons.payments_outlined, size: 20),
//                                   SizedBox(width: 10),
//                                   Text(
//                                     'Submit Withdrawal Request',
//                                     style: TextStyle(
//                                       fontWeight: FontWeight.w700,
//                                       fontSize: 16,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _submitRequest() async {
//     final amount = double.tryParse(_amountController.text) ?? 0;
//     final balance = AuthService.currentUser!.wallet;

//     if (amount < 500) {
//       _showSnack('Minimum withdrawal amount is ₹500');
//       return;
//     }
//     if (amount > balance) {
//       _showSnack('Insufficient balance. Your available balance is ₹${balance.toStringAsFixed(0)}');
//       return;
//     }

//     // Show confirmation dialog
//     final confirmed = await showDialog<bool>(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(20),
//         ),
//         title: ShaderMask(
//           shaderCallback: (bounds) => const LinearGradient(
//             colors: [primaryPurple, secondaryPurple],
//           ).createShader(bounds),
//           child: const Text(
//             'Confirm Withdrawal',
//             style: TextStyle(
//               fontWeight: FontWeight.w700,
//               fontSize: 18,
//               color: Colors.white,
//             ),
//           ),
//         ),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'You are about to withdraw:',
//               style: TextStyle(color: textMuted),
//             ),
//             const SizedBox(height: 12),
//             Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [primaryPurple.withOpacity(0.08), secondaryPurple.withOpacity(0.04)],
//                 ),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Text(
//                     'Amount',
//                     style: TextStyle(fontWeight: FontWeight.w600),
//                   ),
//                   Text(
//                     '₹${amount.toStringAsFixed(0)}',
//                     style: TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                       color: primaryPurple,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 16),
//             Text(
//               'Funds will be transferred to your registered bank account.',
//               style: TextStyle(fontSize: 12, color: textMuted),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx, false),
//             child: Text('Cancel', style: TextStyle(color: textMuted)),
//           ),
//           Container(
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(10),
//               gradient: const LinearGradient(
//                 colors: [primaryPurple, secondaryPurple],
//               ),
//             ),
//             child: ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.transparent,
//                 foregroundColor: Colors.white,
//                 elevation: 0,
//               ),
//               onPressed: () => Navigator.pop(ctx, true),
//               child: const Text('Confirm'),
//             ),
//           ),
//         ],
//       ),
//     );

//     if (confirmed != true) return;

//     setState(() => _loading = true);
//     try {
//       await _userService.requestWithdrawal(amount);
//       if (mounted) {
//         _showSnack('Withdrawal request submitted successfully!');
//         Navigator.pop(context);
//       }
//     } catch (e) {
//       _showSnack('Error: $e');
//     } finally {
//       if (mounted) {
//         setState(() => _loading = false);
//       }
//     }
//   }

//   void _showSnack(String msg) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(msg),
//         backgroundColor: primaryPurple,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(10),
//         ),
//       ),
//     );
//   }
// }