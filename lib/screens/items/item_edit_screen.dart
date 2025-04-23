import 'package:flutter/material.dart';
import 'package:tiba_pay/models/item.dart';
import 'package:tiba_pay/models/user.dart';
import 'package:tiba_pay/repositories/item_repository.dart';
import 'package:tiba_pay/utils/database_helper.dart';
import 'package:uuid/uuid.dart';

class ItemEditScreen extends StatefulWidget {
  final Item? item;
  final User currentUser;

  const ItemEditScreen({
    Key? key, 
    this.item,
    required this.currentUser,
  }) : super(key: key);

  @override
  _ItemEditScreenState createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends State<ItemEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemRepository = ItemRepository(dbHelper: DatabaseHelper.instance);
  
  late String _itemId;
  late String _itemName;
  late String _itemCategory;
  late double _itemPrice;
  late String _itemSponsor;
  late bool _isActive;
  late String _createdBy;

  final List<String> _categories = ['DENTAL', 'OPTHAMOLOGY', 'ABS AND GYN', 'OPD', 'EMD', 'RADIOLOGY', 
                                        'PSYCHIATRIC', 'INTERNAL MEDICINE', 'ORTHOPEDIC', 'DIALYSIS', 
                                        'SURGICAL', 'ENT', 'DERMATOLOGY', 'PHYSIOTHERAPY', 'MALNUTRITION', 
                                        'COMMUNITY PHARMACY', 'IPD PHARMACY', 'EMD PHARMACY', 'MORTUARY', 'OTHER'];
  final List<String> _sponsors = ['CASH REFERRAL', 'CASH SELF REFERRAL', 'FIRST TRUCK'];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    if (widget.item != null) {
      // Editing existing item
      _itemId = widget.item!.itemId;
      _itemName = widget.item!.itemName;
      _itemCategory = widget.item!.itemCategory;
      _itemPrice = widget.item!.itemPrice;
      _itemSponsor = widget.item!.itemSponsor;
      _isActive = widget.item!.isActive;
      _createdBy = widget.item!.createdBy;
      
      _nameController.text = _itemName;
      _priceController.text = _itemPrice.toString();
    } else {
      // Creating new item
      _itemId = const Uuid().v4();
      _itemName = '';
      _itemCategory = _categories.first;
      _itemPrice = 0.0;
      _itemSponsor = _sponsors.first;
      _isActive = true;
      _createdBy = widget.currentUser.username;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      final item = Item(
        itemId: _itemId,
        itemName: _itemName,
        itemCategory: _itemCategory,
        itemPrice: _itemPrice,
        itemSponsor: _itemSponsor,
        isActive: _isActive,
        createdAt: widget.item?.createdAt ?? DateTime.now(),
        createdBy: _createdBy,
      );

      try {
        if (widget.item == null) {
          await _itemRepository.insertItem(item);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item created successfully')),
          );
        } else {
          await _itemRepository.updateItem(item);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item updated successfully')),
          );
        }
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving item: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'Create Item' : 'Edit Item'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveItem,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter item name';
                  }
                  return null;
                },
                onSaved: (value) => _itemName = value!,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _itemCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _itemCategory = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
                onSaved: (value) => _itemPrice = double.parse(value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _itemSponsor,
                decoration: const InputDecoration(
                  labelText: 'Sponsor',
                  border: OutlineInputBorder(),
                ),
                items: _sponsors.map((sponsor) {
                  return DropdownMenuItem<String>(
                    value: sponsor,
                    child: Text(sponsor),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _itemSponsor = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active'),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),
              if (widget.item != null) ...[
                const SizedBox(height: 16),
                Text('Created By: ${widget.item!.createdBy}'),
                const SizedBox(height: 8),
                Text('Created At: ${widget.item!.formattedCreatedAt}'),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveItem,
                child: const Text('Save Item'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}