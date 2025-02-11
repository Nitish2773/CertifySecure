import 'dart:io';
import 'package:certify_secure_app/CertifySecure/Screen/utils/constants.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/helpers.dart';
import 'package:certify_secure_app/CertifySecure/Widgets/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class TeacherProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? teacherData;
  final Function()? onDataUpdate;

  const TeacherProfileScreen({
    super.key,
    this.teacherData,
    this.onDataUpdate,
  });

  @override
  _TeacherProfileScreenState createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController departmentController = TextEditingController();
  final TextEditingController designationController = TextEditingController();
  final TextEditingController employeeIdController = TextEditingController();
  final TextEditingController qualificationController = TextEditingController();
  final TextEditingController experienceController = TextEditingController();
  final TextEditingController specializedSubjectsController = TextEditingController();
  final TextEditingController researchInterestsController = TextEditingController();
  final TextEditingController officeLocationController = TextEditingController();
  final TextEditingController officeHoursController = TextEditingController();

  // State variables
  String? imageUrl;
  bool isEditing = false;
  bool isLoading = false;
  double profileCompletionPercentage = 0.0;
  List<String> _assignedSections = [];
  List<String> _teachingSubjects = [];

  // Available options
  final List<String> _availableSections = ['A', 'B', 'C', 'D'];
  final List<String> _availableSubjects = [
    'Data Structures',
    'Algorithms',
    'Database Management',
    'Computer Networks',
    'Operating Systems',
    'Software Engineering',
    // Add more subjects as needed
  ];  @override
  void initState() {
    super.initState();
    _initializeData();
    _addControllerListeners();
  }

  void _initializeData() {
    if (widget.teacherData != null) {
      _loadPrefilledData();
    } else {
      _loadUserData();
    }
  }

  void _addControllerListeners() {
    // Add listeners to all controllers for profile completion calculation
    nameController.addListener(_calculateProfileCompletion);
    phoneController.addListener(_calculateProfileCompletion);
    departmentController.addListener(_calculateProfileCompletion);
    designationController.addListener(_calculateProfileCompletion);
    employeeIdController.addListener(_calculateProfileCompletion);
    qualificationController.addListener(_calculateProfileCompletion);
    experienceController.addListener(_calculateProfileCompletion);
    specializedSubjectsController.addListener(_calculateProfileCompletion);
    researchInterestsController.addListener(_calculateProfileCompletion);
    officeLocationController.addListener(_calculateProfileCompletion);
    officeHoursController.addListener(_calculateProfileCompletion);
  }

  void _loadPrefilledData() {
    setState(() {
      imageUrl = widget.teacherData!['imageUrl'];
      nameController.text = widget.teacherData!['name'] ?? '';
      phoneController.text = widget.teacherData!['phone'] ?? '';
      departmentController.text = widget.teacherData!['department'] ?? '';
      designationController.text = widget.teacherData!['designation'] ?? '';
      employeeIdController.text = widget.teacherData!['employeeId'] ?? '';
      qualificationController.text = widget.teacherData!['qualification'] ?? '';
      experienceController.text = widget.teacherData!['experience'] ?? '';
      specializedSubjectsController.text = widget.teacherData!['specializedSubjects'] ?? '';
      researchInterestsController.text = widget.teacherData!['researchInterests'] ?? '';
      officeLocationController.text = widget.teacherData!['officeLocation'] ?? '';
      officeHoursController.text = widget.teacherData!['officeHours'] ?? '';
      _assignedSections = List<String>.from(widget.teacherData!['sections'] ?? []);
      _teachingSubjects = List<String>.from(widget.teacherData!['teachingSubjects'] ?? []);
    });
    _calculateProfileCompletion();
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);
    try {
      if (user != null) {
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            imageUrl = userData['imageUrl'];
            nameController.text = userData['name'] ?? user?.displayName ?? '';
            phoneController.text = userData['phone'] ?? '';
            departmentController.text = userData['department'] ?? '';
            designationController.text = userData['designation'] ?? '';
            employeeIdController.text = userData['employeeId'] ?? '';
            qualificationController.text = userData['qualification'] ?? '';
            experienceController.text = userData['experience'] ?? '';
            specializedSubjectsController.text = userData['specializedSubjects'] ?? '';
            researchInterestsController.text = userData['researchInterests'] ?? '';
            officeLocationController.text = userData['officeLocation'] ?? '';
            officeHoursController.text = userData['officeHours'] ?? '';
            _assignedSections = List<String>.from(userData['sections'] ?? []);
            _teachingSubjects = List<String>.from(userData['teachingSubjects'] ?? []);
          });
          _calculateProfileCompletion();
        }
      }
    } catch (e) {
      Helpers.showSnackBar(
        context,
        'Error loading user data: ${e.toString()}',
        isError: true,
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _calculateProfileCompletion() {
    int totalFields = 12; // Including profile picture
    int completedFields = 0;

    if (imageUrl != null && imageUrl!.isNotEmpty) completedFields++;
    if (nameController.text.isNotEmpty) completedFields++;
    if (phoneController.text.isNotEmpty) completedFields++;
    if (departmentController.text.isNotEmpty) completedFields++;
    if (designationController.text.isNotEmpty) completedFields++;
    if (employeeIdController.text.isNotEmpty) completedFields++;
    if (qualificationController.text.isNotEmpty) completedFields++;
    if (experienceController.text.isNotEmpty) completedFields++;
    if (specializedSubjectsController.text.isNotEmpty) completedFields++;
    if (researchInterestsController.text.isNotEmpty) completedFields++;
    if (officeLocationController.text.isNotEmpty) completedFields++;
    if (officeHoursController.text.isNotEmpty) completedFields++;

    setState(() {
      profileCompletionPercentage = (completedFields / totalFields) * 100;
    });
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    try {
      final Map<String, dynamic> userData = {
        'name': nameController.text,
        'phone': phoneController.text,
        'department': departmentController.text,
        'designation': designationController.text,
        'employeeId': employeeIdController.text,
        'qualification': qualificationController.text,
        'experience': experienceController.text,
        'specializedSubjects': specializedSubjectsController.text,
        'researchInterests': researchInterestsController.text,
        'officeLocation': officeLocationController.text,
        'officeHours': officeHoursController.text,
        'sections': _assignedSections,
        'teachingSubjects': _teachingSubjects,
        'imageUrl': imageUrl,
        'role': 'teacher',
        'updatedAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .set(userData, SetOptions(merge: true));

      await user!.updateDisplayName(nameController.text);

      setState(() => isEditing = false);
      widget.onDataUpdate?.call();
      Helpers.showSnackBar(context, 'Profile updated successfully');
    } catch (e) {
      Helpers.showSnackBar(
        context,
        'Error updating profile: ${e.toString()}',
        isError: true,
      );
    } finally {
      setState(() => isLoading = false);
    }
  }  Future<void> _pickAndUploadImage() async {
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

      final String fileName = '${user!.uid}_${DateTime.now().millisecondsSinceEpoch}';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child(AppConstants.profileImagesPath)
          .child('$fileName.jpg');

      final UploadTask uploadTask = storageRef.putFile(File(image.path));
      final TaskSnapshot taskSnapshot = await uploadTask;
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      setState(() => imageUrl = downloadUrl);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'imageUrl': downloadUrl});

      _calculateProfileCompletion();
      Helpers.showSnackBar(context, 'Profile picture updated successfully');
    } catch (e) {
      Helpers.showSnackBar(
        context,
        'Error updating profile picture: ${e.toString()}',
        isError: true,
      );
    } finally {
      setState(() => isLoading = false);
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.secondary,
          ],
        ),
        borderRadius: BorderRadius.only(
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
                      color: Colors.black.withOpacity(0.1),
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
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                color: Colors.white,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.person, size: 50, color: Colors.white),
                        )
                      : const Icon(Icons.person, size: 50, color: Colors.white),
                ),
              ),
              if (isEditing)
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
                        border: Border.all(
                          color: AppColors.primary,
                          width: 2,
                        ),
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
            nameController.text,
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
          if (designationController.text.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              designationController.text,
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
  }  Widget _buildProfileForm() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Personal Information'),
          const SizedBox(height: 15),
          _buildTextField(
            controller: nameController,
            label: 'Full Name',
            icon: Icons.person,
            enabled: isEditing,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your name';
              }
              return null;
            },
          ),
          const SizedBox(height: 15),
          _buildTextField(
            controller: phoneController,
            label: 'Phone Number',
            icon: Icons.phone,
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
          const SizedBox(height: 25),

          _buildSectionTitle('Professional Information'),
          const SizedBox(height: 15),
          _buildTextField(
            controller: employeeIdController,
            label: 'Employee ID',
            icon: Icons.badge,
            enabled: isEditing,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your employee ID';
              }
              return null;
            },
          ),
          const SizedBox(height: 15),
          _buildTextField(
            controller: departmentController,
            label: 'Department',
            icon: Icons.business,
            enabled: isEditing,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your department';
              }
              return null;
            },
          ),
          const SizedBox(height: 15),
          _buildTextField(
            controller: designationController,
            label: 'Designation',
            icon: Icons.work,
            enabled: isEditing,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your designation';
              }
              return null;
            },
          ),
          const SizedBox(height: 15),
          _buildTextField(
            controller: qualificationController,
            label: 'Qualification',
            icon: Icons.school,
            enabled: isEditing,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your qualification';
              }
              return null;
            },
          ),
          const SizedBox(height: 15),
          _buildTextField(
            controller: experienceController,
            label: 'Experience (Years)',
            icon: Icons.timeline,
            enabled: isEditing,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your experience';
              }
              return null;
            },
          ),
          const SizedBox(height: 25),

          _buildSectionTitle('Academic Information'),
          const SizedBox(height: 15),
          if (isEditing) ...[
            _buildChipSelection(
              title: 'Assigned Sections',
              selectedItems: _assignedSections,
              availableItems: _availableSections,
              onSelectionChanged: (sections) {
                setState(() => _assignedSections = sections);
              },
            ),
            const SizedBox(height: 15),
            _buildChipSelection(
              title: 'Teaching Subjects',
              selectedItems: _teachingSubjects,
              availableItems: _availableSubjects,
              onSelectionChanged: (subjects) {
                setState(() => _teachingSubjects = subjects);
              },
            ),
          ] else ...[
            _buildInfoField('Assigned Sections', _assignedSections.join(', ')),
            const SizedBox(height: 15),
            _buildInfoField('Teaching Subjects', _teachingSubjects.join(', ')),
          ],
          const SizedBox(height: 15),
          _buildTextField(
            controller: specializedSubjectsController,
            label: 'Specialized Subjects',
            icon: Icons.star,
            enabled: isEditing,
            maxLines: 2,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            controller: researchInterestsController,
            label: 'Research Interests',
            icon: Icons.science,
            enabled: isEditing,
            maxLines: 2,
          ),
          const SizedBox(height: 25),

          _buildSectionTitle('Contact Information'),
          const SizedBox(height: 15),
          _buildTextField(
            controller: officeLocationController,
            label: 'Office Location',
            icon: Icons.location_on,
            enabled: isEditing,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            controller: officeHoursController,
            label: 'Office Hours',
            icon: Icons.access_time,
            enabled: isEditing,
          ),
          const SizedBox(height: 30),
          _buildActionButton(),
          const SizedBox(height: 20),
        ],
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

  Widget _buildInfoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.isEmpty ? 'Not specified' : value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildChipSelection({
    required String title,
    required List<String> selectedItems,
    required List<String> availableItems,
    required Function(List<String>) onSelectionChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableItems.map((item) {
            final isSelected = selectedItems.contains(item);
            return FilterChip(
              label: Text(item),
              selected: isSelected,
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    selectedItems.add(item);
                  } else {
                    selectedItems.remove(item);
                  }
                  onSelectionChanged(selectedItems);
                });
              },
              backgroundColor: isSelected ? AppColors.primary.withOpacity(0.1) : null,
              selectedColor: AppColors.primary.withOpacity(0.2),
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : Colors.black87,
              ),
            );
          }).toList(),
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
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? AppColors.primary.withOpacity(0.3) : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary.withOpacity(0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
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
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
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
    if (percentage >= 100) return 'Your profile is complete!';
    if (percentage >= 70) return 'Almost there! Fill in the remaining fields.';
    if (percentage >= 40) return 'Good start! Keep adding more information.';
    return 'Let\'s start building your profile!';
  }

  @override
  void dispose() {
    // Dispose all controllers
    nameController.dispose();
    phoneController.dispose();
    departmentController.dispose();
    designationController.dispose();
    employeeIdController.dispose();
    qualificationController.dispose();
    experienceController.dispose();
    specializedSubjectsController.dispose();
    researchInterestsController.dispose();
    officeLocationController.dispose();
    officeHoursController.dispose();
    super.dispose();
  }
}