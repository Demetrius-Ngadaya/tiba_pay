import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tiba_pay/models/item.dart';
import 'package:tiba_pay/repositories/item_repository.dart';
import 'package:tiba_pay/utils/database_helper.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class ItemReportScreen extends StatefulWidget {
  const ItemReportScreen({super.key});

  @override
  _ItemReportScreenState createState() => _ItemReportScreenState();
}

class _ItemReportScreenState extends State<ItemReportScreen> {
  final _itemRepository = ItemRepository(dbHelper: DatabaseHelper.instance);
  List<Item> _items = [];
  bool _isLoading = false;
  int _rowsPerPage = 10;
  int _currentPage = 0;
  int _totalRecords = 0;
  
  // Filter controllers
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedSponsor = 'All';
  String? _selectedStatus;
  
  List<String> _categories = ['All'];
  List<String> _sponsors = ['All'];
  final List<String> statusOptions = ['All', 'Active', 'Inactive'];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadDistinctValues();
  }

  Future<void> _loadDistinctValues() async {
    final categories = await _itemRepository.getDistinctCategories();
    final sponsors = await _itemRepository.getDistinctSponsors();
    
    setState(() {
      _categories = ['All', ...categories];
      _sponsors = ['All', ...sponsors];
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Get total count with current filters
      final count = await _itemRepository.getItemsCount(
        searchQuery: _searchController.text.isNotEmpty ? _searchController.text : null,
        category: _selectedCategory != 'All' ? _selectedCategory : null,
        sponsor: _selectedSponsor != 'All' ? _selectedSponsor : null,
        isActive: _selectedStatus == 'Active' 
          ? true 
          : _selectedStatus == 'Inactive' 
            ? false 
            : null,
      );

      // Get paginated data
      final items = await _itemRepository.getAllItems(
        limit: _rowsPerPage == -1 ? null : _rowsPerPage,
        offset: _rowsPerPage == -1 ? null : _currentPage * _rowsPerPage,
        searchQuery: _searchController.text.isNotEmpty ? _searchController.text : null,
        category: _selectedCategory != 'All' ? _selectedCategory : null,
        sponsor: _selectedSponsor != 'All' ? _selectedSponsor : null,
        isActive: _selectedStatus == 'Active' 
          ? true 
          : _selectedStatus == 'Inactive' 
            ? false 
            : null,
      );

      setState(() {
        _totalRecords = count;
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading items: ${e.toString()}')),
      );
    }
  }

  Future<void> _exportToPdf() async {
    final filteredItems = await _getAllFilteredItems();
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('Item Report', 
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                border: pw.TableBorder.all(),
                headers: ['S/N', 'Item Name', 'Department', 'Price', 'Sponsor', 'Status', 'Created At'],
                data: filteredItems.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return [
                    i + 1,
                    item.itemName,
                    item.itemCategory,
                    item.itemPrice.toStringAsFixed(2),
                    item.itemSponsor,
                    item.isActive ? 'Active' : 'Inactive',
                    DateFormat('yyyy-MM-dd HH:mm').format(item.createdAt),
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

  Future<List<Item>> _getAllFilteredItems() async {
    return await _itemRepository.getAllItems(
      searchQuery: _searchController.text.isNotEmpty ? _searchController.text : null,
      category: _selectedCategory != 'All' ? _selectedCategory : null,
      sponsor: _selectedSponsor != 'All' ? _selectedSponsor : null,
      isActive: _selectedStatus == 'Active' 
        ? true 
        : _selectedStatus == 'Inactive' 
          ? false 
          : null,
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
    final filteredItems = await _getAllFilteredItems();
    final excel = Excel.createExcel();
    final sheet = excel['Item Report'];

    // Add headers
    sheet.appendRow(['S/N', 'Item Name', 'Department', 'Price', 'Sponsor', 'Status', 'Created At']);

    // Add data
    for (var i = 0; i < filteredItems.length; i++) {
      final item = filteredItems[i];
      sheet.appendRow([
        i + 1,
        item.itemName,
        item.itemCategory,
        item.itemPrice.toStringAsFixed(2),
        item.itemSponsor,
        item.isActive ? 'Active' : 'Inactive',
        DateFormat('yyyy-MM-dd HH:mm').format(item.createdAt),
      ]);
    }

    // Try to save to Downloads folder first
    String? downloadsPath = await _getDownloadsDirectory();
    String filePath;
    
    if (downloadsPath != null) {
      filePath = '$downloadsPath/item_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    } else {
      final directory = await getApplicationDocumentsDirectory();
      filePath = '${directory.path}/item_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
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
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
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
        title: const Text('Item Report'),
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
                            // Search Field
                            _buildSearchField(
                              controller: _searchController,
                              label: 'Search items',
                            ),
                            const SizedBox(height: 10),
                            
                            // Horizontal scrollable filters
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  // Department Filter
                                  SizedBox(
                                    width: MediaQuery.of(context).size.width * 0.45,
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedCategory,
                                      decoration: const InputDecoration(
                                        labelText: 'Department',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                      ),
                                      items: _categories.map((category) {
                                        return DropdownMenuItem<String>(
                                          value: category,
                                          child: Text(
                                            category,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedCategory = value!;
                                          _currentPage = 0;
                                          _loadData();
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  
                                  // Sponsor Filter
                                  SizedBox(
                                    width: MediaQuery.of(context).size.width * 0.45,
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedSponsor,
                                      decoration: const InputDecoration(
                                        labelText: 'Sponsor',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                      ),
                                      items: _sponsors.map((sponsor) {
                                        return DropdownMenuItem<String>(
                                          value: sponsor,
                                          child: Text(
                                            sponsor,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedSponsor = value!;
                                          _currentPage = 0;
                                          _loadData();
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  
                                  // Status Filter
                                  SizedBox(
                                    width: MediaQuery.of(context).size.width * 0.45,
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedStatus,
                                      decoration: const InputDecoration(
                                        labelText: 'Status',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                      ),
                                      items: statusOptions.map((status) {
                                        return DropdownMenuItem<String>(
                                          value: status != 'All' ? status : null,
                                          child: Text(
                                            status,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedStatus = value;
                                          _currentPage = 0;
                                          _loadData();
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            
                            // Rows per page selector
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                DropdownButton<int>(
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
                              DataColumn(label: Text('Item Name')),
                              DataColumn(label: Text('Department')),
                              DataColumn(label: Text('Price'), numeric: true),
                              DataColumn(label: Text('Sponsor')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Created At')),
                            ],
                            rows: _items.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              final serialNumber = showAll 
                                  ? index + 1 
                                  : (_currentPage * _rowsPerPage) + index + 1;
                              
                              return DataRow(cells: [
                                DataCell(Text(serialNumber.toString())),
                                DataCell(Text(item.itemName)),
                                DataCell(Text(item.itemCategory)),
                                DataCell(Text(item.itemPrice.toStringAsFixed(2))),
                                DataCell(Text(item.itemSponsor)),
                                DataCell(Text(item.isActive ? 'Active' : 'Inactive')),
                                DataCell(Text(DateFormat('yyyy-MM-dd HH:mm').format(item.createdAt))),
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
                    '${_currentPage * _rowsPerPage + _items.length} '
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