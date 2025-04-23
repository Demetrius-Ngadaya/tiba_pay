import 'package:flutter/material.dart';
import 'package:tiba_pay/models/item.dart';
import 'package:tiba_pay/models/user.dart';
import 'package:tiba_pay/utils/database_helper.dart';
import 'package:tiba_pay/screens/items/item_edit_screen.dart';
import 'package:tiba_pay/repositories/item_repository.dart';

class ItemListScreen extends StatefulWidget {
  final User currentUser;

  const ItemListScreen({Key? key, required this.currentUser}) : super(key: key);

  @override
  _ItemListScreenState createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  final ItemRepository _itemRepository = ItemRepository(dbHelper: DatabaseHelper.instance);
  List<Item> _items = [];
  List<Item> _filteredItems = [];
  bool _isLoading = true;
  int _rowsPerPage = 10;
  int _currentPage = 1;
  final TextEditingController _searchController = TextEditingController();

  // Filters
  String? _categoryFilter;
  String? _sponsorFilter;
  bool? _activeFilter = true;

  final List<String> _categories = ['DENTAL', 'OPTHAMOLOGY', 'ABS AND GYN', 'OPD', 'EMD', 'RADIOLOGY', 
                                        'PSYCHIATRIC', 'INTERNAL MEDICINE', 'ORTHOPEDIC', 'DIALYSIS', 
                                        'SURGICAL', 'ENT', 'DERMATOLOGY', 'PHYSIOTHERAPY', 'MALNUTRITION', 
                                        'COMMUNITY PHARMACY', 'IPD PHARMACY', 'EMD PHARMACY', 'MORTUARY', 'OTHER'];
  final List<String> _sponsors = ['CASH REFERRAL', 'CASH SELF REFERRAL', 'FIRST TRUCK'];

  @override
  void initState() {
    super.initState();
    _loadItems();
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _itemRepository.getAllItems();
      setState(() {
        _items = items;
        _filteredItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load items: $e')),
      );
    }
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _items.where((item) {
        final matchesSearch = item.itemName.toLowerCase().contains(query) ||
            item.itemCategory.toLowerCase().contains(query) ||
            item.itemSponsor.toLowerCase().contains(query) ||
            item.createdBy.toLowerCase().contains(query);
        
        final matchesCategory = _categoryFilter == null || 
            item.itemCategory == _categoryFilter;
        
        final matchesSponsor = _sponsorFilter == null || 
            item.itemSponsor == _sponsorFilter;
        
        final matchesActive = _activeFilter == null || 
            item.isActive == _activeFilter;
        
        return matchesSearch && matchesCategory && matchesSponsor && matchesActive;
      }).toList();
    });
  }

  void _deleteItem(String itemId) async {
    try {
      await _itemRepository.deleteItem(itemId);
      _loadItems();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete item: $e')),
      );
    }
  }

  void _confirmDelete(Item item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${item.itemName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteItem(item.itemId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_filteredItems.length / _rowsPerPage).ceil();
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    final paginatedItems = _filteredItems.sublist(
      startIndex.clamp(0, _filteredItems.length),
      endIndex.clamp(0, _filteredItems.length),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Items'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadItems,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Row
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.filter_alt),
                  onPressed: () => _showFilterDialog(),
                ),
              ],
            ),
          ),
          // CRUD Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => ItemEditScreen(currentUser: widget.currentUser),
                    ),
                  ).then((_) => _loadItems()),
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _rowsPerPage,
                  items: [10, 25, 50, 100]
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text('$value items'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _rowsPerPage = value!;
                      _currentPage = 1;
                    });
                  },
                ),
              ],
            ),
          ),
          // Items Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Department')),
                          DataColumn(label: Text('Price'), numeric: true),
                          DataColumn(label: Text('Sponsor')),
                          DataColumn(label: Text('Created By')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: paginatedItems.map((item) {
                          return DataRow(cells: [
                            DataCell(Text(item.itemName)),
                            DataCell(Text(item.itemCategory)),
                            DataCell(Text('${item.itemPrice.toStringAsFixed(2)}')),
                            DataCell(Text(item.itemSponsor)),
                            DataCell(Text(item.createdBy)),
                            DataCell(
                              Chip(
                                label: Text(
                                  item.isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    color: item.isActive ? Colors.green : Colors.red,
                                  ),
                                ),
                                backgroundColor: item.isActive
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                              ),
                            ),
                            DataCell(Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (ctx) => ItemEditScreen(
                                        item: item,
                                        currentUser: widget.currentUser,
                                      ),
                                    ),
                                  ).then((_) => _loadItems()),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _confirmDelete(item),
                                ),
                              ],
                            )),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
          ),
          // Pagination
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
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filter Items'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _categoryFilter,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [null, ..._categories]
                  .map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category ?? 'All Categories'),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => _categoryFilter = value);
                _filterItems();
              },
            ),
            DropdownButtonFormField<String>(
              value: _sponsorFilter,
              decoration: const InputDecoration(labelText: 'Sponsor'),
              items: [null, ..._sponsors]
                  .map((sponsor) => DropdownMenuItem(
                        value: sponsor,
                        child: Text(sponsor ?? 'All Sponsors'),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => _sponsorFilter = value);
                _filterItems();
              },
            ),
            DropdownButtonFormField<bool>(
              value: _activeFilter,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Statuses')),
                const DropdownMenuItem(value: true, child: Text('Active')),
                const DropdownMenuItem(value: false, child: Text('Inactive')),
              ],
              onChanged: (value) {
                setState(() => _activeFilter = value);
                _filterItems();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _categoryFilter = null;
                _sponsorFilter = null;
                _activeFilter = true;
              });
              _filterItems();
              Navigator.pop(ctx);
            },
            child: const Text('Reset'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}