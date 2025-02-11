import 'package:certify_secure_app/CertifySecure/Screen/company/company_dashboard.dart';
import 'package:certify_secure_app/CertifySecure/Screen/login/face_recognition_screen.dart';
import 'package:certify_secure_app/CertifySecure/Screen/student/student_dashboard.dart';
import 'package:certify_secure_app/CertifySecure/Screen/main/role_selection_screen.dart';
import 'package:certify_secure_app/CertifySecure/Screen/teacher/teacher_dashboard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LoginScreen extends StatefulWidget {
  final String selectedRole;

  const LoginScreen({
    super.key,
    required this.selectedRole,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  
Future<void> handleLogin() async {
  if (!_validateInputs()) return;

  setState(() => isLoading = true);

  try {
    UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: emailController.text.trim(),
      password: passwordController.text,
    );

    if (userCredential.user != null) {
      // Get user data from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        _showError('User data not found');
        return;
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String userRole = userData['role'] ?? '';

      // Verify if the user's role matches the selected role
      if (userRole.toLowerCase() != widget.selectedRole.toLowerCase()) {
        await FirebaseAuth.instance.signOut();
        _showError('You are not authorized to login as ${widget.selectedRole}');
        return;
      }

      // Handle role-specific login logic
      switch (widget.selectedRole.toLowerCase()) {
        case 'student':
          final bool? faceAuthResult = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FaceRecognitionScreen(
                email: emailController.text,
                password: passwordController.text,
              ),
            ),
          );

          if (faceAuthResult == true) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => StudentDashboard(
                  studentId: userData['studentId'],
                  studentName: userData['name'],
                  studentClass: userData['class'],
                  studentSection: userData['section'],
                ),
              ),
            );
          } else {
            await FirebaseAuth.instance.signOut();
            _showError('Face authentication failed');
          }
          break;

        case 'teacher':
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const TeacherDashboard(),
            ),
          );
          break;

        case 'company':
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const CompanyDashboard(),
            ),
          );
          break;

        default:
          await FirebaseAuth.instance.signOut();
          _showError('Invalid role');
      }
    }
  } on FirebaseAuthException catch (e) {
    _showError(_getErrorMessage(e.code));
  } catch (e) {
    _showError('An unexpected error occurred');
    print('Error details: $e'); // For debugging
  } finally {
    if (mounted) setState(() => isLoading = false);
  }
}

  bool _validateInputs() {
    if (emailController.text.trim().isEmpty) {
      _showError('Please enter your email');
      return false;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
        .hasMatch(emailController.text.trim())) {
      _showError('Please enter a valid email');
      return false;
    }
    if (passwordController.text.isEmpty) {
      _showError('Please enter your password');
      return false;
    }
    return true;
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      default:
        return 'Login failed. Please try again';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const RoleSelectionScreen(),
          ),
        );
        return false;
      },
      child: Scaffold(
        body: SizedBox.expand(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade900,
                  Colors.blue.shade800,
                  Colors.blue.shade500,
                ],
              ),
            ),
            child: SafeArea(
              bottom: false, // Add this to extend below safe area
              child: Stack(
                children: [
                  // Decorative elements
                  Positioned(
                    top: -50,
                    right: -50,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -100,
                    left: -100,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),

                  // Main content
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25),
                        child: Column(
                          children: [
                            SizedBox(height: height * 0.05),

                            // Back Button
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_ios,
                                    color: Colors.white),
                                onPressed: () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const RoleSelectionScreen(),
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: height * 0.02),

                            // App Logo
                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.5),
                                    spreadRadius: 5,
                                    blurRadius: 20,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/login.jpg',
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),

                            SizedBox(height: height * 0.03),

                            // Welcome Text
                            Text(
                              "Welcome Back!",
                              style: TextStyle(
                                fontSize: 35,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(2, 2),
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 8),

                            Text(
                              "Login as ${widget.selectedRole.capitalize()}",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white.withOpacity(0.9),
                                letterSpacing: 0.5,
                              ),
                            ),

                            SizedBox(height: height * 0.05),

                            // Login Card
                            Container(
                              padding: const EdgeInsets.all(25),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    spreadRadius: 5,
                                    blurRadius: 15,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Email",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  CustomTextField(
                                    controller: emailController,
                                    hintText: "Enter your email",
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    "Password",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  CustomTextField(
                                    controller: passwordController,
                                    hintText: "Enter your password",
                                    icon: Icons.lock_outline,
                                    isPassword: true,
                                  ),
                                  const SizedBox(height: 25),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 55,
                                    child: ElevatedButton(
                                      onPressed: isLoading ? null : handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.shade800,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                        ),
                                        elevation: 8,
                                        shadowColor:
                                            Colors.blue.withOpacity(0.5),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (!isLoading)
                                            const Icon(
                                              Icons.login,
                                              size: 22,
                                              color: Colors.white,
                                            ),
                                          const SizedBox(width: 10),
                                          Text(
                                            isLoading
                                                ? "Please wait..."
                                                : "Login",
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: height * 0.04),

                            // Footer
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.security,
                                    color: Colors.white.withOpacity(0.9),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Secure • Reliable • Trusted",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Add extra padding at bottom
                            SizedBox(height: height * 0.05),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Loading Overlay
                  if (isLoading)
                    Container(
                      color: Colors.black.withOpacity(0.6),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                spreadRadius: 5,
                                blurRadius: 15,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 20),
                              const Text(
                                "Logging in...",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "Please wait",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool isPassword;
  final TextInputType keyboardType;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        obscureText: widget.isPassword ? _obscureText : false,
        keyboardType: widget.keyboardType,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(color: Colors.grey.shade500),
          prefixIcon: Icon(widget.icon, color: Colors.grey.shade600),
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
