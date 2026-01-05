import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart'; // Chart
import '../theme/app_colors.dart';
import '../core/network/dio_client.dart'; 
import 'dart:async';
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

  Timer? _timer;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchStats();
    _fetchUsers();
    
    // Auto-refresh stats every 5 seconds
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _fetchStats();
      }
    });
    
    // Infinite Scroll Listener
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoadingUsers && _hasMoreUsers) {
        _fetchUsers();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  // 1. Fetch Stats from Backend (Aggregated)
  Future<void> _fetchStats() async {
    try {
       // Use DioClient to handle BaseUrl automatically (10.0.2.2 or localhost)
       final dio = DioClient.instance.dio; 
       final response = await dio.get('/api/admin/stats');
       if (response.statusCode == 200) {
         if (mounted) {
           setState(() {
             _stats = response.data;
           });
         }
       }
    } catch (e) {
      print("Error fetching stats: $e");
      // Fallback/Error State to stop spinning
      if (mounted) {
        setState(() {
          _stats = {
            "total_users": 0,
            "active_orders": 0,
            "total_assets": 0,
            "user_growth": [],
            "status": "Offline (Connection Error)"
          };
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connection Error: $e")));
      }
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
           tabs: [
             Tab(text: "Overview"),
             Tab(text: "Users (${_stats?['total_users'] ?? '...'})"), // Real Count
             Tab(text: "CMS"),
           ]
        )
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(textColor, isDark),
          _buildUsersTab(textColor),
          _buildCmsTab(textColor),
        ],
      )
    );
  }
  
  Widget _buildOverviewTab(Color textColor, bool isDark) {
    if (_stats == null) return const Center(child: CircularProgressIndicator());
    
    // Parse Real Data
    final List<dynamic> rawGrowth = _stats!['user_growth'] ?? [];
    final List<double> userGrowth = rawGrowth.isEmpty 
        ? [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        : rawGrowth.map((e) => (e as num).toDouble()).toList();
        
    // Dynamic MaxY
    double maxY = 10;
    if (userGrowth.isNotEmpty) {
      double maxVal = userGrowth.reduce((curr, next) => curr > next ? curr : next);
      maxY = (maxVal * 1.5).clamp(10.0, 1000.0);
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Stats Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: [
              _buildStatCard("Online Users", "${_stats!['total_users']}", Colors.blue, Icons.people, isDark),
              _buildStatCard("Active Orders", "${_stats!['active_orders']}", Colors.orange, Icons.trending_up, isDark),
              _buildStatCard("Total Assets", "\$${((_stats!['total_assets'] ?? 0) / 1000000).toStringAsFixed(1)}M", Colors.green, Icons.attach_money, isDark),
              _buildStatCard("Server Status", "${_stats!['status']}", Colors.teal, Icons.dns, isDark),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // 2. Growth Chart
          Text("User Growth (Last 7 Days)", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E222D) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
            ),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                         // Generate last 7 days
                         final today = DateTime.now();
                         // value 0 = 6 days ago, value 6 = today
                         final date = today.subtract(Duration(days: 6 - value.toInt()));
                         return Padding(
                           padding: const EdgeInsets.only(top: 8.0),
                           child: Text(
                             "${date.day}/${date.month}", 
                             style: TextStyle(color: Colors.grey, fontSize: 10)
                           ),
                         );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0, maxX: 6, 
                minY: 0, maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: userGrowth.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(show: true, color: AppColors.primary.withOpacity(0.1)),
                    dotData: FlDotData(show: true), // Show dots for data points
                  )
                ]
              )
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 3. System Config
          Text("System Control", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('system').doc('config').snapshots(),
            builder: (context, snapshot) {
               bool isMaintenance = false;
               if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                 isMaintenance = (snapshot.data!.data() as Map<String, dynamic>)['maintenance_mode'] ?? false;
               }
               return Container(
                 decoration: BoxDecoration(
                   color: isDark ? const Color(0xFF1E222D) : Colors.white,
                   borderRadius: BorderRadius.circular(16),
                 ),
                 child: SwitchListTile(
                   title: Text("Maintenance Mode", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                   subtitle: Text(
                     isMaintenance ? "🔴 System OFFLINE" : "🟢 System ONLINE",
                     style: TextStyle(color: isMaintenance ? Colors.red : Colors.green),
                   ),
                   value: isMaintenance,
                   onChanged: (val) async {
                      // Confirmation Dialog
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(val ? "Enable Maintenance Mode?" : "Disable Maintenance Mode?"),
                          content: Text(val 
                            ? "This will prevent ALL users from logging in or trading. Are you sure?" 
                            : "System will go back online for all users."),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true), 
                              child: Text(val ? "Turn OFF System" : "Go Online", style: TextStyle(color: val ? Colors.red : Colors.green))
                            ),
                          ],
                        )
                      );
                      
                      if (confirm == true) {
                         await FirebaseFirestore.instance.collection('system').doc('config').set(
                           {'maintenance_mode': val}, SetOptions(merge: true)
                         );
                         _fetchStats(); // Refresh stats to reflect status change if needed (though stream updates toggle)
                      }
                   },
                   activeColor: Colors.red,
                   secondary: Icon(Icons.security, color: isMaintenance ? Colors.red : Colors.green),
                 ),
               );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              // Percentage indicator removed
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          )
        ],
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
                // const PopupMenuItem(value: 'add_money', child: Text("💰 Add 100M Demo")),
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
    final dio = DioClient.instance.dio;
    try {
      if (action == 'add_money') {
         final response = await dio.post('/api/admin/add_balance', data: {'user_id': uid, 'amount': 100000000});
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.data['message'] ?? "Added 100M VND")));
      } else if (action == 'ban') {
         final response = await dio.post('/api/admin/ban', data: {'user_id': uid});
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.data['message'])));
         _fetchUsers(); // Refresh UI list
      } else if (action == 'reset_pass') {
         final response = await dio.post('/api/admin/reset_password', data: {'user_id': uid});
         final link = response.data['link'];
         // Show Link in Dialog to Copy
         showDialog(
           context: context, 
           builder: (ctx) => AlertDialog(
             title: const Text("Password Reset Link"),
             content: SelectableText(link),
             actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))]
           )
         );
      }
    } catch (e) {
      String msg = e.toString();
      if (e is DioException) {
        msg = e.response?.data['detail'] ?? e.message;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $msg"), backgroundColor: Colors.red));
    }
  }


  
  Widget _buildCmsTab(Color textColor) { 
    return const AdminCmsTab();
  }
}
