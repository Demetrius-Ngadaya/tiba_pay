import 'package:flutter/material.dart';
import 'package:tiba_pay/models/item.dart';
import 'package:tiba_pay/utils/database_helper.dart';
import 'package:tiba_pay/repositories/item_repository.dart';

class ItemEditScreen extends StatefulWidget {
  final Item? item;

  const ItemEditScreen({this.item});

  @override
  _ItemEditScreenState createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends State<ItemEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemRepository = ItemRepository(dbHelper: DatabaseHelper.instance);

  final List<String> _categories = [ 'DENTAL', 'OPTHAMOLOGY', 'ABS AND GYN', 'OPD', 'EMD', 'RADIOLOGY', 'PSYCHIATRIC', 'INTERNAL MEDICINE', 'ORTHOPEDIC', 'DIALYSIS', 'SURGICAL', 'ENT', 'DERMATOLOGY', 'PHYSIOTHERAPY', 'MALNUTRITION', 'COMMUNITY PHARMACY', 'IPD PHARMACY', 'EMD PHARMACY', 'MORTUARY', 'OTHER',] ;
  final List<String> _sponsors = ['CASH REFERRAL', 'CASH SELF REFERRAL', 'FIRST TRUCK'];

  late String _itemName;
  late String _itemCategory;
  late double _itemPrice;
  late String _itemSponsor;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _itemName = widget.item!.itemName;
      _itemCategory = widget.item!.itemCategory;
      _itemPrice = widget.item!.itemPrice;
      _itemSponsor = widget.item!.itemSponsor;
      _isActive = widget.item!.isActive;
    } else {
      _itemName = '';
      _itemCategory = _categories.first;
      _itemPrice = 0.0;
      _itemSponsor = _sponsors.first;
      _isActive = true;
    }
  }

  Future<void> _saveItem() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      try {
        if (widget.item != null) {
          // Update existing item
          final updatedItem = Item(
            itemId: widget.item!.itemId,
            itemName: _itemName,
            itemCategory: _itemCategory,
            itemPrice: _itemPrice,
            itemSponsor: _itemSponsor,
            isActive: _isActive,
            createdAt: widget.item!.createdAt,
          );
          await _itemRepository.updateItem(updatedItem);
        } else {
          // Create new item
          final newItem = Item(
            itemId: DateTime.now().millisecondsSinceEpoch.toString(),
            itemName: _itemName,
            itemCategory: _itemCategory,
            itemPrice: _itemPrice,
            itemSponsor: _itemSponsor,
            isActive: _isActive,
            createdAt: DateTime.now(),
          );
          await _itemRepository.addItem(newItem);
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
        title: Text(widget.item == null ? 'Add New Item' : 'Edit Item'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                initialValue: _itemName,
                decoration: InputDecoration(labelText: 'Item Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter item name';
                  }
                  return null;
                },
                onSaved: (value) => _itemName = value!,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _itemCategory,
                decoration: InputDecoration(labelText: 'Item department'),
                items: _categories
                    .map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _itemCategory = value!),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                initialValue: _itemPrice.toString(),
                decoration: InputDecoration(labelText: 'Item Price'),
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
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _itemSponsor,
                decoration: InputDecoration(labelText: 'Item Sponsor'),
                items: _sponsors
                    .map((sponsor) => DropdownMenuItem(
                          value: sponsor,
                          child: Text(sponsor),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _itemSponsor = value!),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a sponsor';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              SwitchListTile(
                title: Text('Active'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveItem,
                child: Text('Save Item'),
              ),
              if (widget.item != null) ...[
                SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}