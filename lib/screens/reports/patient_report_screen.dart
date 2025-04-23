import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tiba_pay/models/patient.dart';
import 'package:tiba_pay/repositories/patient_repository.dart';
import 'package:tiba_pay/utils/database_helper.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class PatientReportScreen extends StatefulWidget {
  const PatientReportScreen({super.key});

  @override
  _PatientReportScreenState createState() => _PatientReportScreenState();
}

class _PatientReportScreenState extends State<PatientReportScreen> {
  final _patientRepository = PatientRepository(dbHelper: DatabaseHelper.instance);
  List<Patient> _patients = [];
  bool _isLoading = false;
  int _rowsPerPage = 10;
  int _currentPage = 0;
  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoading = true);
    try {
      final patients = await _patientRepository.getAllPatients();
      setState(() {
        _patients = patients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading patients: ${e.toString()}')),
      );
    }
  }

  List<Patient> _getFilteredPatients() {
    var filtered = _patients;
    
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((patient) {
        return patient.patientNumber.toLowerCase().contains(query) ||
               patient.fullName.toLowerCase().contains(query) ||
               (patient.phoneNumber?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
    
    if (_startDate != null) {
      filtered = filtered.where((patient) => 
        patient.createdAt.isAfter(_startDate!)).toList();
    }
    
    if (_endDate != null) {
      filtered = filtered.where((patient) => 
        patient.createdAt.isBefore(_endDate!.add(const Duration(days: 1)))).toList();
    }
    
    return filtered;
  }

  Future<void> _exportToPdf() async {
    final filteredPatients = _getFilteredPatients();
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('Patient Report', 
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                border: pw.TableBorder.all(),
                headers: ['S/N', 'Patient No', 'Full Name', 'Sponsor', 'Phone', 'Address', 'Created At'],
                data: filteredPatients.asMap().entries.map((entry) {
                  final i = entry.key;
                  final patient = entry.value;
                  return [
                    i + 1,
                    patient.patientNumber,
                    patient.fullName,
                    patient.sponsor,
                    patient.phoneNumber ?? 'N/A',
                    patient.address ?? 'N/A',
                    DateFormat('yyyy-MM-dd').format(patient.createdAt),
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
    final filteredPatients = _getFilteredPatients();
    final excel = Excel.createExcel();
    final sheet = excel['Patient Report'];

    // Add headers
    sheet.appendRow(['S/N', 'Patient No', 'Full Name', 'Sponsor', 'Phone', 'Address', 'Created At']);

    // Add data
    for (var i = 0; i < filteredPatients.length; i++) {
      final patient = filteredPatients[i];
      sheet.appendRow([
        i + 1,
        patient.patientNumber,
        patient.fullName,
        patient.sponsor,
        patient.phoneNumber ?? 'N/A',
        patient.address ?? 'N/A',
        DateFormat('yyyy-MM-dd').format(patient.createdAt),
      ]);
    }

    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/patient_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(excel.encode()!);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Excel file saved to: $filePath')),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredPatients = _getFilteredPatients();
    final pageCount = (filteredPatients.length / _rowsPerPage).ceil();
    final paginatedPatients = filteredPatients
        .skip(_currentPage * _rowsPerPage)
        .take(_rowsPerPage)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Report'),
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
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _selectDate(context, true),
                            child: Text(_startDate == null 
                              ? 'Select Start Date' 
                              : 'From: ${DateFormat('yyyy-MM-dd HH:mm').format(_startDate!)}'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _selectDate(context, false),
                            child: Text(_endDate == null 
                              ? 'Select End Date' 
                              : 'To: ${DateFormat('yyyy-MM-dd HH:mm').format(_endDate!)}'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        DropdownButton<int>(
                          value: _rowsPerPage,
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
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      border: TableBorder.all(color: Colors.grey),
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(label: Text('S/N')),
                        DataColumn(label: Text('Patient No')),
                        DataColumn(label: Text('Full Name')),
                        DataColumn(label: Text('Sponsor')),
                        DataColumn(label: Text('Phone')),
                        DataColumn(label: Text('Address')),
                        DataColumn(label: Text('Created At')),
                      ],
                      rows: paginatedPatients.asMap().entries.map((entry) {
                        final index = entry.key;
                        final patient = entry.value;
                        final serialNumber = (_currentPage * _rowsPerPage) + index + 1;
                        
                        return DataRow(cells: [
                          DataCell(Text(serialNumber.toString())),
                          DataCell(Text(patient.patientNumber)),
                          DataCell(Text(patient.fullName)),
                          DataCell(Text(patient.sponsor)),
                          DataCell(Text(patient.phoneNumber ?? 'N/A')),
                          DataCell(Text(patient.address ?? 'N/A')),
                          DataCell(Text(DateFormat('yyyy-MM-dd HH:mm').format(patient.createdAt))),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
          ),
          if (filteredPatients.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage == 0 ? null : () {
                      setState(() => _currentPage--);
                    },
                  ),
                  Text('Page ${_currentPage + 1} of $pageCount'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage == pageCount - 1 ? null : () {
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