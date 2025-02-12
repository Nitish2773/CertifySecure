// lib/screens/company/company_profile_screen.dart

import 'dart:io';
import 'package:certify_secure_app/CertifySecure/Screen/company/company_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/constants.dart';
import 'package:certify_secure_app/CertifySecure/Widgets/loading_indicator.dart';

class CompanyProfileScreen extends StatefulWidget {
  final CompanyData companyData;
  final Function(CompanyData) onProfileUpdated;

  const CompanyProfileScreen({
    super.key,
    required this.companyData,
    required this.onProfileUpdated,
  });

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _industryController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _websiteController = TextEditingController();

  bool _isLoading = false;
  bool _isEditing = false;
  File? _imageFile;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController.text = widget.companyData.name;
    _emailController.text = widget.companyData.email;
    _phoneController.text = widget.companyData.phone ?? '';
    _industryController.text = widget.companyData.industry ?? '';
    _locationController.text = widget.companyData.location ?? '';
    _descriptionController.text = widget.companyData.description ?? '';
    _websiteController.text = widget.companyData.website ?? '';
    _currentImageUrl = widget.companyData.profileImage;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _industryController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
        });
      }
    } catch (e) {
      _showErrorSnackbar('Error picking image: $e');
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _currentImageUrl;

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('company_profiles')
          .child('${widget.companyData.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = storageRef.putFile(_imageFile!);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      _showErrorSnackbar('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final imageUrl = await _uploadImage();
      
      final updatedData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'industry': _industryController.text.trim(),
        'location': _locationController.text.trim(),
        'description': _descriptionController.text.trim(),
        'website': _websiteController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (imageUrl != null) {
        updatedData['profileImage'] = imageUrl;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.companyData.id)
          .update(updatedData);

      final updatedCompanyData = CompanyData(
        id: widget.companyData.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        industry: _industryController.text.trim(),
        location: _locationController.text.trim(),
        description: _descriptionController.text.trim(),
        website: _websiteController.text.trim(),
        profileImage: imageUrl ?? _currentImageUrl,
        isVerified: widget.companyData.isVerified,
        joinedDate: widget.companyData.joinedDate,
      );

      widget.onProfileUpdated(updatedCompanyData);
      
      setState(() {
        _isEditing = false;
        _isLoading = false;
      });

      _showSuccessSnackbar('Profile updated successfully');
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackbar('Error updating profile: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isLoading ? null : _saveProfile,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileImage(),
                    const SizedBox(height: 24),
                    _buildProfileForm(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileImage() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey[200],
            backgroundImage: _imageFile != null
                ? FileImage(_imageFile!)
                : _currentImageUrl != null
                    ? NetworkImage(_currentImageUrl!)
                    : null,
            child: _imageFile == null && _currentImageUrl == null
                ? Text(
                    widget.companyData.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  )
                : null,
          ),
          if (_isEditing)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  onPressed: _pickImage,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _nameController,
          label: 'Company Name',
          icon: Icons.business,
          enabled: _isEditing,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Company name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _emailController,
          label: 'Email',
          icon: Icons.email,
          enabled: false,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _phoneController,
          label: 'Phone',
          icon: Icons.phone,
          enabled: _isEditing,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _industryController,
          label: 'Industry',
          icon: Icons.category,
          enabled: _isEditing,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _locationController,
          label: 'Location',
          icon: Icons.location_on,
          enabled: _isEditing,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _websiteController,
          label: 'Website',
          icon: Icons.web,
          enabled: _isEditing,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _descriptionController,
          label: 'Description',
          icon: Icons.description,
          enabled: _isEditing,
          maxLines: 3,
        ),
        const SizedBox(height: 24),
        if (_isEditing)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey[100],
      ),
    );
  }
}