import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tiba_pay/models/user.dart';
import 'package:tiba_pay/repositories/user_repository.dart';
import 'package:tiba_pay/utils/database_helper.dart';
import 'package:tiba_pay/screens/admin/user_edit_screen.dart';

class UserListScreen extends StatefulWidget {
  final User currentUser;

  const UserListScreen({super.key, required this.currentUser});

  @override
  _UserListScreenState createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final UserRepository _userRepository = UserRepository(dbHelper: DatabaseHelper.instance);
  List<User> _users = [];
  bool _isLoading = true;
  int _rowsPerPage = 10;
  int _currentPage = 1;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _userRepository.getAllUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load users: $e')),
      );
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _users = _users.where((user) {
        return user.username.toLowerCase().contains(query) ||
               user.firstName.toLowerCase().contains(query) ||
               user.lastName.toLowerCase().contains(query) ||
               user.role.toLowerCase().contains(query) ||
               user.createdBy.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _deleteUser(int userId) async {
    try {
      await _userRepository.deleteUser(userId);
      _loadUsers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete user: $e')),
      );
    }
  }

  void _confirmDelete(User user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${user.username}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteUser(user.userId!);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_users.length / _rowsPerPage).ceil();
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    final paginatedUsers = _users.sublist(
      startIndex.clamp(0, _users.length),
      endIndex.clamp(0, _users.length),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Username')),
                          DataColumn(label: Text('Full Name')),
                          DataColumn(label: Text('Role')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Created By')),
                          DataColumn(label: Text('Created At')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: paginatedUsers.map((user) {
                          return DataRow(cells: [
                            DataCell(Text(user.username)),
                            DataCell(Text(user.fullName)),
                            DataCell(Text(user.role)),
                            DataCell(
                              Chip(
                                label: Text(
                                  user.status,
                                  style: TextStyle(
                                    color: user.status == 'active' ? Colors.green : Colors.red,
                                  ),
                                ),
                                backgroundColor: user.status == 'active'
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                              ),
                            ),
                            DataCell(Text(user.createdBy)),
                            DataCell(Text(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(user.createdAt)))),
                            DataCell(Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (ctx) => UserEditScreen(
                                        user: user,
                                        currentUser: widget.currentUser,
                                      ),
                                    ),
                                  ).then((_) => _loadUsers()),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _confirmDelete(user),
                                ),
                              ],
                            )),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 1
                      ? () => setState(() => _currentPage--)
                      : null,
                ),
                Text('Page $_currentPage of $totalPages'),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentPage < totalPages
                      ? () => setState(() => _currentPage++)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => UserEditScreen(currentUser: widget.currentUser),
          ),
        ).then((_) => _loadUsers()),
        child: const Icon(Icons.add),
      ),
    );
  }
}