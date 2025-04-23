import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tiba_pay/models/item.dart';
import 'package:tiba_pay/models/patient.dart';
import 'package:tiba_pay/models/payment.dart';
import 'package:tiba_pay/models/user.dart';
import 'package:tiba_pay/repositories/item_repository.dart';
import 'package:tiba_pay/repositories/patient_repository.dart';
import 'package:tiba_pay/repositories/payment_repository.dart';
import 'package:tiba_pay/utils/database_helper.dart';

class ProcessPaymentScreen extends StatefulWidget {
  final User user;

  const ProcessPaymentScreen({super.key, required this.user});

  @override
  _ProcessPaymentScreenState createState() => _ProcessPaymentScreenState();
}

class _ProcessPaymentScreenState extends State<ProcessPaymentScreen> {
  final _patientRepository = PatientRepository(dbHelper: DatabaseHelper.instance);
  final _itemRepository = ItemRepository(dbHelper: DatabaseHelper.instance);
  final _paymentRepository = PaymentRepository(dbHelper: DatabaseHelper.instance);

  late Future<List<Patient>> _patientsFuture;
  late Future<List<Item>> _itemsFuture;

  Patient? _selectedPatient;
  List<PaymentItem> _selectedItems = [];
  String? _selectedSponsor;
  String? _selectedCategory;
  Item? _selectedItem;

  final List<String> _sponsors = ['CASH REFERRAL', 'CASH SELF REFERRAL', 'FIRST TRUCK'];
  List<String> _categories = [];
  List<Item> _filteredItems = [];

  int _rowsPerPage = 10;
  int _currentPage = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchType = 'Patient Number';
  final List<String> _searchTypes = [
    'Patient Number',
    'Patient Name',
    'Sponsor',
    'Register Date'
  ];

  @override
  void initState() {
    super.initState();
    _patientsFuture = _patientRepository.getAllPatients();
    _itemsFuture = _itemRepository.getActiveItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (_selectedPatient == null || _selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select patient and at least one item')),
      );
      return;
    }

