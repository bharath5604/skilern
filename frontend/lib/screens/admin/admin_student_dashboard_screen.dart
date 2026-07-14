// import 'package:flutter/material.dart';
// import '../../services/admin_student_dashboard_service.dart';
// import '../../services/socketservice.dart';

// // =============================================================================
// // GLOBAL DESIGN TOKENS (Moved outside classes to fix scoping errors)
// // =============================================================================
// const Color kPrimaryRed = Color(0xFFE53935);
// const Color kBlueColor = Color(0xFF2563EB);
// const Color kGreenColor = Color(0xFF059669);
// const Color kOrangeColor = Color(0xFFD97706);
// const Color kBgGray = Color(0xFFF6F7FB);
// const Color kCardWhite = Colors.white;
// const Color kTextDark = Color(0xFF111827);
// const Color kTextMuted = Color(0xFF6B7280);
// const Color kBorderGray = Color(0xFFE5E7EB);

// class AdminStudentDashboardScreen extends StatefulWidget {
//   final String studentId;

//   const AdminStudentDashboardScreen({
//     Key? key,
//     required this.studentId,
//   }) : super(key: key);

//   @override
//   State<AdminStudentDashboardScreen> createState() =>
//       _AdminStudentDashboardScreenState();
// }

// class _AdminStudentDashboardScreenState
//     extends State<AdminStudentDashboardScreen> {
//   final AdminStudentDashboardService service = AdminStudentDashboardService();

//   Map<String, dynamic>? data;
//   bool loading = false;
//   String? errorMessage;

//   @override
//   void initState() {
//     super.initState();
//     _initializeRealTime();
//   }

//   /// Sets up real-time listener and initial data load
//   Future<void> _initializeRealTime() async {
//     await loadDashboard();

//     SocketService.connect();
    
//     // Listen for profile update signals from the backend
//     SocketService.on('user_profile_updated', (payload) {
//       if (mounted && payload['userId'] == widget.studentId) {
//         debugPrint("Admin Student Dash: Profile changed, refreshing...");
//         loadDashboard(isSilent: true); 
//       }
//     });
//   }

//   @override
//   void dispose() {
//     SocketService.off('user_profile_updated');
//     super.dispose();
//   }

//   int toInt(dynamic v) {
//     if (v == null) return 0;
//     if (v is int) return v;
//     return int.tryParse(v.toString()) ?? 0;
//   }

//   double toDouble(dynamic v) {
//     if (v == null) return 0.0;
//     if (v is double) return v;
//     return double.tryParse(v.toString()) ?? 0.0;
//   }

//   String formatCurrency(num value) {
//     return "₹${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}";
//   }

//   /// Fetches student metrics and profile.
//   Future<void> loadDashboard({bool isSilent = false}) async {
//     if (!mounted) return;
//     if (!isSilent) {
//       setState(() {
//         loading = true;
//         errorMessage = null;
//       });
//     }

//     try {
//       final res = await service.getStudentDashboard(widget.studentId);
//       if (!mounted) return;
//       setState(() => data = res);
//     } catch (e) {
//       if (!mounted) return;
//       setState(() => errorMessage = e.toString());
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
//       );
//     } finally {
//       if (mounted && !isSilent) setState(() => loading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final dashboard = (data != null && data!.containsKey('data')) 
//         ? data!['data'] 
//         : data;

//     final student = dashboard?['student'] is Map 
//         ? Map<String, dynamic>.from(dashboard!['student']) 
//         : <String, dynamic>{};

//     final String studentName = (student['name'] ?? 'Student').toString();
//     final String studentEmail = (student['email'] ?? 'N/A').toString();
//     final String studentMobile = (student['mobile'] ?? 'N/A').toString();
//     final String studentLoc = (student['location'] ?? 'Remote').toString();
//     final String studentBio = (student['bio'] ?? 'No bio provided.').toString();
//     final List technicalSkills = student['skills'] is List ? student['skills'] : [];

//     final String accHolder = (student['bankAccountHolderName'] ?? 'Not set').toString();
//     final String accNumber = (student['bankAccountNumber'] ?? 'Not set').toString();
//     final String accIFSC = (student['ifscCode'] ?? 'Not set').toString();

//     final bool isApproved = student['isApproved'] == true;

//     final int totalTasks = toInt(dashboard?['totalTasks']);
//     final int completedTasks = toInt(dashboard?['completedTasks']);
//     final double totalPayments = toDouble(dashboard?['totalEarnings'] ?? dashboard?['totalPayments']);
//     final int pendingTasks = (totalTasks - completedTasks).clamp(0, 9999);
//     final double completionRate = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

