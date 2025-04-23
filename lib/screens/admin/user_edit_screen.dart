import 'package:flutter/material.dart';
import 'dart:convert'; // for utf8
import 'package:crypto/crypto.dart'; // for sha256
import 'package:intl/intl.dart';

import 'package:tiba_pay/models/user.dart';
import 'package:tiba_pay/repositories/user_repository.dart';
import 'package:tiba_pay/utils/database_helper.dart';

class UserEditScreen extends StatefulWidget {
  final User? user;
  final User currentUser;

  const UserEditScreen({
    super.key, 
    this.user,
    required this.currentUser,
  });

  @override
  _UserEditScreenState createState() => _UserEditScreenState();
}

class _UserEditScreenState extends State<UserEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _userRepository = UserRepository(dbHelper: DatabaseHelper.instance);
  
  String? _role;
  String? _status;

  @override
  void initState() {
    super.initState();
    
    if (widget.user != null) {
      _firstNameController.text = widget.user!.firstName;
      _middleNameController.text = widget.user!.middleName ?? '';
      _lastNameController.text = widget.user!.lastName;
      _usernameController.text = widget.user!.username;
      _role = widget.user!.role;
      _status = widget.user!.status;
    } else {
      _role = 'cashier';
      _status = 'active';
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    final user = User(
      userId: widget.user?.userId,
      firstName: _firstNameController.text.trim(),
      middleName: _middleNameController.text.trim().isEmpty 
          ? null 
          : _middleNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      username: _usernameController.text.trim(),
      passwordHash: _passwordController.text.trim().isEmpty
          ? widget.user?.passwordHash ?? ''
          : _hashPassword(_passwordController.text.trim()),
      role: _role!,
      status: _status!,
      createdAt: widget.user?.createdAt ?? DateTime.now().toIso8601String(),
      createdBy: widget.user?.createdBy ?? widget.currentUser.fullName,
    );

    try {
      if (widget.user == null) {
        await _userRepository.createUser(user);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User created successfully')),
        );
      } else {
        await _userRepository.updateUser(user);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User updated successfully')),
        );
      }
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving user: ${e.toString()}')),
      );
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.user == null ? 'Add User' : 'Edit User'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveUser,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter first name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _middleNameController,
                decoration: const InputDecoration(labelText: 'Middle Name'),
              ),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter last name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter username';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: widget.user == null ? '' : 'Leave blank to keep current',
                ),
                obscureText: true,
                validator: (value) {
                  if (widget.user == null && (value == null || value.isEmpty)) {
                    return 'Please enter password';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _role,
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'accountant', child: Text('Accountant')),
                  DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                ],
                onChanged: (value) => setState(() => _role = value),
                decoration: const InputDecoration(labelText: 'Role'),
              ),
              DropdownButtonFormField<String>(
                value: _status,
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                ],
                onChanged: (value) => setState(() => _status = value),
                decoration: const InputDecoration(labelText: 'Status'),
              ),
              if (widget.user != null) ...[
                const SizedBox(height: 16),
                Text('Created By: ${widget.user!.createdBy}'),
                const SizedBox(height: 8),
                Text('Created At: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(widget.user!.createdAt))}'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}