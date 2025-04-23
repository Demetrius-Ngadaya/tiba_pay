import 'package:flutter/material.dart';
import 'package:tiba_pay/models/patient.dart';
import 'package:tiba_pay/models/user.dart';
import 'package:tiba_pay/repositories/patient_repository.dart';
import 'package:tiba_pay/utils/database_helper.dart';
import 'patient_edit_screen.dart';

class PatientListScreen extends StatefulWidget {
  final User currentUser;

  const PatientListScreen({super.key, required this.currentUser});

  @override
  _PatientListScreenState createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final PatientRepository _patientRepository =
      PatientRepository(dbHelper: DatabaseHelper.instance);
  List<Patient> _patients = [];
  List<Patient> _filteredPatients = [];
  bool _isLoading = true;
  int _rowsPerPage = 10;
  int _currentPage = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _searchController.addListener(_filterPatients);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    try {
      final patients = await _patientRepository.getAllPatients();
      setState(() {
        _patients = patients;
        _filteredPatients = patients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading patients: ${e.toString()}')),
      );
    }
  }

  void _filterPatients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPatients = _patients.where((patient) {
        return patient.fullName.toLowerCase().contains(query) ||
            patient.patientNumber.toLowerCase().contains(query);
      }).toList();
      _currentPage = 0; // Reset to first page when filtering
    });
  }

  Future<void> _navigateToAddPatient() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientEditScreen(currentUser: widget.currentUser),
      ),
    );

    if (result == true) {
      await _loadPatients();
    }
  }

  Future<void> _deletePatient(Patient patient) async {
    try {
      await _patientRepository.deletePatient(patient.patientNumber);
      await _loadPatients();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting patient: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = (_filteredPatients.length / _rowsPerPage).ceil();
    final paginatedPatients = _filteredPatients
        .skip(_currentPage * _rowsPerPage)
        .take(_rowsPerPage)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPatients,
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
                        labelText: 'Search by name or patient number',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filterPatients();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButton<int>(
                            value: _rowsPerPage,
                            items: [10, 25, 50, 100].map((value) {
                              return DropdownMenuItem<int>(
                                value: value,
                                child: Text('$value items per page'),
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
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPatients.isEmpty
                    ? const Center(child: Text('No patients found'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            border: TableBorder.all(color: Colors.grey),
                            columnSpacing: 20,
                            columns: const [
                              DataColumn(label: Text('S/N')),
                              DataColumn(label: Text('Patient Number')),
                              DataColumn(label: Text('Full Name')),
                              DataColumn(label: Text('Sponsor')),
                              DataColumn(label: Text('Phone')),
                              DataColumn(label: Text('Created By')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: paginatedPatients.map((patient) {
                              return DataRow(cells: [
                                DataCell(Text(
                                    (paginatedPatients.indexOf(patient) + 1 + (_currentPage * _rowsPerPage)).toString())),
                                DataCell(Text(patient.patientNumber)),
                                DataCell(Text(patient.fullName)),
                                DataCell(Text(patient.sponsor)),
                                DataCell(Text(patient.phoneNumber ?? 'N/A')),
                                DataCell(Text(patient.createdBy)),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () async {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => PatientEditScreen(
                                                patient: patient,
                                                currentUser: widget.currentUser,
                                              ),
                                            ),
                                          );
                                          if (result == true) {
                                            await _loadPatients();
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deletePatient(patient),
                                      ),
                                    ],
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
          ),
          if (_filteredPatients.isNotEmpty)
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
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddPatient,
        tooltip: 'Add Patient',
        child: const Icon(Icons.add),
      ),
    );
  }
}