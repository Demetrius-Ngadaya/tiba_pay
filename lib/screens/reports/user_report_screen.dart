import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tiba_pay/models/user.dart';
import 'package:tiba_pay/repositories/user_repository.dart';
import 'package:tiba_pay/utils/database_helper.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class UserReportScreen extends StatefulWidget {
  const UserReportScreen({super.key});

  @override
  _UserReportScreenState createState() => _UserReportScreenState();
}

class _UserReportScreenState extends State<UserReportScreen> {
  final _userRepository = UserRepository(dbHelper: DatabaseHelper.instance);
  List<User> _users = [];
  bool _isLoading = false;
  int _rowsPerPage = 10;
  int _currentPage = 0;
  final TextEditingController _searchController = TextEditingController();
  String _selectedRole = 'All';
  String _selectedStatus = 'All';

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
    var filtered = _users;

    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((user) {
        return user.username.toLowerCase().contains(query) ||
            user.firstName.toLowerCase().contains(query) ||
            user.lastName.toLowerCase().contains(query);
      }).toList();
    }

    if (_selectedRole != 'All') {
      filtered =
          filtered.where((user) => user.role == _selectedRole).toList();
    }

    if (_selectedStatus != 'All') {
      filtered =
          filtered.where((user) => user.status == _selectedStatus).toList();
    }

    return filtered;
  }

  Future<void> _exportToPdf() async {
    final filteredUsers = _getFilteredUsers();
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('User Report',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                border: pw.TableBorder.all(),
                headers: ['S/N', 'Full Name', 'Username', 'Role', 'Status', 'Created At'],
                data: filteredUsers.asMap().entries.map((entry) {
                  final i = entry.key;
                  final user = entry.value;
                  return [
                    i + 1,
                    '${user.firstName} ${user.middleName ?? ''} ${user.lastName}'.trim(),
                    user.username,
                    user.role,
                    user.status,
                    user.createdAt,
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> _exportToExcel() async {
    final filteredUsers = _getFilteredUsers();
    final excel = Excel.createExcel();
    final sheet = excel['User Report'];

    sheet.appendRow(['S/N', 'Full Name', 'Username', 'Role', 'Status', 'Created At']);

    for (var i = 0; i < filteredUsers.length; i++) {
      final user = filteredUsers[i];
      sheet.appendRow([
        i + 1,
        '${user.firstName} ${user.middleName ?? ''} ${user.lastName}'.trim(),
        user.username,
        user.role,
        user.status,
        user.createdAt,
      ]);
    }

    final directory = await getApplicationDocumentsDirectory();
    final filePath =
        '${directory.path}/user_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(excel.encode()!);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Excel file saved to: $filePath')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _getFilteredUsers();
    final pageCount = (filteredUsers.length / _rowsPerPage).ceil();
    final paginatedUsers = filteredUsers
        .skip(_currentPage * _rowsPerPage)
        .take(_rowsPerPage)
        .toList();
    final roles = ['All', ..._users.map((u) => u.role).toSet().toList()];
    final statuses = ['All', ..._users.map((u) => u.status).toSet().toList()];

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportToPdf,
          ),
          IconButton(
            icon: const Icon(Icons.grid_on),
            onPressed: _exportToExcel,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Search',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        ),
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 200,
                            child: DropdownButtonFormField<String>(
                              value: _selectedRole,
                              decoration: const InputDecoration(
                                labelText: 'Filter by Role',
                                border: OutlineInputBorder(),
                              ),
                              items: roles.map((role) {
                                return DropdownMenuItem<String>(
                                  value: role,
                                  child: Text(role),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedRole = value!;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 200,
                            child: DropdownButtonFormField<String>(
                              value: _selectedStatus,
                              decoration: const InputDecoration(
                                labelText: 'Filter by Status',
                                border: OutlineInputBorder(),
                              ),
                              items: statuses.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedStatus = value!;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 150,
                            child: DropdownButtonFormField<int>(
                              value: _rowsPerPage,
                              decoration: const InputDecoration(
                                labelText: 'Items per page',
                                border: OutlineInputBorder(),
                              ),
                              items: [10, 25, 50, 100].map((value) {
                                return DropdownMenuItem<int>(
                                  value: value,
                                  child: Text('$value items'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _rowsPerPage = value!;
                                  _currentPage = 0;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
                        border: TableBorder.all(color: Colors.grey),
                        columnSpacing: 20,
                        columns: const [
                          DataColumn(label: Text('S/N')),
                          DataColumn(label: Text('Full Name')),
                          DataColumn(label: Text('Username')),
                          DataColumn(label: Text('Role')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Created At')),
                        ],
                        rows: paginatedUsers.asMap().entries.map((entry) {
                          final index = entry.key;
                          final user = entry.value;
                          final serialNumber =
                              (_currentPage * _rowsPerPage) + index + 1;

                          return DataRow(cells: [
                            DataCell(Text(serialNumber.toString())),
                            DataCell(Text(
                                '${user.firstName} ${user.middleName ?? ''} ${user.lastName}'.trim())),
                            DataCell(Text(user.username)),
                            DataCell(Text(user.role)),
                            DataCell(Text(user.status)),
                            DataCell(Text(user.createdAt)),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
          ),
          if (filteredUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage == 0
                        ? null
                        : () {
                            setState(() => _currentPage--);
                          },
                  ),
                  Text('Page ${_currentPage + 1} of $pageCount'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage == pageCount - 1
                        ? null
                        : () {
                            setState(() => _currentPage++);
                          },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