//     return Scaffold(
//       backgroundColor: kBgGray,
//       appBar: AppBar(
//         elevation: 0,
//         backgroundColor: Colors.white,
//         surfaceTintColor: Colors.white,
//         title: const Text('Student Full Insight', style: TextStyle(color: kTextDark, fontWeight: FontWeight.w700)),
//         iconTheme: const IconThemeData(color: kTextDark),
//         actions: [
//             IconButton(icon: const Icon(Icons.refresh), onPressed: loadDashboard)
//         ],
//       ),
//       body: loading && data == null
//           ? const Center(child: CircularProgressIndicator(color: kPrimaryRed))
//           : RefreshIndicator(
//               onRefresh: loadDashboard,
//               child: dashboard == null
//                   ? _buildErrorView()
//                   : ListView(
//                       padding: const EdgeInsets.all(16),
//                       children: [
//                         buildHeroCard(
//                           studentName: studentName,
//                           studentEmail: studentEmail,
//                           location: studentLoc,
//                           isApproved: isApproved
//                         ),
//                         const SizedBox(height: 16),
//                         _buildStatGrid(totalTasks, completedTasks, pendingTasks),
//                         const SizedBox(height: 16),
                        
//                         DashboardCard(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               sectionTitle('Performance overview'),
//                               const SizedBox(height: 14),
//                               Row(
//                                 children: [
//                                   Expanded(child: MiniMetric(label: 'Completion rate', value: '${(completionRate * 100).toStringAsFixed(0)}%', color: kGreenColor)),
//                                   const SizedBox(width: 12),
//                                   Expanded(child: MiniMetric(label: 'Payments earned', value: formatCurrency(totalPayments), color: kPrimaryRed)),
//                                 ],
//                               ),
//                               const SizedBox(height: 16),
//                               const Text('Task completion progress', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextDark)),
//                               const SizedBox(height: 10),
//                               ClipRRect(
//                                 borderRadius: BorderRadius.circular(10),
//                                 child: LinearProgressIndicator(
//                                   value: completionRate,
//                                   minHeight: 10,
//                                   backgroundColor: kBorderGray,
//                                   valueColor: const AlwaysStoppedAnimation(kGreenColor),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(height: 16),

//                         DashboardCard(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               sectionTitle('Professional credentials'),
//                               const SizedBox(height: 14),
//                               Text(studentBio, style: const TextStyle(fontSize: 13, color: kTextDark, height: 1.4)),
//                               const Divider(height: 24),
//                               const Text('Technical Skills', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextMuted)),
//                               const SizedBox(height: 8),
//                               if (technicalSkills.isEmpty)
//                                 const Text("No skills listed.", style: TextStyle(fontSize: 12, color: kTextMuted))
//                               else
//                                 Wrap(
//                                   spacing: 6, runSpacing: 0,
//                                   children: technicalSkills.map((s) => Chip(
//                                     label: Text(s.toString(), style: const TextStyle(fontSize: 10, color: kBlueColor)),
//                                     backgroundColor: kBlueColor.withOpacity(0.05),
//                                   )).toList(),
//                                 ),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(height: 16),

//                         DashboardCard(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               sectionTitle('Bank Account Information'),
//                               const SizedBox(height: 14),
//                               InfoRow(icon: Icons.badge_outlined, label: 'Account Holder', value: accHolder),
//                               InfoRow(icon: Icons.credit_card, label: 'Account Number', value: accNumber),
//                               InfoRow(icon: Icons.code, label: 'IFSC Code', value: accIFSC),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(height: 16),

//                         DashboardCard(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               sectionTitle('Contact details'),
//                               const SizedBox(height: 14),
//                               InfoRow(icon: Icons.person_outline, label: 'Name', value: studentName),
//                               InfoRow(icon: Icons.phone_android, label: 'Mobile', value: studentMobile),
//                               InfoRow(icon: Icons.mail_outline, label: 'Email', value: studentEmail),
//                               InfoRow(
//                                 icon: Icons.verified_user_outlined,
//                                 label: 'Status',
//                                 value: isApproved ? 'Approved' : 'Pending',
//                                 valueColor: isApproved ? kGreenColor : kOrangeColor,
//                               ),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(height: 40),
//                       ],
//                     ),
//             ),
//     );
//   }

//   Widget _buildStatGrid(int total, int completed, int pending) {
//     return GridView.count(
//       crossAxisCount: 3,
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       crossAxisSpacing: 12,
//       mainAxisSpacing: 12,
//       childAspectRatio: 0.85,
//       children: [
//         StatCard(title: 'Total', value: total.toString(), subtitle: 'Assigned', icon: Icons.work_outline, color: kBlueColor),
//         StatCard(title: 'Done', value: completed.toString(), subtitle: 'Finished', icon: Icons.task_alt, color: kGreenColor),
//         StatCard(title: 'Pending', value: pending.toString(), subtitle: 'Active', icon: Icons.pending_actions, color: kOrangeColor),
//       ],
//     );
//   }

