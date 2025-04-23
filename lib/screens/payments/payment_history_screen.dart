import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tiba_pay/models/payment.dart';
import 'package:tiba_pay/repositories/payment_repository.dart';
import 'package:tiba_pay/utils/database_helper.dart';

class PaymentHistoryScreen extends StatefulWidget {
  final bool showAll;
  final int? userId;

  const PaymentHistoryScreen({
    super.key,
    required this.showAll,
    this.userId,
  });

  @override
  _PaymentHistoryScreenState createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final _paymentRepository = PaymentRepository(dbHelper: DatabaseHelper.instance);
  final _scrollController = ScrollController();
  final NumberFormat _currencyFormat = NumberFormat("#,##0.00", "en_US");

  List<Payment> _payments = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 0;
  int _rowsPerPage = 10;
  int _currentPage = 0;

  // Filter variables
  final TextEditingController _searchController = TextEditingController();
  String _searchType = 'Patient Number';
  final List<String> _searchTypes = ['Patient Number', 'Patient Name', 'Item Category'];
  String? _selectedCategoryFilter;

  @override
  void initState() {
    super.initState();
    _loadInitialPayments();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialPayments() async {
    setState(() {
      _isLoading = true;
      _page = 0;
      _currentPage = 0;
    });

    try {
      final payments = widget.showAll
          ? await _paymentRepository.getAllPaymentsWithDetails(limit: _rowsPerPage, offset: 0)
          : await _paymentRepository.getPaymentsByUser(widget.userId!, limit: _rowsPerPage, offset: 0);

      setState(() {
        _payments = payments;
        _isLoading = false;
        _hasMore = payments.length == _rowsPerPage;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading payments: ${e.toString()}')),
      );
    }
  }

  Future<void> _loadMorePayments() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);
    _page++;

    try {
      final newPayments = widget.showAll
          ? await _paymentRepository.getAllPaymentsWithDetails(
              limit: _rowsPerPage,
              offset: _page * _rowsPerPage)
          : await _paymentRepository.getPaymentsByUser(
              widget.userId!,
              limit: _rowsPerPage,
              offset: _page * _rowsPerPage);

      setState(() {
        _payments.addAll(newPayments);
        _isLoading = false;
        _hasMore = newPayments.length == _rowsPerPage;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading more payments: ${e.toString()}')),
      );
    }
  }

  void _scrollListener() {
    if (_scrollController.offset >=
        _scrollController.position.maxScrollExtent - 200 &&
        !_scrollController.position.outOfRange) {
      _loadMorePayments();
    }
  }

  List<Payment> _applyFilters(List<Payment> payments) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty && _selectedCategoryFilter == null) return payments;

