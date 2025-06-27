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
import 'package:permission_handler/permission_handler.dart';

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
  int _totalRecords = 0;
  
  // Filter controllers
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _patientNumberController = TextEditingController();
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _sponsorController = TextEditingController();
  final TextEditingController _createdByController = TextEditingController();
  
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Get total count with current filters
      final count = await _patientRepository.getPatientsCount(
        searchQuery: _searchController.text.isNotEmpty ? _searchController.text : null,
        patientNumber: _patientNumberController.text.isNotEmpty ? _patientNumberController.text : null,
        patientName: _patientNameController.text.isNotEmpty ? _patientNameController.text : null,
        sponsor: _sponsorController.text.isNotEmpty ? _sponsorController.text : null,
        createdBy: _createdByController.text.isNotEmpty ? int.tryParse(_createdByController.text) : null,
        startDate: _startDate,
        endDate: _endDate,
      );

      // Get paginated data
      final patients = await _patientRepository.getAllPatients(
        limit: _rowsPerPage == -1 ? null : _rowsPerPage,
        offset: _rowsPerPage == -1 ? null : _currentPage * _rowsPerPage,
        searchQuery: _searchController.text.isNotEmpty ? _searchController.text : null,
        patientNumber: _patientNumberController.text.isNotEmpty ? _patientNumberController.text : null,
        patientName: _patientNameController.text.isNotEmpty ? _patientNameController.text : null,
        sponsor: _sponsorController.text.isNotEmpty ? _sponsorController.text : null,
        createdBy: _createdByController.text.isNotEmpty ? int.tryParse(_createdByController.text) : null,
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() {
        _totalRecords = count;
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

  Future<void> _exportToPdf() async {
    final filteredPatients = await _getAllFilteredPatients();
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
                    DateFormat('yyyy-MM-dd HH:mm').format(patient.createdAt),
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

  Future<List<Patient>> _getAllFilteredPatients() async {
    return await _patientRepository.getAllPatients(
      searchQuery: _searchController.text.isNotEmpty ? _searchController.text : null,
      patientNumber: _patientNumberController.text.isNotEmpty ? _patientNumberController.text : null,
      patientName: _patientNameController.text.isNotEmpty ? _patientNameController.text : null,
      sponsor: _sponsorController.text.isNotEmpty ? _sponsorController.text : null,
      createdBy: _createdByController.text.isNotEmpty ? int.tryParse(_createdByController.text) : null,
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  Future<String?> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          return null;
        }
      }
      
      Directory? directory;
      try {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } catch (e) {
        directory = await getExternalStorageDirectory();
      }
      return directory?.path;
    } else if (Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
    return null;
  }

  Future<void> _exportToExcel() async {
    final filteredPatients = await _getAllFilteredPatients();
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
        DateFormat('yyyy-MM-dd HH:mm').format(patient.createdAt),
      ]);
    }

    // Try to save to Downloads folder first
    String? downloadsPath = await _getDownloadsDirectory();
    String filePath;
    
    if (downloadsPath != null) {
      filePath = '$downloadsPath/patient_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    } else {
      final directory = await getApplicationDocumentsDirectory();
      filePath = '${directory.path}/patient_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    }

    try {
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);
      
      if (Platform.isAndroid) {
        await file.create(recursive: true);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excel file saved to: $filePath'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () async {
              if (await File(filePath).exists()) {
                if (Platform.isAndroid) {
                  await Process.run('am', ['start', '-t', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', '-d', 'file://$filePath']);
                }
              }
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving file: ${e.toString()}')),
      );
    }
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
        _currentPage = 0;
        _loadData();
      });
    }
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    controller.clear();
                    setState(() {
                      _currentPage = 0;
                      _loadData();
                    });
                  },
                ),
        ),
        onChanged: (value) {
          _currentPage = 0;
          _loadData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showAll = _rowsPerPage == -1;
    final pageCount = showAll ? 1 : (_totalRecords / _rowsPerPage).ceil();

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
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            _buildSearchField(
                              controller: _searchController,
                              label: 'Search all fields',
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _selectDate(context, true),
                                    child: Text(_startDate == null 
                                      ? 'Select Start Date' 
                                      : 'From: ${DateFormat('yyyy-MM-dd').format(_startDate!)}'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _selectDate(context, false),
                                    child: Text(_endDate == null 
                                      ? 'Select End Date' 
                                      : 'To: ${DateFormat('yyyy-MM-dd').format(_endDate!)}'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSearchField(
                                    controller: _patientNumberController,
                                    label: 'Filter by Patient No',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildSearchField(
                                    controller: _patientNameController,
                                    label: 'Filter by Patient Name',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSearchField(
                                    controller: _sponsorController,
                                    label: 'Filter by Sponsor',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildSearchField(
                                    controller: _createdByController,
                                    label: 'Filter by Created By (ID)',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButton<int>(
                                    value: _rowsPerPage,
                                    items: [
                                      DropdownMenuItem(value: 10, child: Text('10 items')),
                                      DropdownMenuItem(value: 25, child: Text('25 items')),
                                      DropdownMenuItem(value: 50, child: Text('50 items')),
                                      DropdownMenuItem(value: -1, child: Text('All items')),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _rowsPerPage = value!;
                                        _currentPage = 0;
                                        _loadData();
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Records: $_totalRecords',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _isLoading 
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
                            rows: _patients.asMap().entries.map((entry) {
                              final index = entry.key;
                              final patient = entry.value;
                              final serialNumber = showAll 
                                  ? index + 1 
                                  : (_currentPage * _rowsPerPage) + index + 1;
                              
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
                ],
              ),
            ),
          ),
          if (!showAll && _totalRecords > 0)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.first_page),
                    onPressed: _currentPage > 0
                        ? () {
                            setState(() {
                              _currentPage = 0;
                              _loadData();
                            });
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 0
                        ? () {
                            setState(() {
                              _currentPage--;
                              _loadData();
                            });
                          }
                        : null,
                  ),
                  Text(
                    'Page ${_currentPage + 1} of $pageCount\n'
                    'Showing ${_currentPage * _rowsPerPage + 1}-'
                    '${_currentPage * _rowsPerPage + _patients.length} '
                    'of $_totalRecords',
                    textAlign: TextAlign.center,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < pageCount - 1
                        ? () {
                            setState(() {
                              _currentPage++;
                              _loadData();
                            });
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.last_page),
                    onPressed: _currentPage < pageCount - 1
                        ? () {
                            setState(() {
                              _currentPage = pageCount - 1;
                              _loadData();
                            });
                          }
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}