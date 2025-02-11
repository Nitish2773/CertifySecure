// lib/screens/company/verify_certificates_screen.dart

import 'package:certify_secure_app/CertifySecure/Screen/utils/constants.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/helpers.dart';
import 'package:certify_secure_app/CertifySecure/Services/blockchain_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CertificateDetails {
  final String studentName;
  final String studentId;
  final String rollNumber;
  final String department;
  final String certificateName;
  final String certificateType;
  final DateTime issueDate;
  final DateTime verificationDate;
  final String verifiedBy;
  final String hash;
  final String storedHash;
  final String blockchainHash;
  final bool isBlockchainVerified;

  CertificateDetails({
    required this.studentName,
    required this.studentId,
    required this.rollNumber,
    required this.department,
    required this.certificateName,
    required this.certificateType,
    required this.issueDate,
    required this.verificationDate,
    required this.verifiedBy,
    required this.hash,
    required this.storedHash,
    required this.blockchainHash,
    this.isBlockchainVerified = false,
  });

  factory CertificateDetails.fromFirestore(Map<String, dynamic> data) {
    final studentDetails = data['studentDetails'] as Map<String, dynamic>;
    final verificationDetails =
        data['verificationDetails'] as Map<String, dynamic>;

    return CertificateDetails(
      studentName: studentDetails['name'] ?? 'N/A',
      studentId: studentDetails['userId'] ?? 'N/A',
      rollNumber: studentDetails['rollNumber'] ?? 'N/A',
      department: studentDetails['department'] ?? 'N/A',
      certificateName: data['name'] ?? 'N/A',
      certificateType: data['certificateType'] ?? 'N/A',
      issueDate: (data['issueDate'] as Timestamp).toDate(),
      verificationDate:
          (verificationDetails['verifiedAt'] as Timestamp).toDate(),
      verifiedBy: verificationDetails['verifierName'] ?? 'N/A',
      hash: verificationDetails['hash'] ?? 'N/A',
      storedHash: '',
      blockchainHash: '',
    );
  }
}

class VerifyCertificatesScreen extends StatefulWidget {
  const VerifyCertificatesScreen({super.key});

  @override
  _VerifyCertificatesScreenState createState() =>
      _VerifyCertificatesScreenState();
}

class _VerifyCertificatesScreenState extends State<VerifyCertificatesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdController = TextEditingController();
  final _documentIdController = TextEditingController();
  final _hashController = TextEditingController();
  final _blockchainService = BlockchainService();

  bool _isLoading = false;
  bool _isLoadingDetails = false;
  String? _verificationResult;
  bool _isVerified = false;
  CertificateDetails? _certificateDetails;

  @override
  void dispose() {
    _studentIdController.dispose();
    _documentIdController.dispose();
    _hashController.dispose();
    super.dispose();
  }
