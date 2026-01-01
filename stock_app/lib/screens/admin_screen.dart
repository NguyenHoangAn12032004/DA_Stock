import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import '../theme/app_colors.dart';
import '../core/network/dio_client.dart'; 
import 'admin_course_screen.dart'; // Assume DioClient is accessible via GetIt or Provider

// Since we are refactoring, let's keep it self-contained in Stateful for now to avoid creating complex Providers yet.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  
  // Data State
  Map<String, dynamic>? _stats;
  List<DocumentSnapshot> _users = [];
  bool _isLoadingUsers = false;
  bool _hasMoreUsers = true;
  DocumentSnapshot? _lastUserDoc;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchStats();
    _fetchUsers();
    
    // Infinite Scroll Listener
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoadingUsers && _hasMoreUsers) {
        _fetchUsers();
      }
    });
  }
  
  // 1. Fetch Stats from Backend (Aggregated)
  Future<void> _fetchStats() async {
    try {
      // Direct Dio call for simplicity or use ApiService
      // Assuming DioClient setup or plain Dio for MVP
       final dio = Dio(); 
       final response = await dio.get('http://10.0.2.2:8000/api/admin/stats');
       if (response.statusCode == 200) {
         setState(() {
           _stats = response.data;
         });
       }
    } catch (e) {
      print("Error fetching stats: $e");
    }
  }

  // 2. Fetch Users (Paginated Firestore)
  Future<void> _fetchUsers() async {
    if (_isLoadingUsers) return;
    setState(() { _isLoadingUsers = true; });

    try {
      Query query = FirebaseFirestore.instance.collection('users').orderBy('createdAt', descending: true).limit(_limit);
      
      if (_lastUserDoc != null) {
        query = query.startAfterDocument(_lastUserDoc!);
      }

      final snapshot = await query.get();
      
      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _users.addAll(snapshot.docs);
          _lastUserDoc = snapshot.docs.last;
          if (snapshot.docs.length < _limit) _hasMoreUsers = false;
        });
      } else {
        setState(() { _hasMoreUsers = false; });
      }
    } catch (e) {
      print("Error fetching users: $e");
    } finally {
      setState(() { _isLoadingUsers = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... UI Code similar to previous but using _stats and _users ...
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111418) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Admin Dashboard 🛡️"),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: () {
            setState(() {
              _users.clear();
              _lastUserDoc = null;
              _hasMoreUsers = true;
              _stats = null;
            });
            _fetchStats();
            _fetchUsers();
          })
        ],
        bottom: TabBar(
           controller: _tabController,
           tabs: const [
             Tab(text: "Overview"),
             Tab(text: "Users (10k+)"), // Optimized
             Tab(text: "CMS"),
           ]
        )
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(textColor),
          _buildUsersTab(textColor),
          _buildCmsTab(textColor),
        ],
      )
    );
  }
  
  Widget _buildOverviewTab(Color textColor) {
    if (_stats == null) return const Center(child: CircularProgressIndicator());
    
    return SingleChildScrollView(
      child: Column(
        children: [
          // Real Data Cards
          _buildStatCard("Total Users", "${_stats!['total_users']}", Colors.blue),
          _buildStatCard("Active Orders", "${_stats!['active_orders']}", Colors.orange),
          
          const Divider(height: 32),
          
          // System Config Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("System Configuration", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('system').doc('config').snapshots(),
                  builder: (context, snapshot) {
                     bool isMaintenance = false;
                     if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                       isMaintenance = (snapshot.data!.data() as Map<String, dynamic>)['maintenance_mode'] ?? false;
                     }
                     return Card(
                       color: isMaintenance ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                       child: SwitchListTile(
                         title: Text("Maintenance Mode", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                         subtitle: Text(
                           isMaintenance ? "System is OFFLINE (Users cannot trade)" : "System is ONLINE",
                           style: TextStyle(color: textColor.withOpacity(0.7)),
                         ),
                         value: isMaintenance,
                         onChanged: (val) async {
                           await FirebaseFirestore.instance.collection('system').doc('config').set(
                             {'maintenance_mode': val}, SetOptions(merge: true)
                           );
                         },
                         activeColor: Colors.red,
                       ),
                     );
                  }
                ),
              ],
            ),
          )
        ]
      ),
    );
  }
  
  Widget _buildUsersTab(Color textColor) {
     return ListView.builder(
       controller: _scrollController,
       itemCount: _users.length + (_hasMoreUsers ? 1 : 0),
       itemBuilder: (context, index) {
         if (index == _users.length) {
           return const Center(child: CircularProgressIndicator());
         }
         final doc = _users[index];
         final data = doc.data() as Map<String, dynamic>;
         final uid = doc.id;
         final email = data['email'] ?? 'No Email';
         final role = data['role'] ?? 'user';
         final isBanned = data['status'] == 'banned';
         final balance = data['balance'] ?? 0;
         
         return ListTile(
            leading: CircleAvatar(
              backgroundColor: isBanned ? Colors.black : (role == 'admin' ? Colors.red : Colors.blue),
              child: Icon(isBanned ? Icons.block : (role == 'admin' ? Icons.admin_panel_settings : Icons.person), color: Colors.white),
            ),
            title: Text(email, style: TextStyle(color: textColor, decoration: isBanned ? TextDecoration.lineThrough : null)),
            subtitle: Text("Bal: \$${(balance/1000000).toStringAsFixed(1)}M | Role: $role", style: TextStyle(color: Colors.grey)),
            trailing: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: textColor),
              onSelected: (value) => _handleUserAction(value, uid, data),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'add_money', child: Text("💰 Add 100M Demo")),
                PopupMenuItem(
                  value: 'ban', 
                  child: Text(isBanned ? "✅ Unban User" : "🚫 Ban User", style: TextStyle(color: isBanned ? Colors.green : Colors.red))
                ),
                const PopupMenuItem(value: 'reset_pass', child: Text("📧 Send Reset Password")),
              ],
            ),
         );
       }
     );
  }

  Future<void> _handleUserAction(String action, String uid, Map<String, dynamic> data) async {
    final db = FirebaseFirestore.instance;
    try {
      if (action == 'add_money') {
         await db.collection('users').doc(uid).update({
           'balance': FieldValue.increment(100000000),
           'total_assets': FieldValue.increment(100000000)
         });
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Added 100M VND to user wallet! 💰")));
      } else if (action == 'ban') {
         final isBanned = data['status'] == 'banned';
         await db.collection('users').doc(uid).update({
           'status': isBanned ? 'active' : 'banned'
         });
         // Refresh list locally
         final idx = _users.indexWhere((d) => d.id == uid);
         if (idx != -1) {
             // In real app, re-fetch or robust state update. For now just standard refresh logic will hit on scroll or manual refresh.
             _fetchUsers(); // Simple re-fetch
         }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Widget _buildStatCard(String title, String value, Color color) {
    // ... same as before
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3))
      ),
      child: Row(children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)), 
        const Spacer(), 
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold))
      ])
    );
  }
  
  Widget _buildCmsTab(Color textColor) { 
    return Center(
      child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
             const Icon(Icons.school, size: 80, color: Colors.blue),
             const SizedBox(height: 16),
             Text("Stock Academy CMS", style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
             Padding(
               padding: const EdgeInsets.all(16.0),
               child: Text("Manage Modules, Lessons, and Video Content directly.", 
                 textAlign: TextAlign.center,
                 style: TextStyle(color: textColor.withOpacity(0.7))
               ),
             ),
             ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)
                ),
                icon: const Icon(Icons.edit, color: Colors.white),
                label: const Text("Open Course Editor", style: TextStyle(color: Colors.white, fontSize: 16)),
                onPressed: () {
                   // Navigate to CMS
                   Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminCourseScreen()));
                },
               )
         ]
      ),
    );
  }
}
