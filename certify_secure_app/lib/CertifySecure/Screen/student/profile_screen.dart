import 'dart:io';
import 'package:certify_secure_app/CertifySecure/Screen/utils/constants.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/helpers.dart';
import 'package:certify_secure_app/CertifySecure/Widgets/custom_text_field.dart';
import 'package:certify_secure_app/CertifySecure/Widgets/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController collegeController = TextEditingController();
  final TextEditingController rollNumberController = TextEditingController();
  final TextEditingController semesterController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  // State variables
  String? imageUrl;
  bool isEditing = false;
  bool isLoading = false;
  double profileCompletionPercentage = 0.0;

  // Dropdown values
  String? _selectedCourse;
  String? _selectedBranch;
  String? _selectedYear;
  DateTime? _dateOfBirth;
  String? _gender;
  String? _bloodGroup;

  // Dropdown options
  final List<String> _courses = [
    'BTECH',
    'MCA',
    'MBA',
    'Degree'
  ];
  final List<String> _branches = [ 'Computer Science','CSE', 'ECE', 'EEE', 'CIVIL', 'MECH'];
  final List<String> _years = ['1st Year', '2nd Year', '3rd Year', '4th Year'];
  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-'
  ];
  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Add listeners to all controllers
    nameController.addListener(_calculateProfileCompletion);
    phoneController.addListener(_calculateProfileCompletion);
    collegeController.addListener(_calculateProfileCompletion);
    rollNumberController.addListener(_calculateProfileCompletion);
    semesterController.addListener(_calculateProfileCompletion);
    addressController.addListener(_calculateProfileCompletion);
  }

  void _calculateProfileCompletion() {
    int totalFields = 12; // Including all fields
    int completedFields = 0;

    if (imageUrl != null && imageUrl!.isNotEmpty) completedFields++;
    if (nameController.text.isNotEmpty) completedFields++;
    if (phoneController.text.isNotEmpty) completedFields++;
    if (collegeController.text.isNotEmpty) completedFields++;
    if (rollNumberController.text.isNotEmpty) completedFields++;
    if (semesterController.text.isNotEmpty) completedFields++;
    if (addressController.text.isNotEmpty) completedFields++;
    if (_selectedCourse != null) completedFields++;
    if (_selectedBranch != null) completedFields++;
    if (_selectedYear != null) completedFields++;
    if (_dateOfBirth != null) completedFields++;
    if (_gender != null) completedFields++;
    if (_bloodGroup != null) completedFields++;

    setState(() {
      profileCompletionPercentage = (completedFields / totalFields) * 100;
    });
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);
    try {
      if (user != null) {
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection(AppConstants.usersCollection)
            .doc(user!.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            imageUrl = userData['imageUrl'];
            nameController.text = userData['name'] ?? user?.displayName ?? '';
            phoneController.text = userData['phone'] ?? '';
            collegeController.text = userData['college'] ?? '';
            rollNumberController.text = userData['rollNumber'] ?? '';
            semesterController.text = userData['semester'] ?? '';
            addressController.text = userData['address'] ?? '';

            // Dropdown values
            _selectedCourse = userData['course'];
            _selectedBranch = userData['branch'];
            _selectedYear = userData['year'];
            _dateOfBirth = userData['dateOfBirth']?.toDate();
            _gender = userData['gender'];
            _bloodGroup = userData['bloodGroup'];
          });
          _calculateProfileCompletion();
        }
      }
    } catch (e) {
      Helpers.showSnackBar(context, 'Error loading user data', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    try {
      final Map<String, dynamic> userData = {
        'name': nameController.text,
        'phone': phoneController.text,
        'college': collegeController.text,
        'rollNumber': rollNumberController.text,
        'semester': semesterController.text,
        'address': addressController.text,
        'imageUrl': imageUrl,
        'course': _selectedCourse,
        'branch': _selectedBranch,
        'year': _selectedYear,
        'dateOfBirth':
            _dateOfBirth != null ? Timestamp.fromDate(_dateOfBirth!) : null,
        'gender': _gender,
        'bloodGroup': _bloodGroup,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'status': 'active',
      };

      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user!.uid)
          .set(userData, SetOptions(merge: true));

      await user!.updateDisplayName(nameController.text);

      setState(() => isEditing = false);
      _calculateProfileCompletion();
      Helpers.showSnackBar(context, 'Profile updated successfully');
    } catch (e) {
      Helpers.showSnackBar(
        context,
        'Error updating profile',
        isError: true,
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image == null) return;

      setState(() => isLoading = true);

      final String fileName =
          '${user!.uid}_${DateTime.now().millisecondsSinceEpoch}';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child(AppConstants.profileImagesPath)
          .child('$fileName.jpg');

      final UploadTask uploadTask = storageRef.putFile(File(image.path));
      final TaskSnapshot taskSnapshot = await uploadTask;
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      setState(() => imageUrl = downloadUrl);

      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user!.uid)
          .update({'imageUrl': downloadUrl});

      _calculateProfileCompletion();
      Helpers.showSnackBar(context, 'Profile picture updated successfully');
    } catch (e) {
      Helpers.showSnackBar(
        context,
        'Error updating profile picture',
        isError: true,
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
      });
      _calculateProfileCompletion();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const LoadingIndicator(message: 'Loading profile...');
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 20),
            _buildCompletionIndicator(),
            const SizedBox(height: 20),
            _buildProfileForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                color: Colors.white,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.person,
                                  size: 50, color: Colors.white),
                        )
                      : const Icon(Icons.person, size: 50, color: Colors.white),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickAndUploadImage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            nameController.text.isNotEmpty ? nameController.text : 'Your Name',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            user?.email ?? 'No email',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          if (_selectedCourse != null && _selectedBranch != null) ...[
            const SizedBox(height: 5),
            Text(
              '$_selectedCourse - $_selectedBranch',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletionIndicator() {
    final color = _getColorForPercentage(profileCompletionPercentage);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Profile Completion',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${profileCompletionPercentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: profileCompletionPercentage / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getCompletionMessage(profileCompletionPercentage),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildDropdown({
  required String? value,
  required List<String> items,
  required String hint,
  required IconData icon,
  required Function(String?)? onChanged,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey),
      borderRadius: BorderRadius.circular(8),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: items.contains(value) ? value : null,
        isExpanded: true,
        hint: Row(
          children: [
            Icon(icon, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Text(hint, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
        items: items.map<DropdownMenuItem<String>>((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Row(
              children: [
                Icon(icon, color: Colors.grey[600]),
                const SizedBox(width: 12),
                Text(item),
              ],
            ),
          );
        }).toList(),
        onChanged: isEditing ? onChanged : null,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
        ),
        icon: const Icon(Icons.arrow_drop_down),
        iconSize: 24,
        elevation: 16,
        dropdownColor: Colors.white,
      ),
    ),
  );
}

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: () {
          if (isEditing) {
            _updateProfile();
          } else {
            setState(() => isEditing = true);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isEditing ? AppColors.success : AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isEditing ? Icons.save : Icons.edit,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              isEditing ? 'Save Profile' : 'Edit Profile',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForPercentage(double percentage) {
    if (percentage >= 100) return Colors.green;
    if (percentage >= 70) return Colors.blue;
    if (percentage >= 40) return Colors.orange;
    return Colors.red;
  }

  String _getCompletionMessage(double percentage) {
    if (percentage >= 100) return 'Excellent! Your profile is complete.';
    if (percentage >= 70) return 'Almost there! Fill in the remaining fields.';
    if (percentage >= 40) return 'Good start! Keep adding more information.';
    return 'Let\'s start building your profile!';
  }

  Widget _buildProfileForm() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Personal Information'),
          const SizedBox(height: 15),

          CustomTextField(
            controller: nameController,
            label: 'Full Name',
            hint: 'Enter your full name',
            prefixIcon: Icons.person,
            enabled: isEditing,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your name';
              }
              return null;
            },
          ),
          const SizedBox(height: 15),

          CustomTextField(
            controller: phoneController,
            label: 'Phone Number',
            hint: 'Enter your phone number',
            prefixIcon: Icons.phone,
            enabled: isEditing,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your phone number';
              }
              if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                return 'Please enter a valid 10-digit phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 15),

          // Date of Birth Selector
          GestureDetector(
            onTap: isEditing ? () => _selectDate(context) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Text(
                    _dateOfBirth != null
                        ? DateFormat('dd MMM yyyy').format(_dateOfBirth!)
                        : 'Select Date of Birth',
                    style: TextStyle(
                      color: _dateOfBirth != null
                          ? Colors.black
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),

          // Gender Dropdown
          _buildDropdown(
            value: _gender,
            items: _genders,
            hint: 'Select Gender',
            icon: Icons.person_outline,
            onChanged: isEditing
                ? (value) {
                    setState(() {
                      _gender = value;
                      _calculateProfileCompletion();
                    });
                  }
                : null,
          ),
          const SizedBox(height: 15),

          // Blood Group Dropdown
          _buildDropdown(
            value: _bloodGroup,
            items: _bloodGroups,
            hint: 'Select Blood Group',
            icon: Icons.bloodtype,
            onChanged: isEditing
                ? (value) {
                    setState(() {
                      _bloodGroup = value;
                      _calculateProfileCompletion();
                    });
                  }
                : null,
          ),
          const SizedBox(height: 25),

          _buildSectionTitle('Academic Information'),
          const SizedBox(height: 15),

          // Course Dropdown
          _buildDropdown(
            value: _selectedCourse,
            items: _courses,
            hint: 'Select Course',
            icon: Icons.school,
            onChanged: isEditing
                ? (value) {
                    setState(() {
                      _selectedCourse = value;
                      _calculateProfileCompletion();
                    });
                  }
                : null,
          ),
          const SizedBox(height: 15),

          // Branch Dropdown
          _buildDropdown(
            value: _selectedBranch,
            items: _branches,
            hint: 'Select Branch',
            icon: Icons.category,
            onChanged: isEditing
                ? (value) {
                    setState(() {
                      _selectedBranch = value;
                      _calculateProfileCompletion();
                    });
                  }
                : null,
          ),
          const SizedBox(height: 15),

          // Year Dropdown
          _buildDropdown(
            value: _selectedYear,
            items: _years,
            hint: 'Select Year',
            icon: Icons.timeline,
            onChanged: isEditing
                ? (value) {
                    setState(() {
                      _selectedYear = value;
                      _calculateProfileCompletion();
                    });
                  }
                : null,
          ),
          const SizedBox(height: 15),

          CustomTextField(
            controller: rollNumberController,
            label: 'Roll Number',
            hint: 'Enter your roll number',
            prefixIcon: Icons.numbers,
            enabled: isEditing,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your roll number';
              }
              return null;
            },
          ),
          const SizedBox(height: 15),

          CustomTextField(
            controller: semesterController,
            label: 'Semester',
            hint: 'Enter current semester',
            prefixIcon: Icons.calendar_today,
            enabled: isEditing,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your semester';
              }
              if (!RegExp(r'^[1-8]$').hasMatch(value)) {
                return 'Please enter a valid semester (1-8)';
              }
              return null;
            },
          ),
          const SizedBox(height: 15),

          CustomTextField(
            controller: collegeController,
            label: 'College Name',
            hint: 'Enter your college name',
            prefixIcon: Icons.account_balance,
            enabled: isEditing,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your college name';
              }
              return null;
            },
          ),
          const SizedBox(height: 15),

          CustomTextField(
            controller: addressController,
            label: 'Address',
            hint: 'Enter your address',
            prefixIcon: Icons.location_on,
            enabled: isEditing,
            maxLines: 3,
          ),
          const SizedBox(height: 30),

          _buildActionButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Remove listeners
    nameController.removeListener(_calculateProfileCompletion);
    phoneController.removeListener(_calculateProfileCompletion);
    collegeController.removeListener(_calculateProfileCompletion);
    rollNumberController.removeListener(_calculateProfileCompletion);
    semesterController.removeListener(_calculateProfileCompletion);
    addressController.removeListener(_calculateProfileCompletion);

    // Dispose controllers
    nameController.dispose();
    phoneController.dispose();
    collegeController.dispose();
    rollNumberController.dispose();
    semesterController.dispose();
    addressController.dispose();
    super.dispose();
  }
}