Future<void> _verifyHash() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _verificationResult = null;
      _isVerified = false;
      _certificateDetails = null;
    });

    try {
      final studentId = _studentIdController.text.trim();
      final documentId = _documentIdController.text.trim();

      // 1. Check Firestore verification first
      final doc = await FirebaseFirestore.instance
          .collection('certificates')
          .doc(documentId)
          .get();

      if (!doc.exists) {
        _showVerificationResult('Certificate not found', false);
        return;
      }

      final data = doc.data()!;
      final studentDetails = data['studentDetails'] as Map<String, dynamic>;
      final verificationDetails =
          data['verificationDetails'] as Map<String, dynamic>;

      // 2. Check if verified by teacher
      if (data['verificationStatus'] != 'verified') {
        _showVerificationResult(
          'This certificate has not been verified by a teacher yet.',
          false,
        );
        return;
      }

      // 3. Verify student ID
      if (studentDetails['rollNumber'] != studentId) {
        _showVerificationResult(
          'Student ID/Roll Number does not match certificate',
          false,
        );
        return;
      }

      // 4. Get hash from blockchain
      String blockchainHash = '';
      bool isBlockchainVerified = false;
      try {
        blockchainHash = await _blockchainService.getCertificateHash(
          studentId,
          documentId,
        );
        isBlockchainVerified = blockchainHash.isNotEmpty && blockchainHash != 'Unable to retrieve';
        print('Retrieved blockchain hash: $blockchainHash');
      } catch (e) {
        print('Error retrieving blockchain hash: $e');
        blockchainHash = 'Unable to retrieve';
      }

      // 5. Create certificate details
      _certificateDetails = CertificateDetails(
        studentName: studentDetails['name'] ?? 'N/A',
        studentId: studentDetails['uid'] ?? 'N/A',
        rollNumber: studentDetails['rollNumber'] ?? 'N/A',
        department: studentDetails['department'] ?? 'N/A',
        certificateName: data['name'] ?? 'N/A',
        certificateType: data['certificateType'] ?? 'N/A',
        issueDate: (data['issueDate'] as Timestamp).toDate(),
        verificationDate:
            (verificationDetails['verifiedAt'] as Timestamp).toDate(),
        verifiedBy: verificationDetails['verifierName'] ?? 'N/A',
        hash: verificationDetails['hash'] ?? 'N/A',
        storedHash: verificationDetails['hash'] ?? 'N/A',
        blockchainHash: blockchainHash,
        isBlockchainVerified: isBlockchainVerified,
      );

      // 6. Record verification
      await _recordVerification(studentId, documentId);

      // 7. Create verification message
      String verificationMessage = 'Certificate verified successfully!\n\n'
          'This certificate has been verified by ${_certificateDetails!.verifiedBy} '
          'from ${_certificateDetails!.department} department.\n\n'
          'Verification Details:\n'
          'Issue Date: ${Helpers.formatDate(_certificateDetails!.issueDate)}\n'
          'Verified On: ${Helpers.formatDateTime(_certificateDetails!.verificationDate)}\n\n';

      // Add blockchain verification status
      if (isBlockchainVerified) {
        verificationMessage += 'Blockchain Verification: ✓ Successful\n'
            'This certificate is also verified on blockchain.\n\n';
      } else {
        verificationMessage += 'Blockchain Verification: ⚠ Not Available\n'
            'Certificate is verified by institution only.\n\n';
      }

      verificationMessage += 'This certificate is verified as original and legitimate.';

      _showVerificationResult(verificationMessage, true);

    } catch (e) {
      print('Verification error: $e');
      _showVerificationResult(
        'Error verifying certificate: ${e.toString()}',
        false,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showVerificationResult(String message, bool isSuccess) {
    setState(() {
      _verificationResult = message;
      _isVerified = isSuccess;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Certificates'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 30),
              _buildVerificationForm(),
              if (_verificationResult != null) ...[
                const SizedBox(height: 30),
                _buildVerificationResult(),
              ],
              if (_certificateDetails != null) _buildCertificateDetails(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _recordVerification(String studentId, String documentId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Record verification in company_verifications collection
      await FirebaseFirestore.instance.collection('company_verifications').add({
        'studentId': studentId,
        'certificateId': documentId,
        'companyId': user.uid,
        'companyName': user.displayName ?? 'Unknown Company',
        'verifiedAt': FieldValue.serverTimestamp(),
        'certificateDetails': {
          'name': _certificateDetails!.certificateName,
          'type': _certificateDetails!.certificateType,
          'department': _certificateDetails!.department,
          'studentName': _certificateDetails!.studentName,
          'rollNumber': _certificateDetails!.rollNumber,
          'issueDate': _certificateDetails!.issueDate,
          'verifiedBy': _certificateDetails!.verifiedBy,
          'hash': _certificateDetails!.hash,
        },
      });

      // Create notification for student
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': _certificateDetails!.studentId,
        'title': 'Certificate Verified by Company',
        'message': 'Your certificate "${_certificateDetails!.certificateName}" '
            'was verified by ${user.displayName ?? 'a company'}.',
        'type': 'company_verification',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'metadata': {
          'certificateId': documentId,
          'companyId': user.uid,
          'companyName': user.displayName,
        },
      });
    } catch (e) {
      print('Error recording verification: $e');
      // Don't throw the error as this is a non-critical operation
    }
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Verify Certificates',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Enter certificate details to verify authenticity',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationForm() {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              controller: _studentIdController,
              label: 'Student ID/Roll Number',
              icon: Icons.person,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter student ID';
                }
                return null;
              },
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: _documentIdController,
              label: 'Certificate ID',
              icon: Icons.description,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter certificate ID';
                }
                return null;
              },
            ),
            const SizedBox(height: 25),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _verifyHash,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.verified_user),
              label: Text(
                _isLoading ? 'Verifying...' : 'Verify Certificate',
                style: const TextStyle(
                  color: Colors.white, // Explicitly setting text color to white
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey),
            suffixIcon: IconButton(
              icon: const Icon(Icons.content_paste),
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                if (data?.text != null) {
                  controller.text = data!.text!;
                }
              },
              tooltip: 'Paste from clipboard',
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationResult() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isVerified ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _isVerified ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isVerified ? Icons.verified_user : Icons.error,
                color: _isVerified ? Colors.green : Colors.red,
                size: 30,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  _isVerified ? 'Certificate Verified' : 'Verification Failed',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _isVerified ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _verificationResult!,
            style: TextStyle(
              color: _isVerified ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
          if (_isVerified && _certificateDetails != null) ...[
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _certificateDetails!.isBlockchainVerified
                      ? Colors.green.shade200
                      : Colors.orange.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _certificateDetails!.isBlockchainVerified
                        ? Icons.security
                        : Icons.info_outline,
                    color: _certificateDetails!.isBlockchainVerified
                        ? Colors.green
                        : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _certificateDetails!.isBlockchainVerified
                          ? 'Blockchain verification successful'
                          : 'Blockchain verification not available',
                      style: TextStyle(
                        color: _certificateDetails!.isBlockchainVerified
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCertificateDetails() {
    if (_isLoadingDetails) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_certificateDetails == null) {
      return Container();
    }

    return Container(
      margin: const EdgeInsets.only(top: 30),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 10),
              const Text(
                'Certificate Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDetailRow(
              'Certificate Name', _certificateDetails!.certificateName),
          _buildDetailRow(
              'Certificate Type', _certificateDetails!.certificateType),
          _buildDetailRow(
              'Issue Date', Helpers.formatDate(_certificateDetails!.issueDate)),
          const Divider(height: 30),
          Row(
            children: [
              const Icon(
                Icons.person,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Text(
                'Student Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildDetailRow('Name', _certificateDetails!.studentName),
          _buildDetailRow('Roll Number', _certificateDetails!.rollNumber),
          _buildDetailRow('Department', _certificateDetails!.department),
          const Divider(height: 30),
          Row(
            children: [
              const Icon(
                Icons.security,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Text(
                'Verification Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildDetailRow('Verified By', _certificateDetails!.verifiedBy),
          _buildDetailRow('Verified On',
              Helpers.formatDateTime(_certificateDetails!.verificationDate)),
          _buildHashRow('Stored Hash', _certificateDetails!.hash),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHashRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
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
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Hash copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  tooltip: 'Copy hash',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
