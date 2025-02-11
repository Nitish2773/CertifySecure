import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

class FaceRecognitionScreen extends StatefulWidget {
  final String email;
  final String password;

  const FaceRecognitionScreen({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<FaceRecognitionScreen> createState() => _FaceRecognitionScreenState();
}

class _FaceRecognitionScreenState extends State<FaceRecognitionScreen>
    with SingleTickerProviderStateMixin {
  late FaceDetector faceDetector;
  CameraController? cameraController;
  late List<CameraDescription> cameras;
  bool isProcessing = false;
  String loadingMessage = "Authenticating...";
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _initializeDetector();
    _initializeCamera();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  void _initializeDetector() {
    faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        minFaceSize: 0.15,
      ),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      var status = await Permission.camera.request();
      if (!status.isGranted) {
        throw Exception('Camera permission not granted');
      }

      cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras found');
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      await _setupCamera(frontCamera);
    } catch (e) {
      _handleCameraError(e);
    }
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    try {
      if (cameraController != null) {
        await cameraController!.dispose();
      }

      cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await cameraController!.initialize();

      if (Platform.isAndroid) {
        await cameraController!
            .lockCaptureOrientation(DeviceOrientation.landscapeRight);
        await cameraController!.setFocusMode(FocusMode.auto);
        await cameraController!.setFlashMode(FlashMode.off);
      }

      if (mounted) {
        setState(() {
          isCameraInitialized = true;
        });
      }
    } catch (e) {
      _handleCameraError(e);
    }
  }

  void _handleCameraError(dynamic error) {
    print('Camera error: $error');
    if (mounted) {
      showCustomSnackBar(
        context: context,
        message: 'Camera initialization failed: ${error.toString()}',
        isError: true,
      );
    }
  }

  Future<void> switchCamera() async {
    if (cameras.length < 2) return;

    try {
      final lensDirection = cameraController?.description.lensDirection;
      final CameraDescription newCamera = lensDirection ==
              CameraLensDirection.front
          ? cameras.firstWhere(
              (camera) => camera.lensDirection == CameraLensDirection.back)
          : cameras.firstWhere(
              (camera) => camera.lensDirection == CameraLensDirection.front);

      await _setupCamera(newCamera);
    } catch (e) {
      showCustomSnackBar(
        context: context,
        message: 'Failed to switch camera: ${e.toString()}',
        isError: true,
      );
    }
  }

  void showCustomSnackBar({
    required BuildContext context,
    required String message,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> captureAndRecognize() async {
  if (cameraController == null || !cameraController!.value.isInitialized) {
    return;
  }

  setState(() {
    isProcessing = true;
    loadingMessage = "Authenticating... Please wait.";
  });

  try {
    XFile file = await cameraController!.takePicture();
    File imageFile = File(file.path);

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('https://face-recognition-app-8dhb.onrender.com/recognize'),
    );

    var multipartFile =
        await http.MultipartFile.fromPath('image', imageFile.path);
    request.files.add(multipartFile);

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);

      if (jsonResponse['success'] == true) {
        String? userId = jsonResponse['id']?.toString();
        String? userRole = jsonResponse['role']?.toString();

        if (userId != null && userRole != null) {
          if (widget.email == "nitishkamisetti123@gmail.com") {
            showCustomSnackBar(
              context: context,
              message: "Face recognized. Login successful!",
            );
            await Future.delayed(const Duration(seconds: 2)); // Added delay
            Navigator.of(context).pop(true);
          } else {
            throw Exception('Face recognition failed: User mismatch');
          }
        } else {
          throw Exception('Invalid user data received from server');
        }
      } else {
        throw Exception(jsonResponse['message'] ?? 'Face not recognized');
      }
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  } catch (e) {
    print('Error during face recognition: $e');
    showCustomSnackBar(
      context: context,
      message: 'Error: ${e.toString()}',
      isError: true,
    );
    await Future.delayed(const Duration(seconds: 2)); // Added delay
    if (mounted) { // Added mounted check
      Navigator.of(context).pop(false);
    }
  } finally {
    if (mounted) { // Added mounted check
      setState(() {
        isProcessing = false;
        loadingMessage = "";
      });
    }
  }
}

  @override
  void dispose() {
    try {
      cameraController?.dispose();
      faceDetector.close();
      _animationController.dispose();
    } catch (e) {
      print('Dispose error: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInstructionsSection(),
                      const SizedBox(height: 20),
                      _buildCameraPreview(),
                      const SizedBox(height: 20),
                      _buildAuthenticateButton(),
                      _buildStatusMessage(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Authenticate your Face ID",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            "Instructions:-",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _buildInstruction(
                "1. Biometric verification requires ",
                "access to your camera",
                ", please ",
                "Turn on Camera",
                " to proceed.",
              ),
              const SizedBox(height: 10),
              _buildInstruction(
                "2. Position yourself in front of the camera, ",
                "ensuring that your entire face is visible on the screen",
                ", and ",
                "do not move the device",
                " to ensure accurate detection.",
              ),
              const SizedBox(height: 10),
              _buildInstruction(
                "3. Ensure that the environment has ",
                "proper lighting",
                " for easy recognition",
                "",
                "",
              ),
            ],
          ),
        ),
      ],
    );
  }

Widget _buildCameraPreview() {
  if (!isCameraInitialized ||
      cameraController == null ||
      !cameraController!.value.isInitialized) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height * 0.6,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  bool isFrontCamera =
      cameraController!.description.lensDirection == CameraLensDirection.front;

  return Container(
    width: MediaQuery.of(context).size.width,
    height: MediaQuery.of(context).size.height * 0.45,
    margin: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.grey.withOpacity(0.3),
        width: 1,
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform(
            alignment: Alignment.center,
            transform: isFrontCamera ? Matrix4.rotationY(math.pi) : Matrix4.identity(),
            child: RotatedBox(
              quarterTurns: 1 - cameraController!.description.sensorOrientation ~/ 90,
              child: AspectRatio(
                aspectRatio: 1,
                child: CameraPreview(cameraController!),
              ),
            ),
          ),
          _buildCameraOverlay(),
          _buildSwitchCameraButton(),
        ],
      ),
    ),
  );
}

  Widget _buildCameraOverlay() {
    return Center(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            width: MediaQuery.of(context).size.width * 0.6,
            height: MediaQuery.of(context).size.width * 0.6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSwitchCameraButton() {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(
            Icons.flip_camera_ios_rounded,
            color: Colors.white,
          ),
          onPressed: switchCamera,
        ),
      ),
    );
  }

  Widget _buildAuthenticateButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        onPressed: !isProcessing ? captureAndRecognize : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7E57C2),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          isProcessing ? "Processing..." : "Authenticate",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusMessage() {
    if (!isProcessing) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          "Camera access granted! Please click 'Authenticate' to complete biometric verification.",
          style: TextStyle(
            color: Colors.green[600],
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildInstruction(
    String prefix,
    String highlight1,
    String middle,
    String highlight2,
    String suffix,
  ) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[800],
          height: 1.5,
        ),
        children: [
          TextSpan(text: prefix),
          TextSpan(
            text: highlight1,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          TextSpan(text: middle),
          if (highlight2.isNotEmpty)
            TextSpan(
              text: highlight2,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          if (suffix.isNotEmpty) TextSpan(text: suffix),
        ],
      ),
    );
  }
}