//   Widget _buildErrorView() {
//     return ListView(
//       padding: const EdgeInsets.all(20),
//       children: [
//         const SizedBox(height: 100),
//         DashboardCard(
//           child: Column(
//             children: [
//               const Icon(Icons.error_outline, size: 48, color: kPrimaryRed),
//               const SizedBox(height: 16),
//               const Text('Unable to load dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//               const SizedBox(height: 8),
//               Text(errorMessage ?? 'No data available', textAlign: TextAlign.center, style: const TextStyle(color: kTextMuted)),
//               const SizedBox(height: 20),
//               ElevatedButton(onPressed: loadDashboard, style: ElevatedButton.styleFrom(backgroundColor: kPrimaryRed), child: const Text('Retry', style: TextStyle(color: Colors.white))),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget buildHeroCard({required String studentName, required String studentEmail, required String location, required bool isApproved}) {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(24),
//         gradient: const LinearGradient(colors: [kPrimaryRed, Color(0xFFC62828)], begin: Alignment.topLeft, end: Alignment.bottomRight),
//         boxShadow: [BoxShadow(color: kPrimaryRed.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text('Student Profile', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
//           const SizedBox(height: 12),
//           Text(studentName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
//           Text(studentEmail, style: const TextStyle(color: Colors.white70, fontSize: 14)),
//           const SizedBox(height: 16),
//           Wrap(
//             spacing: 8,
//             runSpacing: 8,
//             children: [
//               HeroChip(icon: Icons.location_on, text: location),
//               HeroChip(icon: isApproved ? Icons.verified : Icons.hourglass_top, text: isApproved ? 'Approved' : 'Active'),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget sectionTitle(String text) {
//     return Row(
//       children: [
//         Container(width: 5, height: 18, decoration: BoxDecoration(color: kPrimaryRed, borderRadius: BorderRadius.circular(10))),
//         const SizedBox(width: 8),
//         Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextDark)),
//       ],
//     );
//   }
// }

// // Sub-widgets

// class DashboardCard extends StatelessWidget {
//   final Widget child;
//   const DashboardCard({Key? key, required this.child}) : super(key: key);
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: kBorderGray)),
//       child: child,
//     );
//   }
// }

// class StatCard extends StatelessWidget {
//   final String title, value, subtitle;
//   final IconData icon;
//   final Color color;
//   const StatCard({Key? key, required this.title, required this.value, required this.subtitle, required this.icon, required this.color}) : super(key: key);
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: kBorderGray)),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
//           const SizedBox(height: 8),
//           Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
//           Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextDark)),
//         ],
//       ),
//     );
//   }
// }

// class MiniMetric extends StatelessWidget {
//   final String label, value;
//   final Color color;
//   const MiniMetric({Key? key, required this.label, required this.value, required this.color}) : super(key: key);
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(label, style: const TextStyle(fontSize: 10, color: kTextMuted, fontWeight: FontWeight.w600)),
//           const SizedBox(height: 4),
//           Text(value, style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.bold)),
//         ],
//       ),
//     );
//   }
// }

// class HeroChip extends StatelessWidget {
//   final IconData icon;
//   final String text;
//   const HeroChip({Key? key, required this.icon, required this.text}) : super(key: key);
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//       decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(icon, size: 13, color: Colors.white),
//           const SizedBox(width: 6),
//           Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
//         ],
//       ),
//     );
//   }
// }

// class InfoRow extends StatelessWidget {
//   final IconData icon;
//   final String label, value;
//   final Color? valueColor;
//   const InfoRow({Key? key, required this.icon, required this.label, required this.value, this.valueColor}) : super(key: key);
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 12),
//       child: Row(
//         children: [
//           Container(width: 32, height: 32, decoration: BoxDecoration(color: kPrimaryRed.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.info_outline, size: 16, color: kPrimaryRed)),
//           const SizedBox(width: 12),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(label, style: const TextStyle(fontSize: 10, color: kTextMuted, fontWeight: FontWeight.w600)),
//               Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor ?? kTextDark)),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _SectionTitleText extends StatelessWidget {
//   final String text;
//   const _SectionTitleText(this.text);
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Container(width: 5, height: 18, decoration: BoxDecoration(color: kPrimaryRed, borderRadius: BorderRadius.circular(10))),
//         const SizedBox(width: 8),
//         Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextDark)),
//       ],
//     );
//   }
// }