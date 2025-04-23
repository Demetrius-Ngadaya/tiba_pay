import 'package:flutter/material.dart';
import 'package:tiba_pay/models/user.dart';
import 'package:tiba_pay/screens/admin/user_list_screen.dart';
import 'package:tiba_pay/screens/payments/payment_history_screen.dart';
import 'package:tiba_pay/screens/payments/process_payment_screen.dart';
import 'package:tiba_pay/screens/patients/patient_list_screen.dart';
import '../items/item_list_screen.dart';
import '../reports/item_report_screen.dart';
import '../reports/patient_report_screen.dart';
import '../reports/payment_report_screen.dart';
import '../reports/user_report_screen.dart';

class HomeScreen extends StatelessWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

  String get welcomeMessage {
    switch (user.role) {
      case 'admin':
        return 'Admin Dashboard';
      case 'accountant':
        return 'Accountant Dashboard';
      case 'cashier':
        return 'Cashier Dashboard';
      default:
        return 'Welcome';
    }
  }

  String get userInitials {
    return '${user.firstName[0]}${user.lastName[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(welcomeMessage),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text('${user.firstName} ${user.lastName}'),
              accountEmail: Text('@${user.username} - ${user.role.toUpperCase()}'),
              currentAccountPicture: CircleAvatar(
                child: Text(userInitials),
              ),
            ),
            _buildDrawerItem(
              context,
              icon: Icons.person,
              title: 'Patients',
              onTap: () => _navigateTo(context, PatientListScreen(currentUser: user)),
            ),
            _buildDrawerItem(
              context,
              icon: Icons.payment,
              title: 'Process Payment',
              onTap: () => _navigateTo(context, ProcessPaymentScreen(user: user)),
            ),
            if (user.role == 'admin' || user.role == 'accountant')
              _buildDrawerItem(
                context,
                icon: Icons.history,
                title: 'All Payment History',
                onTap: () => _navigateTo(context, PaymentHistoryScreen(showAll: true)),
              ),
            if (user.role == 'cashier')
              _buildDrawerItem(
                context,
                icon: Icons.history,
                title: 'My Payment History',
                onTap: () => _navigateTo(context, PaymentHistoryScreen(
                  showAll: false,
                  userId: user.userId,
                )),
              ),
            if (user.role == 'admin') ...[
              _buildDrawerItem(
                context,
                icon: Icons.inventory,
                title: 'Manage Items',
                onTap: () => _navigateTo(context,  ItemListScreen()),
              ),
              _buildDrawerItem(
                context,
                icon: Icons.people,
                title: 'User Management',
                onTap: () => _navigateTo(context, const UserListScreen()),
              ),
            ],
            if (user.role == 'admin' || user.role == 'cashier')
              ExpansionTile(
                leading: const Icon(Icons.assessment),
                title: const Text('Reports'),
                children: [
                  _buildReportItem('Patient Report', () => _navigateTo(context, PatientReportScreen())),
                  _buildReportItem('Payment Report', () => _navigateTo(context, PaymentReportScreen(user: user))),
                  if (user.role == 'admin') ...[
                    _buildReportItem('Item Report', () => _navigateTo(context, ItemReportScreen())),
                    _buildReportItem('User Report', () => _navigateTo(context, UserReportScreen())),
                  ],
                ],
              ),
            const Divider(),
            _buildDrawerItem(
              context,
              icon: Icons.settings,
              title: 'Settings',
              onTap: () {},
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.medical_services, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            Text(
              'Welcome to TibaPay',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(
              '${user.firstName} ${user.lastName}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 5),
            Text(
              '(${user.role.toUpperCase()})',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            if (user.role == 'admin')
              _buildAdminQuickActions(context),
          ],
        ),
      ),
      floatingActionButton: user.role == 'cashier' || user.role == 'admin'
          ? FloatingActionButton(
              onPressed: () => _navigateTo(context, ProcessPaymentScreen(user: user)),
              tooltip: 'New Payment',
              child: const Icon(Icons.payment),
            )
          : null,
    );
  }

  Widget _buildDrawerItem(BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget _buildReportItem(String title, VoidCallback onTap) {
    return ListTile(
      title: Text(title),
      onTap: onTap,
    );
  }

  Widget _buildAdminQuickActions(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ActionChip(
          avatar: const Icon(Icons.people, size: 18),
          label: const Text('Manage Users'),
          onPressed: () => _navigateTo(context, const UserListScreen()),
        ),
        ActionChip(
          avatar: const Icon(Icons.settings, size: 18),
          label: const Text('System Settings'),
          onPressed: () {},
        ),
      ],
    );
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}