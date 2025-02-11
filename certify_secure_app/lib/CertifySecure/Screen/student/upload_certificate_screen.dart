import 'dart:io';
import 'package:certify_secure_app/CertifySecure/Screen/utils/constants.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/helpers.dart';
import 'package:certify_secure_app/CertifySecure/Widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UploadCertificateScreen extends StatefulWidget {
  const UploadCertificateScreen({super.key});

  @override
  _UploadCertificateScreenState createState() =>
      _UploadCertificateScreenState();
}

class _UploadCertificateScreenState extends State<UploadCertificateScreen>
    with SingleTickerProviderStateMixin {
  // File handling
  File? _pickedFile;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _issuedByController = TextEditingController();
  final _issueDateController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _departmentController = TextEditingController();

  // Date handling
  DateTime? _selectedDate;

  // Certificate type handling
  String _selectedCertificateType = 'Academic';
  final List<String> _certificateTypes = [
    'Academic',
    'Technical',
    'Achievement',
    'Participation',
    'Course Completion',
    'Other'
  ];

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _selectedBatch = '';  // Add if you need batch information
String _selectedSection = '';  // Add if you need section information

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _prefillUserData();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();
  }

  void _prefillUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _studentIdController.text = user.uid;
      _emailController.text = user.email ?? '';
    }
  }

  String _getSemesterNumber(DateTime date) {
    int month = date.month;
    int year = date.year;
    int currentYear = DateTime.now().year;
    int yearDiff = currentYear - year;

    int semesterNumber;
    if (month >= 7 && month <= 12) {
      semesterNumber = yearDiff * 2 + 1;
    } else {
      semesterNumber = yearDiff * 2 + 2;
    }

    return semesterNumber > 8 ? '8' : semesterNumber.toString();
  }

  String _getAcademicYear(DateTime date) {
    int year = date.year;
    int month = date.month;
    if (month >= 7) {
      return '$year-${year + 1}';
    } else {
      return '${year - 1}-$year';
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final fileSize = await file.length();

        if (fileSize > 5 * 1024 * 1024) {
          Helpers.showSnackBar(
            context,
            'File size should be less than 5MB',
            isError: true,
          );
          return;
        }

        setState(() => _pickedFile = file);
        Helpers.showSnackBar(context, 'File selected successfully');
      }
    } catch (e) {
      Helpers.showSnackBar(
        context,
        'Error picking file',
        isError: true,
      );
    }
  }

  

  Future<void> _uploadFile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedFile == null) {
      Helpers.showSnackBar(
        context,
        'Please select a certificate to upload',
        isError: true,
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Get certificate count
      final certificateCount = await _firestore
          .collection(AppConstants.certificatesCollection)
          .where('userId', isEqualTo: _studentIdController.text)
          .get()
          .then((snapshot) => snapshot.docs.length);

      // Format certificate name
      final formattedCertificateName =
          'Certificate_${certificateCount + 1}_${_nameController.text.trim().replaceAll(' ', '_')}';

      // Create certificate ID
      final String certificateId =
          '${_studentIdController.text}_${DateTime.now().millisecondsSinceEpoch}';
      final fileName = '${certificateId}_$formattedCertificateName.pdf';

      // Upload file
      final UploadTask uploadTask = _storage
          .ref('${AppConstants.certificatesPath}/$fileName')
          .putFile(_pickedFile!);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadURL = await snapshot.ref.getDownloadURL();

      // Save to Firestore
      await _firestore
          .collection(AppConstants.certificatesCollection)
          .doc(certificateId)
          .set({
        'certificateId': certificateId,
        'fileName': fileName,
        'url': downloadURL,
        'name': formattedCertificateName,
        'originalName': _nameController.text.trim(),
        'description': _descriptionController.text,
        'issuedBy': _issuedByController.text,
        'issueDate': _selectedDate,
        'uploadedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'userId': _studentIdController.text,
        'userEmail': _emailController.text,
        'department': _departmentController.text.trim(),
          'studentDetails': {
          // Add nested student details
          'uid': user.uid,  // Important: Add UID here
          'email': user.email,
          'name': user.displayName,
          'department': _departmentController.text.trim(),
          'rollNumber': _studentIdController.text,  // If you have this
          'batch': _selectedBatch,  // If you have this
          'section': _selectedSection,  // If you have this
        },
        'certificateType': _selectedCertificateType,
        'semester': _getSemesterNumber(_selectedDate!),
        'academicYear': _getAcademicYear(_selectedDate!),
        'fileSize': await _pickedFile!.length(),
        'fileType': 'pdf',
        'lastModified': FieldValue.serverTimestamp(),
        'verificationStatus': 'pending',
        'verifiedBy': null,
        'verificationDate': null,
        'comments': [],
        'certificateNumber': certificateCount + 1,
      });

      _resetForm();
      Helpers.showSnackBar(context, 'Certificate uploaded successfully');
    } catch (e) {
      Helpers.showSnackBar(
        context,
        e.toString(),
        isError: true,
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _issueDateController.text = DateFormat('dd MMM yyyy').format(picked);
      });
    }
  }

  void _resetForm() {
    setState(() {
      _pickedFile = null;
      _nameController.clear();
      _idController.clear();
      _descriptionController.clear();
       _departmentController.clear(); // Add this line
      _issuedByController.clear();
      _issueDateController.clear();
      _selectedDate = null;
      _uploadProgress = 0.0;
      _selectedCertificateType = 'Academic';
    });
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload Certificate',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Upload your certificates in PDF format',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFileUploadSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _isUploading ? null : _pickFile,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _pickedFile != null
                        ? Icons.file_present
                        : Icons.upload_file,
                    size: 50,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _pickedFile != null
                        ? 'Selected: ${_pickedFile!.path.split('/').last}'
                        : 'Click to select PDF certificate',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isUploading) ...[
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: 10),
            Text(
              '${(_uploadProgress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCertificateDetailsForm() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedCertificateType,
              items: _certificateTypes.map((String type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCertificateType = newValue!;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 15),
        CustomTextField(
          controller: _studentIdController,
          label: 'Student ID',
          hint: 'Student ID',
          prefixIcon: Icons.person,
          // readOnly: true,
        ),
        const SizedBox(height: 15),
        CustomTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'Email',
          prefixIcon: Icons.email,
          // readOnly: true,
        ),
        const SizedBox(height: 15),
        CustomTextField(
          controller: _departmentController,
          label: 'Department',
          hint: 'Enter your department',
          prefixIcon: Icons.school,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your department';
            }
            return null;
          },
        ),
        const SizedBox(height: 15),
        // Add Batch Dropdown here
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedBatch.isEmpty ? null : _selectedBatch,
            hint: const Text('Select Batch'),
            isExpanded: true,
            decoration: const InputDecoration(
              border: InputBorder.none,
              prefixIcon: Icon(Icons.school),
            ),
            items: ['2020', '2021', '2022', '2023'].map((String batch) {
              return DropdownMenuItem(
                value: batch,
                child: Text(batch),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedBatch = newValue ?? '';
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a batch';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 15),
        // Add Section Dropdown here
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedSection.isEmpty ? null : _selectedSection,
            hint: const Text('Select Section'),
            isExpanded: true,
            decoration: const InputDecoration(
              border: InputBorder.none,
              prefixIcon: Icon(Icons.group),
            ),
            items: ['A', 'B', 'C', 'D'].map((String section) {
              return DropdownMenuItem(
                value: section,
                child: Text(section),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedSection = newValue ?? '';
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a section';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 15),
        CustomTextField(
          controller: _nameController,
          label: 'Certificate Name',
          hint: 'Enter certificate name',
          prefixIcon: Icons.description,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter certificate name';
            }
            return null;
          },
        ),
        const SizedBox(height: 15),
        CustomTextField(
          controller: _idController,
          label: 'Certificate ID',
          hint: 'Enter certificate ID',
          prefixIcon: Icons.numbers,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter certificate ID';
            }
            return null;
          },
        ),
        const SizedBox(height: 15),
        CustomTextField(
          controller: _issuedByController,
          label: 'Issued By',
          hint: 'Enter issuing authority',
          prefixIcon: Icons.business,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter issuing authority';
            }
            return null;
          },
        ),
        const SizedBox(height: 15),
        GestureDetector(
          onTap: () => _selectDate(context),
          child: AbsorbPointer(
            child: CustomTextField(
              controller: _issueDateController,
              label: 'Issue Date',
              hint: 'Select issue date',
              prefixIcon: Icons.calendar_today,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select issue date';
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: 15),
        CustomTextField(
          controller: _descriptionController,
          label: 'Description (Optional)',
          hint: 'Enter certificate description',
          prefixIcon: Icons.note,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildUploadButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isUploading ? null : _uploadFile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isUploading
            ? const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload),
                  SizedBox(width: 8),
                  Text(
                    'Upload Certificate',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 30),
                _buildFileUploadSection(),
                const SizedBox(height: 30),
                _buildCertificateDetailsForm(),
                const SizedBox(height: 30),
                _buildUploadButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _idController.dispose();
    _descriptionController.dispose();
    _departmentController.dispose(); 
    _issuedByController.dispose();
    _issueDateController.dispose();
    _studentIdController.dispose();
    _emailController.dispose();
     _selectedBatch = ''; // Reset batch
    _selectedSection = '';
    super.dispose();
  }
}
