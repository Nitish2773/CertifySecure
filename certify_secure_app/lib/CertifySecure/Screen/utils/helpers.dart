// lib/utils/helpers.dart

import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';

class Helpers {
  // UI Helpers
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      duration: duration,
      action: action,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      elevation: 6,
      margin: const EdgeInsets.all(10),
    );

    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  static Future<void> showLoadingDialog(
    BuildContext context, {
    String message = 'Loading...',
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 15),
                Text(message),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                cancelText,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDestructive ? Colors.red : Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  // Date Formatting Helpers
  static String formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('MMM d, yyyy h:mm a').format(date);
  }

  static String formatTimestamp(Timestamp timestamp) {
    return formatDateTime(timestamp.toDate());
  }

  static String getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  // File Handling Helpers
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  static String getFileExtension(String fileName) {
    return path.extension(fileName).toLowerCase();
  }

  static String getMimeType(String filePath) {
    final mimeType = lookupMimeType(filePath);
    return mimeType ?? 'application/octet-stream';
  }

  static bool isValidFileType(String filePath, List<String> allowedExtensions) {
    final extension = getFileExtension(filePath);
    return allowedExtensions.contains(extension.toLowerCase());
  }

  static bool isValidFileSize(int fileSize, {int maxSizeMB = 5}) {
    return fileSize <= maxSizeMB * 1024 * 1024;
  }

  // File Hash Helpers
  static Future<String> generateFileHash(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist');
      }

      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      throw Exception('Error generating file hash: $e');
    }
  }

  static Future<String> generateFileHashInChunks(
    String filePath, {
    int chunkSize = 1024 * 1024, // 1MB chunks
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist');
      }

      const hash = sha256;
      final sink = ByteConversionSink.withCallback((bytes) {});
      final input = hash.startChunkedConversion(sink as Sink<Digest>);

      final stream = file.openRead();
      await for (var chunk in stream) {
        input.add(chunk);
      }

      input.close();
      final digest = sha256.convert(await file.readAsBytes());
      return digest.toString();
    } catch (e) {
      throw Exception('Error generating file hash in chunks: $e');
    }
  }

  static Future<bool> verifyFileHash(String filePath, String expectedHash) async {
    try {
      final actualHash = await generateFileHash(filePath);
      return actualHash.toLowerCase() == expectedHash.toLowerCase();
    } catch (e) {
      throw Exception('Error verifying file hash: $e');
    }
  }

  // String Manipulation Helpers
  static String truncateString(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  static String shortenHash(String hash, {int length = 8}) {
    if (hash.length <= length * 2) return hash;
    return '${hash.substring(0, length)}...${hash.substring(hash.length - length)}';
  }

  static String capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  // Validation Helpers
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  static bool isValidPhone(String phone) {
    return RegExp(r'^\+?[\d\s-]{10,}$').hasMatch(phone);
  }

  static bool isValidPassword(String password) {
    // At least 8 characters, 1 uppercase, 1 lowercase, 1 number
    return RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d]{8,}$')
        .hasMatch(password);
  }

  // Random Generation Helpers
  static String generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  static String generateUniqueId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        generateRandomString(8);
  }

  // Color Helpers
  static Color getContrastingTextColor(Color backgroundColor) {
    return ThemeData.estimateBrightnessForColor(backgroundColor) ==
            Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  static Color darken(Color color, [double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  static Color lighten(Color color, [double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }

  // Additional File Helpers
  static Future<bool> checkFileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  static Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      return await file.length();
    } catch (e) {
      throw Exception('Error getting file size: $e');
    }
  }

  // Additional String Helpers
  static String removeSpecialCharacters(String text) {
    return text.replaceAll(RegExp(r'[^\w\s]+'), '');
  }

  static String normalizeFileName(String fileName) {
    // Remove special characters and spaces
    String normalized = fileName.replaceAll(RegExp(r'[^\w\s\.]'), '');
    // Replace spaces with underscores
    normalized = normalized.replaceAll(' ', '_');
    return normalized.toLowerCase();
  }

  // Additional Validation Helpers
  static bool isValidUrl(String url) {
    return Uri.tryParse(url)?.hasAbsolutePath ?? false;
  }

  static bool isValidDate(String date) {
    try {
      DateTime.parse(date);
      return true;
    } catch (e) {
      return false;
    }
  }
}