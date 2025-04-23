import 'package:flutter/material.dart';
import 'package:tiba_pay/models/user.dart';
import 'package:tiba_pay/repositories/user_repository.dart';
import 'package:tiba_pay/utils/database_helper.dart';
import 'package:tiba_pay/screens/admin/user_edit_screen.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  _UserListScreenState createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final _userRepository = UserRepository(dbHelper: DatabaseHelper.instance);
  List<User> _users = [];
  bool _isLoading = true;
  int _rowsPerPage = 10;
  int _currentPage = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
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
        SnackBar(content: Text('Error loading users: ${e.toString()}')),
      );
    }
  }

  List<User> _getFilteredUsers() {
    if (_searchController.text.isEmpty) return _users;
    
    final query = _searchController.text.toLowerCase();
    return _users.where((user) {
      return user.username.toLowerCase().contains(query) ||
             user.firstName.toLowerCase().contains(query) ||
             user.lastName.toLowerCase().contains(query) ||
             user.role.toLowerCase().contains(query) ||
             user.status.toLowerCase().contains(query);
    }).toList();
  }

  void _refreshUsers() {
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _getFilteredUsers();
    final pageCount = (filteredUsers.length / _rowsPerPage).ceil();
    final paginatedUsers = filteredUsers
        .skip(_currentPage * _rowsPerPage)
        .take(_rowsPerPage)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Users',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() {
                _currentPage = 0;
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                const Text('Rows per page:'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _rowsPerPage,
                  items: [10, 25, 50, 100].map((value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _rowsPerPage = value!;
                      _currentPage = 0;
                    });
                  },
                ),
                const Spacer(),
                Text('${_currentPage * _rowsPerPage + 1}-${(_currentPage + 1) * _rowsPerPage > filteredUsers.length ? filteredUsers.length : (_currentPage + 1) * _rowsPerPage} of ${filteredUsers.length}'),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage == 0 ? null : () {
                    setState(() => _currentPage--);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentPage >= pageCount - 1 ? null : () {
                    setState(() => _currentPage++);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      border: TableBorder.all(
                        color: Colors.grey,
                        width: 1.0,
                        style: BorderStyle.solid,
                      ),
                      columns: const [
                        DataColumn(label: Text('S/N')),
                        DataColumn(label: Text('Full Name')),
                        DataColumn(label: Text('Username')),
                        DataColumn(label: Text('Role')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Created By')),
                        DataColumn(label: Text('Created At')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: paginatedUsers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final user = entry.value;
                        final serialNumber = (_currentPage * _rowsPerPage) + index + 1;
                        
                        return DataRow(
                          cells: [
                            DataCell(Text(serialNumber.toString())),
                            DataCell(Text('${user.firstName} ${user.middleName ?? ''} ${user.lastName}'.trim())),
                            DataCell(Text(user.username)),
                            DataCell(Text(user.role)),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: user.status == 'Active'
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(user.status),
                              ),
                            ),
                            DataCell(Text(user.createdBy ?? 'System')),
                            DataCell(Text(user.createdAt)),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => UserEditScreen(user: user),
                                    ),
                                  ).then((_) => _refreshUsers());
                                },
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UserEditScreen(),
            ),
          ).then((_) => _refreshUsers());
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}