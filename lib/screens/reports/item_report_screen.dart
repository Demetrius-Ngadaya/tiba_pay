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
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _itemRepository.getAllItems();
      setState(() {
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

  List<Item> _getFilteredItems() {
    var filtered = _items;
    
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((item) {
        return item.itemName.toLowerCase().contains(query) ||
               item.itemCategory.toLowerCase().contains(query);
      }).toList();
    }
    
    if (_selectedCategory != 'All') {
      filtered = filtered.where((item) => 
        item.itemCategory == _selectedCategory).toList();
    }
    
    return filtered;
  }

  Future<void> _exportToPdf() async {
    final filteredItems = _getFilteredItems();
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

  Future<void> _exportToExcel() async {
    final filteredItems = _getFilteredItems();
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

    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/item_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(excel.encode()!);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Excel file saved to: $filePath')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getFilteredItems();
    final pageCount = (filteredItems.length / _rowsPerPage).ceil();
    final paginatedItems = filteredItems
        .skip(_currentPage * _rowsPerPage)
        .take(_rowsPerPage)
        .toList();
    final categories = ['All', ..._items.map((i) => i.itemCategory).toSet().toList()];

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
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Filter by Department',
                              border: OutlineInputBorder(),
                            ),
                            items: categories.map((category) {
                              return DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCategory = value!;
                              });
                            },
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
                        DataColumn(label: Text('Item Name')),
                        DataColumn(label: Text('Department')),
                        DataColumn(label: Text('Price'), numeric: true),
                        DataColumn(label: Text('Sponsor')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Created At')),
                      ],
                      rows: paginatedItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final serialNumber = (_currentPage * _rowsPerPage) + index + 1;
                        
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
          ),
          if (filteredItems.isNotEmpty)
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