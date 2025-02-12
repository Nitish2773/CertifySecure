// lib/screens/company/company_settings_screen.dart

import 'package:certify_secure_app/CertifySecure/Screen/company/company_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/constants.dart';
import 'package:certify_secure_app/CertifySecure/Widgets/loading_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CompanySettingsScreen extends StatefulWidget {
  final CompanyData companyData;
  final Function(Map<String, dynamic>) onSettingsUpdated;

  const CompanySettingsScreen({
    super.key,
    required this.companyData,
    required this.onSettingsUpdated,
  });

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  // Notification Settings
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _verificationAlerts = true;
  bool _systemUpdates = true;

  // Privacy Settings
  bool _showCompanyProfile = true;
  bool _showVerificationHistory = true;
  bool _allowContactInfo = true;

  // Display Settings
  String _theme = 'system';
  String _language = 'en';
  bool _compactMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      // Load settings from Firestore
      final doc = await _firestore
          .collection('company_settings')
          .doc(_auth.currentUser?.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          // Notification Settings
          _emailNotifications = data['emailNotifications'] ?? true;
          _pushNotifications = data['pushNotifications'] ?? true;
          _verificationAlerts = data['verificationAlerts'] ?? true;
          _systemUpdates = data['systemUpdates'] ?? true;

          // Privacy Settings
          _showCompanyProfile = data['showCompanyProfile'] ?? true;
          _showVerificationHistory = data['showVerificationHistory'] ?? true;
          _allowContactInfo = data['allowContactInfo'] ?? true;

          // Display Settings
          _theme = data['theme'] ?? 'system';
          _language = data['language'] ?? 'en';
          _compactMode = data['compactMode'] ?? false;
        });
      }

      // Load local preferences
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _theme = prefs.getString('theme') ?? _theme;
        _language = prefs.getString('language') ?? _language;
      });
    } catch (e) {
      _showErrorSnackbar('Error loading settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = {
        // Notification Settings
        'emailNotifications': _emailNotifications,
        'pushNotifications': _pushNotifications,
        'verificationAlerts': _verificationAlerts,
        'systemUpdates': _systemUpdates,

        // Privacy Settings
        'showCompanyProfile': _showCompanyProfile,
        'showVerificationHistory': _showVerificationHistory,
        'allowContactInfo': _allowContactInfo,

        // Display Settings
        'theme': _theme,
        'language': _language,
        'compactMode': _compactMode,

        // Metadata
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      await _firestore
          .collection('company_settings')
          .doc(_auth.currentUser?.uid)
          .set(settings, SetOptions(merge: true));

      // Save local preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme', _theme);
      await prefs.setString('language', _language);

      widget.onSettingsUpdated(settings);
      _showSuccessSnackbar('Settings saved successfully');
    } catch (e) {
      _showErrorSnackbar('Error saving settings: $e');
    } finally {
      setState(() => _isLoading = false);
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
        title: const Text('Settings'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNotificationSettings(),
                  const SizedBox(height: 24),
                  _buildPrivacySettings(),
                  const SizedBox(height: 24),
                  _buildDisplaySettings(),
                  const SizedBox(height: 24),
                  _buildSecuritySettings(),
                  const SizedBox(height: 24),
                  _buildDataSettings(),
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Divider(),
      ],
    );
  }

  Widget _buildNotificationSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Notifications'),
        SwitchListTile(
          title: const Text('Email Notifications'),
          subtitle: const Text('Receive notifications via email'),
          value: _emailNotifications,
          onChanged: (value) => setState(() => _emailNotifications = value),
        ),
        SwitchListTile(
          title: const Text('Push Notifications'),
          subtitle: const Text('Receive push notifications'),
          value: _pushNotifications,
          onChanged: (value) => setState(() => _pushNotifications = value),
        ),
        SwitchListTile(
          title: const Text('Verification Alerts'),
          subtitle: const Text('Get notified about verification requests'),
          value: _verificationAlerts,
          onChanged: (value) => setState(() => _verificationAlerts = value),
        ),
        SwitchListTile(
          title: const Text('System Updates'),
          subtitle: const Text('Receive system and feature updates'),
          value: _systemUpdates,
          onChanged: (value) => setState(() => _systemUpdates = value),
        ),
      ],
    );
  }

  Widget _buildPrivacySettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Privacy'),
        SwitchListTile(
          title: const Text('Show Company Profile'),
          subtitle: const Text('Make your profile visible to others'),
          value: _showCompanyProfile,
          onChanged: (value) => setState(() => _showCompanyProfile = value),
        ),
        SwitchListTile(
          title: const Text('Show Verification History'),
          subtitle: const Text('Display your verification history'),
          value: _showVerificationHistory,
          onChanged: (value) => setState(() => _showVerificationHistory = value),
        ),
        SwitchListTile(
          title: const Text('Allow Contact Information'),
          subtitle: const Text('Show contact details to verified users'),
          value: _allowContactInfo,
          onChanged: (value) => setState(() => _allowContactInfo = value),
        ),
      ],
    );
  }

  Widget _buildDisplaySettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Display'),
        ListTile(
          title: const Text('Theme'),
          subtitle: Text(_theme.capitalize()),
          trailing: DropdownButton<String>(
            value: _theme,
            onChanged: (value) {
              if (value != null) {
                setState(() => _theme = value);
              }
            },
            items: const [
              DropdownMenuItem(value: 'system', child: Text('System')),
              DropdownMenuItem(value: 'light', child: Text('Light')),
              DropdownMenuItem(value: 'dark', child: Text('Dark')),
            ],
          ),
        ),
        ListTile(
          title: const Text('Language'),
          subtitle: Text(_language.toUpperCase()),
          trailing: DropdownButton<String>(
            value: _language,
            onChanged: (value) {
              if (value != null) {
                setState(() => _language = value);
              }
            },
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'es', child: Text('Spanish')),
              DropdownMenuItem(value: 'fr', child: Text('French')),
            ],
          ),
        ),
        SwitchListTile(
          title: const Text('Compact Mode'),
          subtitle: const Text('Use compact layout for lists'),
          value: _compactMode,
          onChanged: (value) => setState(() => _compactMode = value),
        ),
      ],
    );
  }

  Widget _buildSecuritySettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Security'),
        ListTile(
          leading: const Icon(Icons.password),
          title: const Text('Change Password'),
          onTap: _showChangePasswordDialog,
        ),
        ListTile(
          leading: const Icon(Icons.security),
          title: const Text('Two-Factor Authentication'),
          onTap: _show2FADialog,
        ),
      ],
    );
  }

  Widget _buildDataSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Data Management'),
        ListTile(
          leading: const Icon(Icons.download),
          title: const Text('Export Data'),
          onTap: _showExportDataDialog,
        ),
        ListTile(
          leading: const Icon(Icons.delete_forever),
          title: const Text('Delete Account'),
          textColor: Colors.red,
          onTap: _showDeleteAccountDialog,
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveSettings,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: AppColors.primary,
        ),
        child: const Text(
          'Save Settings',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  // Dialog methods
  Future<void> _showChangePasswordDialog() async {
    // Implement password change dialog
  }

  Future<void> _show2FADialog() async {
    // Implement 2FA setup dialog
  }

  Future<void> _showExportDataDialog() async {
    // Implement data export dialog
  }

  Future<void> _showDeleteAccountDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      // Implement account deletion
    }
  }
}

// Extension for string capitalization
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}