    try {
      // Create a separate payment for each item
      final paymentTime = DateTime.now();
      final basePaymentId = paymentTime.millisecondsSinceEpoch.toString();
      
      for (int i = 0; i < _selectedItems.length; i++) {
        final item = _selectedItems[i];
        final payment = Payment(
          paymentId: '${basePaymentId}_$i',
          paymentDate: paymentTime,
          patientId: _selectedPatient!.patientNumber,
          createdBy: '${widget.user.firstName} ${widget.user.lastName}',
          createdById: widget.user.userId!,
          sponsor: _selectedSponsor!,
          item: item,
          department: item.itemCategory,
          patientName: _selectedPatient!.fullName,
          phoneNumber: _selectedPatient!.phoneNumber,
        );

        await _paymentRepository.createPayment(payment);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payments processed successfully')),
      );

      // Show success dialog with summary
      final totalAmount = _selectedItems.fold(0.0, (sum, item) => sum + (item.amount * item.quantity));
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Payment Successful'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Payments have been recorded successfully.'),
              const SizedBox(height: 16),
              Text('Number of items: ${_selectedItems.length}'),
              Text('Total Amount: ${totalAmount.toStringAsFixed(2)}'),
              Text('Recorded by: ${widget.user.firstName} ${widget.user.lastName}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Print Receipts'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _selectedPatient = null;
                  _selectedItems = [];
                  _selectedSponsor = null;
                  _selectedCategory = null;
                  _selectedItem = null;
                });
              },
              child: const Text('New Payment'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing payments: ${e.toString()}')),
      );
    }
  }

  void _addItemToPayment() {
    if (_selectedItem == null) return;

    setState(() {
      _selectedItems.add(PaymentItem(
        itemId: _selectedItem!.itemId,
        itemName: _selectedItem!.itemName,
        itemCategory: _selectedCategory ?? 'General',
        amount: _selectedItem!.itemPrice,
        quantity: 1,
      ));
      _selectedItem = null;
    });
  }

  void _removeItemFromPayment(int index) {
    setState(() {
      _selectedItems.removeAt(index);
    });
  }

  void _updateItemQuantity(int index, int quantity) {
    if (quantity < 1) return;

    setState(() {
      _selectedItems[index] = _selectedItems[index].copyWith(quantity: quantity);
    });
  }

  Future<void> _filterItems() async {
    if (_selectedSponsor == null || _selectedCategory == null) return;

    final allItems = await _itemsFuture;
    setState(() {
      _filteredItems = allItems.where((item) =>
          item.itemSponsor == _selectedSponsor &&
          item.itemCategory == _selectedCategory
      ).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Process Payment')),
      body: _selectedPatient == null ? _buildPatientTable() : _buildPaymentForm(),
    );
  }
  Widget _buildPatientTable() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _searchType,
                          items: _searchTypes.map((type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(
                                type,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _searchType = value!),
                          decoration: const InputDecoration(
                            labelText: 'Search By',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          ),
                          isExpanded: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Search ${_searchType.toLowerCase()}',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: () {
                                setState(() {
                                  _patientsFuture = _patientRepository.getAllPatients().then((patients) {
                                    final query = _searchController.text.trim().toLowerCase();
                                    if (query.isEmpty) return patients;

                                    switch (_searchType) {
                                      case 'Patient Number':
                                        return patients.where((p) => 
                                          p.patientNumber.toLowerCase().contains(query)).toList();
                                      case 'Patient Name':
                                        return patients.where((p) => 
                                          p.fullName.toLowerCase().contains(query)).toList();
                                      case 'Sponsor':
                                        return patients.where((p) => 
                                          p.sponsor.toLowerCase().contains(query)).toList();
                                      case 'Register Date':
                                        return patients.where((p) => 
                                          DateFormat('yyyy-MM-dd').format(p.createdAt).toLowerCase().contains(query)).toList();
                                      default:
                                        return patients;
                                    }
                                  });
                                });
                              },
                            ),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onSubmitted: (_) {
                            setState(() {
                              _patientsFuture = _patientRepository.getAllPatients().then((patients) {
                                final query = _searchController.text.trim().toLowerCase();
                                if (query.isEmpty) return patients;

                                switch (_searchType) {
                                  case 'Patient Number':
                                    return patients.where((p) => 
                                      p.patientNumber.toLowerCase().contains(query)).toList();
                                  case 'Patient Name':
                                    return patients.where((p) => 
                                      p.fullName.toLowerCase().contains(query)).toList();
                                  case 'Sponsor':
                                    return patients.where((p) => 
                                      p.sponsor.toLowerCase().contains(query)).toList();
                                  case 'Register Date':
                                    return patients.where((p) => 
                                      DateFormat('yyyy-MM-dd').format(p.createdAt).toLowerCase().contains(query)).toList();
                                  default:
                                    return patients;
                                }
                              });
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _patientsFuture = _patientRepository.getAllPatients();
                          });
                        },
                        child: const Text('Clear Search'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Patient>>(
              future: _patientsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No patients found'));
                }

                final patients = snapshot.data!;
                final pageCount = (patients.length / _rowsPerPage).ceil();
                final startIndex = _currentPage * _rowsPerPage;
                final endIndex = startIndex + _rowsPerPage > patients.length
                    ? patients.length
                    : startIndex + _rowsPerPage;
                final pagePatients = patients.sublist(startIndex, endIndex);

                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: MediaQuery.of(context).size.width - 32,
                          ),
                          child: DataTable(
                            columnSpacing: 20,
                            columns: const [
                              DataColumn(label: Text('Patient Number')),
                              DataColumn(label: Text('Patient Name')),
                              DataColumn(label: Text('Sponsor')),
                              DataColumn(label: Text('Phone')),
                              DataColumn(label: Text('Registered Date')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: pagePatients.map((patient) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Tooltip(
                                      message: patient.patientNumber,
                                      child: Text(
                                        patient.patientNumber,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Tooltip(
                                      message: patient.fullName,
                                      child: Text(
                                        patient.fullName,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Tooltip(
                                      message: patient.sponsor,
                                      child: Text(
                                        patient.sponsor,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Tooltip(
                                      message: patient.phoneNumber ?? 'N/A',
                                      child: Text(
                                        patient.phoneNumber ?? 'N/A',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      DateFormat('yyyy-MM-dd HH:mm:ss').format(patient.createdAt),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.payment, color: Colors.blue),
                                      onPressed: () {
                                        setState(() {
                                          _selectedPatient = patient;
                                          _selectedSponsor = patient.sponsor;
                                        });
                                        _itemsFuture.then((items) {
                                          setState(() {
                                            _categories = items
                                                .where((item) => item.itemSponsor == patient.sponsor)
                                                .map((item) => item.itemCategory)
                                                .toSet()
                                                .toList();
                                          });
                                        });
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
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        DropdownButton<int>(
                          value: _rowsPerPage,
                          items: [10, 25, 50, 100].map((value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text('$value per page'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _rowsPerPage = value!;
                              _currentPage = 0;
                            });
                          },
                        ),
                        Row(
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
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Patient: ${_selectedPatient!.fullName}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text('Patient Number: ${_selectedPatient!.patientNumber}'),
                  Text('Sponsor: ${_selectedPatient!.sponsor}'),
                  Text('Phone: ${_selectedPatient!.phoneNumber ?? 'N/A'}'),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedPatient = null;
                        _selectedItems = [];
                      });
                    },
                    child: const Text('Change Patient'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Payment Items',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedSponsor,
                    decoration: const InputDecoration(
                      labelText: 'Sponsor',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    isExpanded: true,
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
                        _selectedSponsor = value;
                        _selectedCategory = null;
                        _selectedItem = null;
                        _filteredItems = [];
                      });
                      _itemsFuture.then((items) {
                        setState(() {
                          _categories = items
                              .where((item) => item.itemSponsor == value)
                              .map((item) => item.itemCategory)
                              .toSet()
                              .toList();
                        });
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_selectedSponsor != null)
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Item Department',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      isExpanded: true,
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
                          _selectedCategory = value;
                          _selectedItem = null;
                        });
                        _filterItems();
                      },
                    ),
                  const SizedBox(height: 16),
                  if (_selectedCategory != null)
                    DropdownButtonFormField<Item>(
                      value: _selectedItem,
                      decoration: const InputDecoration(
                        labelText: 'Select Item',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      isExpanded: true,
                      items: _filteredItems.map((item) {
                        return DropdownMenuItem<Item>(
                          value: item,
                          child: Text(
                            '${item.itemName} - ${item.itemPrice}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (item) => setState(() => _selectedItem = item),
                    ),
                  const SizedBox(height: 16),
                  if (_selectedItem != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Price: ${_selectedItem!.itemPrice}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _addItemToPayment,
                          child: const Text('Add Item'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_selectedItems.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Items',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: MediaQuery.of(context).size.width - 32,
                        ),
                        child: DataTable(
                          columnSpacing: 20,
                          columns: const [
                            DataColumn(label: Text('Item Name')),
                            DataColumn(label: Text('Department')),
                            DataColumn(label: Text('Price')),
                            DataColumn(label: Text('Qty')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: _selectedItems.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            return DataRow(
                              cells: [
                                DataCell(
                                  Tooltip(
                                    message: item.itemName,
                                    child: Text(
                                      item.itemName,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(Text(item.itemCategory)),
                                DataCell(Text('${item.amount.toStringAsFixed(2)}')),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove, size: 16),
                                        onPressed: () => _updateItemQuantity(index, item.quantity - 1),
                                      ),
                                      Text(item.quantity.toString()),
                                      IconButton(
                                        icon: const Icon(Icons.add, size: 16),
                                        onPressed: () => _updateItemQuantity(index, item.quantity + 1),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _removeItemFromPayment(index),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Total Amount: ${_selectedItems.fold(0.0, (sum, item) => sum + (item.amount * item.quantity)).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        onPressed: _processPayment,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        ),
                        child: const Text('Process Payment'),
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