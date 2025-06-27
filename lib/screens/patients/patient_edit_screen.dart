import 'package:flutter/material.dart';
import 'package:tiba_pay/models/patient.dart';
import 'package:tiba_pay/models/user.dart';
import 'package:tiba_pay/repositories/patient_repository.dart';
import 'package:tiba_pay/utils/database_helper.dart';

class PatientEditScreen extends StatefulWidget {
  final Patient? patient;
  final User currentUser;

  const PatientEditScreen({
    super.key, 
    this.patient,
    required this.currentUser,
  });

  @override
  _PatientEditScreenState createState() => _PatientEditScreenState();
}

class _PatientEditScreenState extends State<PatientEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _patientNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _patientRepository = PatientRepository(dbHelper: DatabaseHelper.instance);
  
  String? _selectedSponsor;
  final List<String> _sponsors = ['CASH REFERRAL', 'CASH SELF REFERRAL', 'FAST TRACK'];

  @override
  void initState() {
    super.initState();
    
    if (widget.patient != null) {
      _firstNameController.text = widget.patient!.firstName;
      _middleNameController.text = widget.patient!.middleName ?? '';
      _lastNameController.text = widget.patient!.lastName;
      _patientNumberController.text = widget.patient!.patientNumber;
      _phoneController.text = widget.patient!.phoneNumber ?? '';
      _addressController.text = widget.patient!.address ?? '';
      _selectedSponsor = widget.patient!.sponsor;
    } else {
      _selectedSponsor = 'CASH SELF REFERRAL';
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _patientNumberController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return null;
    if (!value.startsWith('0') || value.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Phone must start with 0 and be 10 digits';
    }
    return null;
  }

  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) return;

    final patient = Patient(
      patientNumber: _patientNumberController.text.trim(),
      firstName: _firstNameController.text.trim(),
      middleName: _middleNameController.text.trim().isEmpty 
          ? null 
          : _middleNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      sponsor: _selectedSponsor ?? 'CASH SELF REFERRAL',
      phoneNumber: _phoneController.text.trim().isEmpty 
          ? null 
          : _phoneController.text.trim(),
      address: _addressController.text.trim().isEmpty 
          ? null 
          : _addressController.text.trim(),
      createdBy: '${widget.currentUser.firstName} ${widget.currentUser.lastName}',
    );

    try {
      if (widget.patient == null) {
        await _patientRepository.createPatient(patient);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient added successfully!')),
        );
      } else {
        await _patientRepository.updatePatient(patient);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient updated successfully!')),
        );
      }
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving patient: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.patient == null ? 'Add Patient' : 'Edit Patient'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _savePatient,
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
                decoration: const InputDecoration(
                  labelText: 'First Name*',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter first name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _middleNameController,
                decoration: const InputDecoration(
                  labelText: 'Middle Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name*',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter last name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _patientNumberController,
                decoration: const InputDecoration(
                  labelText: 'Patient Number (auto-generated)',
                  border: OutlineInputBorder(),
                  filled: true,
                  enabled: false,
                ),
                readOnly: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedSponsor,
                decoration: const InputDecoration(
                  labelText: 'Sponsor*',
                  border: OutlineInputBorder(),
                ),
                items: _sponsors.map((sponsor) {
                  return DropdownMenuItem<String>(
                    value: sponsor,
                    child: Text(sponsor),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedSponsor = value),
                validator: (value) => value == null ? 'Select sponsor' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: _validatePhone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _savePatient,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('SAVE PATIENT'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}