// lib/screens/student/view_certificates_screen.dart

import 'dart:io';
import 'dart:math';
import 'package:certify_secure_app/CertifySecure/Screen/common/pdf_viewer_widget.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/constants.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/helpers.dart';
import 'package:certify_secure_app/CertifySecure/Widgets/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ViewCertificatesScreen extends StatefulWidget {
  const ViewCertificatesScreen({super.key});

  @override
  _ViewCertificatesScreenState createState() => _ViewCertificatesScreenState();
}

class _ViewCertificatesScreenState extends State<ViewCertificatesScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isLoading = true;
  String _selectedFilter = 'all';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _initializePaths();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: AppConstants.defaultAnimationDuration,
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

  Future<void> _initializePaths() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _isLoading = false);
  }  
  
  Future<void> _viewCertificate(DocumentSnapshot doc) async {
  try {
    setState(() => _isLoading = true);
    
    final fileName = doc['fileName'] as String;
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/$fileName';
    
    final file = File(filePath);
    
    // Debug prints
    print('Checking file: $filePath');
    print('File exists: ${await file.exists()}');
    
    if (!await file.exists()) {
      final downloadURL = await _storage
          .ref('${AppConstants.certificatesPath}/$fileName')
          .getDownloadURL();
          
      print('Downloading from: $downloadURL');
      
      final response = await http.get(Uri.parse(downloadURL));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to download file: ${response.statusCode}');
      }
      
      await file.writeAsBytes(response.bodyBytes);
      
      print('File downloaded and saved');
      print('File size: ${await file.length()} bytes');
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerWidget(
          path: filePath,
          title: doc['name'] ?? 'Certificate',
          metadata: {
            'type': doc['certificateType'],
            'issuedBy': doc['issuedBy'],
            'issueDate': doc['issueDate'],
            'status': doc['verificationStatus'],
          },
        ),
      ),
    );
  } catch (e) {
    print('Error viewing certificate: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error viewing certificate: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}
  Future<void> _deleteCertificate(String id, String fileName) async {
    try {
      setState(() => _isLoading = true);
      
      // Delete from Firestore
      await _firestore
          .collection(AppConstants.certificatesCollection)
          .doc(id)
          .delete();
      
      // Delete from Storage
      await _storage.ref('${AppConstants.certificatesPath}/$fileName').delete();
      
      Helpers.showSnackBar(context, 'Certificate deleted successfully');
    } catch (e) {
      Helpers.showSnackBar(
        context,
        'Error deleting certificate: ${e.toString()}',
        isError: true,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }


  void _showCertificateDetails(DocumentSnapshot doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => _buildCertificateDetailsSheet(doc, controller),
      ),
    );
  }  
  
  
  Widget _buildCertificateDetailsSheet(DocumentSnapshot doc, ScrollController controller) {
    final status = doc['verificationStatus'] as String;
    final isVerified = status == 'verified';
    final verificationDetails = isVerified ? doc['verificationDetails'] as Map<String, dynamic> : null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Certificate Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),

          // Verification Status with Copy Options
          if (isVerified) ...[
            Container(
              padding: const EdgeInsets.all(15),
              margin: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.success.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified_user, color: AppColors.success),
                      SizedBox(width: 10),
                      Text(
                        'Verification Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  
                  // Document ID
                  _buildCopyableField(
                    label: 'Document ID',
                    value: doc.id,
                    onCopy: () => _copyToClipboard('Document ID', doc.id),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Certificate Hash
                  _buildCopyableField(
                    label: 'Certificate Hash',
                    value: verificationDetails?['hash'] ?? 'N/A',
                    onCopy: () => _copyToClipboard(
                      'Certificate Hash',
                      verificationDetails?['hash'] ?? '',
                    ),
                  ),

                  const SizedBox(height: 15),
                  const Text(
                    'Share these details with recruiters for certificate verification',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.success,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Basic Details
          _buildDetailItem('Name', doc['name'] ?? 'N/A'),
          _buildDetailItem('Certificate Type', doc['certificateType'] ?? 'N/A'),
          _buildDetailItem('Issued By', doc['issuedBy'] ?? 'N/A'),
          _buildDetailItem(
            'Issue Date',
            doc['issueDate'] != null
                ? Helpers.formatDate((doc['issueDate'] as Timestamp).toDate())
                : 'N/A',
          ),

          // Academic Details
          _buildDetailItem('Academic Year', doc['academicYear'] ?? 'N/A'),
          _buildDetailItem('Semester', doc['semester'] ?? 'N/A'),

          // Status Information
          _buildDetailItem(
            'Verification Status',
            status.toUpperCase(),
            color: isVerified ? AppColors.success : AppColors.warning,
          ),

          // File Information
          _buildDetailItem(
            'File Size',
            _formatFileSize(doc['fileSize'] ?? 0),
          ),
          _buildDetailItem('File Type', doc['fileType']?.toUpperCase() ?? 'N/A'),

          // Verification Details
          if (isVerified) ...[
            _buildDetailItem(
              'Verified By',
              verificationDetails?['verifierName'] ?? 'N/A',
            ),
            _buildDetailItem(
              'Verification Date',
              verificationDetails?['verifiedAt'] != null
                  ? Helpers.formatDateTime((verificationDetails!['verifiedAt'] as Timestamp).toDate())
                  : 'N/A',
            ),
          ],

          const SizedBox(height: 20),

          // Action Buttons
          _buildActionButton(
            label: 'View Certificate',
            icon: Icons.remove_red_eye,
            color: AppColors.primary,
            onPressed: () {
              Navigator.pop(context);
              _viewCertificate(doc);
            },
            isFullWidth: true,
          ),
          if (!isVerified) ...[
            const SizedBox(height: 10),
            _buildActionButton(
              label: 'Delete Certificate',
              icon: Icons.delete,
              color: AppColors.error,
              onPressed: () {
                Navigator.pop(context);
                _showDeleteConfirmation(doc);
              },
              isFullWidth: true,
            ),
          ],
        ],
      ),
    );
  }


  void _copyToClipboard(String label, String value) {
  Clipboard.setData(ClipboardData(text: value)).then((_) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  });
}

Widget _buildCopyableField({
  required String label,
  required String value,
  required VoidCallback onCopy,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.grey,
        ),
      ),
      const SizedBox(height: 5),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              onPressed: onCopy,
              tooltip: 'Copy to clipboard',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    ],
  );
}

  Widget _buildDetailItem(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
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
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isFullWidth = false,
  }) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(DocumentSnapshot doc) {
    Helpers.showConfirmationDialog(
      context,
      title: 'Delete Certificate',
      message: 'Are you sure you want to delete this certificate?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    ).then((confirmed) {
      if (confirmed) {
        _deleteCertificate(doc.id, doc['fileName']);
      }
    });
  }  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterSection(),
        Expanded(
          child: _isLoading
              ? const LoadingIndicator()
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildCertificatesList(),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            'Filter by: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          _buildFilterChip('All', 'all'),
          const SizedBox(width: 10),
          _buildFilterChip('Verified', 'verified'),
          const SizedBox(width: 10),
          _buildFilterChip('Pending', 'pending'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() => _selectedFilter = value);
      },
      backgroundColor:
          isSelected ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade100,
      selectedColor: AppColors.primary.withOpacity(0.1),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : Colors.black87,
      ),
    );
  }

  Widget _buildCertificatesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getFilteredStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            return _buildCertificateCard(snapshot.data!.docs[index]);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getFilteredStream() {
    Query query = _firestore
        .collection(AppConstants.certificatesCollection)
        .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid);

    if (_selectedFilter != 'all') {
      query = query.where('verificationStatus', isEqualTo: _selectedFilter);
    }

    return query.orderBy('uploadedAt', descending: true).snapshots();
  }

  Widget _buildCertificateCard(DocumentSnapshot doc) {
    final status = doc['verificationStatus'] as String;
    final color = status == 'verified' ? AppColors.success : AppColors.warning;
    final uploadDate = (doc['uploadedAt'] as Timestamp).toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: () => _showCertificateDetails(doc),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  status == 'verified'
                      ? Icons.verified
                      : Icons.pending_actions,
                  color: color,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc['name'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      doc['certificateType'] as String,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          Helpers.formatDate(uploadDate),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 70,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 15),
          Text(
            'No certificates found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Upload your first certificate',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 70,
            color: AppColors.error.withOpacity(0.5),
          ),
          const SizedBox(height: 15),
          const Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.error,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Please try again later',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}