    return payments.where((payment) {
      bool matchesSearch = true;
      bool matchesCategory = true;

      if (query.isNotEmpty) {
        switch (_searchType) {
          case 'Patient Number':
            matchesSearch = payment.patientId.toLowerCase().contains(query);
            break;
          case 'Patient Name':
            matchesSearch = (payment.patientName ?? '').toLowerCase().contains(query);
            break;
          case 'Item Department':
            matchesSearch = payment.item.itemCategory.toLowerCase().contains(query);
            break;
        }
      }

      if (_selectedCategoryFilter != null) {
        matchesCategory = payment.item.itemCategory.toLowerCase().contains(_selectedCategoryFilter!.toLowerCase());
      }

      return matchesSearch && matchesCategory;
    }).toList();
  }

  Future<void> _refreshPayments() async {
    await _loadInitialPayments();
  }

  Future<void> _printReceipt(Payment payment) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(level: 0, child: pw.Text('Payment Receipt')),
                pw.SizedBox(height: 20),
                pw.Text('Receipt Number: ${payment.receiptNumber}'),
                pw.Text('Date: ${payment.formattedDate}'),
                pw.Text('Patient: ${payment.patientName ?? 'Unknown'}'),
                pw.Text('Patient ID: ${payment.patientId}'),
                pw.SizedBox(height: 20),
                pw.Text('Item:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('${payment.item.itemName} x${payment.item.quantity} - ${_currencyFormat.format(payment.item.amount)}'),
                pw.Divider(),
                pw.Text('Total Amount: ${_currencyFormat.format(payment.totalAmount)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate receipt: ${e.toString()}')),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No payments found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          if (_searchController.text.isNotEmpty || _selectedCategoryFilter != null)
            TextButton(
              onPressed: _refreshPayments,
              child: Text('Clear filters'),
            ),
        ],
      ),
    );
  }

  List<DataColumn> _buildDataColumns() {
    return [
      DataColumn(label: Text('S.No', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(label: Text('Receipt No', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(label: Text('Patient No', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(label: Text('Patient Name', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(label: Text('Item Department', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(
        label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold)),
        numeric: true,
      ),
      DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(label: Text('Sponsor', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(label: Text('Created By', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
    ];
  }

  List<DataCell> _buildDataCells(Payment payment, int index) {
    return [
      DataCell(Text('${index + 1 + (_currentPage * _rowsPerPage)}')),
      DataCell(Text(payment.receiptNumber)),
      DataCell(Text(payment.patientId)),
      DataCell(Text(payment.patientName ?? 'Unknown')),
      DataCell(Text(payment.phoneNumber ?? 'N/A')),
      DataCell(Text(payment.item.itemName)),
      DataCell(Text(payment.item.itemCategory)),
      DataCell(Text(payment.item.quantity.toString())),
      DataCell(Text(_currencyFormat.format(payment.item.amount))),
      DataCell(Text(payment.item.department ?? 'N/A')),
      DataCell(Text(payment.sponsor)),
      DataCell(Text(payment.createdBy.toString())),
      DataCell(Text(DateFormat('yyyy-MM-dd HH:mm').format(payment.paymentDate))),
      DataCell(
        IconButton(
          icon: const Icon(Icons.print),
          onPressed: () => _printReceipt(payment),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final filteredPayments = _applyFilters(_payments);
    final totalAmount = filteredPayments.fold(
        0.0, (sum, payment) => sum + payment.totalAmount);
    final pageCount = (_payments.length / _rowsPerPage).ceil();
    final paginatedPayments = filteredPayments
        .skip(_currentPage * _rowsPerPage)
        .take(_rowsPerPage)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showAll ? 'All Payments' : 'My Payments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshPayments,
          ),
        ],
      ),
      body: Column(
        children: [
          // Responsive filter controls
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 600) {
                      // Wide screen layout
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  value: _searchType,
                                  items: _searchTypes.map((type) {
                                    return DropdownMenuItem<String>(
                                      value: type,
                                      child: Text(type),
                                    );
                                  }).toList(),
                                  onChanged: (value) => setState(() => _searchType = value!),
                                  decoration: const InputDecoration(
                                    labelText: 'Search By',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    labelText: 'Search ${_searchType.toLowerCase()}',
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.search),
                                      onPressed: _refreshPayments,
                                    ),
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  onChanged: (value) => setState(() {}),
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedCategoryFilter,
                                  decoration: const InputDecoration(
                                    labelText: 'Filter by Department',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('All Departments'),
                                    ),
                                    ...['DENTAL', 'OPTHAMOLOGY', 'ABS AND GYN', 'OPD', 'EMD', 'RADIOLOGY', 
                                        'PSYCHIATRIC', 'INTERNAL MEDICINE', 'ORTHOPEDIC', 'DIALYSIS', 
                                        'SURGICAL', 'ENT', 'DERMATOLOGY', 'PHYSIOTHERAPY', 'MALNUTRITION', 
                                        'COMMUNITY PHARMACY', 'IPD PHARMACY', 'EMD PHARMACY', 'MORTUARY', 'OTHER']
                                        .map((category) {
                                      return DropdownMenuItem<String>(
                                        value: category,
                                        child: Text(category),
                                      );
                                    }).toList(),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedCategoryFilter = value;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<int>(
                                  value: _rowsPerPage,
                                  decoration: const InputDecoration(
                                    labelText: 'Rows per page',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
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
                                    _refreshPayments();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    } else {
                      // Narrow screen layout
                      return Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: _searchType,
                            items: _searchTypes.map((type) {
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                            onChanged: (value) => setState(() => _searchType = value!),
                            decoration: const InputDecoration(
                              labelText: 'Search By',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                          SizedBox(height: 10),
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText: 'Search ${_searchType.toLowerCase()}',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.search),
                                onPressed: _refreshPayments,
                              ),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onChanged: (value) => setState(() {}),
                          ),
                          SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _selectedCategoryFilter,
                            decoration: const InputDecoration(
                              labelText: 'Filter by Department',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('All Departments'),
                              ),
                              ...['DENTAL', 'OPTHAMOLOGY', 'ABS AND GYN', 'OPD', 'EMD', 'RADIOLOGY', 
                                  'PSYCHIATRIC', 'INTERNAL MEDICINE', 'ORTHOPEDIC', 'DIALYSIS', 
                                  'SURGICAL', 'ENT', 'DERMATOLOGY', 'PHYSIOTHERAPY', 'MALNUTRITION', 
                                  'COMMUNITY PHARMACY', 'IPD PHARMACY', 'EMD PHARMACY', 'MORTUARY', 'OTHER']
                                  .map((category) {
                                return DropdownMenuItem<String>(
                                  value: category,
                                  child: Text(category),
                                );
                              }).toList(),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedCategoryFilter = value;
                              });
                            },
                          ),
                          SizedBox(height: 10),
                          DropdownButtonFormField<int>(
                            value: _rowsPerPage,
                            decoration: const InputDecoration(
                              labelText: 'Rows per page',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
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
                              _refreshPayments();
                            },
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
            ),
          ),

          // Payment table
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshPayments,
              child: filteredPayments.isEmpty && !_isLoading
                  ? _buildEmptyState()
                  : Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: DataTable(
                                border: TableBorder.all(color: Colors.grey),
                                columnSpacing: 12,
                                dataRowHeight: 48,
                                headingRowHeight: 56,
                                columns: _buildDataColumns(),
                                rows: [
                                  ...paginatedPayments
                                      .asMap()
                                      .entries
                                      .map((entry) => DataRow(
                                            cells: _buildDataCells(entry.value, entry.key),
                                          ))
                                      .toList(),
                                  // Total amount row
                                  DataRow(
                                    cells: [
                                      DataCell(Text('')),
                                      DataCell(Text('')),
                                      DataCell(Text('')),
                                      DataCell(Text('')),
                                      DataCell(Text('')),
                                      DataCell(Text('')),
                                      DataCell(Text('')),
                                      DataCell(Text('Total:')),
                                      DataCell(
                                        Text(
                                          _currencyFormat.format(totalAmount),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      DataCell(Text('')),
                                      DataCell(Text('')),
                                      DataCell(Text('')),
                                      DataCell(Text('')),
                                      DataCell(Text('')),
                                    ],
                                  ),
                                  if (_isLoading)
                                    DataRow(
                                      cells: List.generate(
                                        _buildDataColumns().length,
                                        (index) {
                                          if (index == 0) {
                                            return DataCell(
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                child: const Center(
                                                  child: CircularProgressIndicator(),
                                                ),
                                              ),
                                            );
                                          }
                                          return const DataCell(Text(''));
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Pagination controls
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          color: Colors.grey[100],
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: _currentPage == 0
                                    ? null
                                    : () {
                                        setState(() => _currentPage--);
                                        _scrollController.animateTo(
                                          0,
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeOut,
                                        );
                                      },
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  'Page ${_currentPage + 1} of ${pageCount == 0 ? 1 : pageCount}',
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: _currentPage == pageCount - 1 || filteredPayments.isEmpty
                                    ? null
                                    : () {
                                        setState(() => _currentPage++);
                                        _scrollController.animateTo(
                                          0,
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeOut,
                                        );
                                      },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}