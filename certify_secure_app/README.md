
---

# CertifySecure: Blockchain-Integrated Student Certificate Validation App with Flutter

## 📑 Table of Contents
1. Project Overview
2. VS Code & Android Studio Setup
3. Frontend: Flutter & Dart Configuration
4. Android & iOS Setup
5. Pubspec.yaml Dependencies
6. Major Screens & UI Implementations
7. Blockchain & SHA-256 Hashing
8. Blockchain Technologies
9. Immutable Data & Blockchain Verification
10. Firebase Backend Setup
11. CSV-based User Registration
12. Firebase Authentication & Storage
13. Complete App Workflow
14. Verification Process & Tamper-Proof Certification
15. Facial Recognition for Student Authentication
16. User Roles & Permissions
17. Project Structure Breakdown
18. Git Cloning & Usage
19. Deployment Guide
20. Screenshots & Video Demo
21. Contact Details
22. Conference Presentation Details

---

## 1. Project Overview

CertifySecure is an innovative application designed to provide a secure and tamper-proof certification system for students. By integrating blockchain technology, facial recognition, and Firebase authentication, the app ensures that certificates are securely stored, verified, and authenticated through a decentralized and immutable process.

### Key Features:
- **🔐 Blockchain-Powered Certificate Storage:** Certificate hashes are stored immutably on the Ethereum blockchain.
- **🤖 Facial Recognition for Secure Login:** A dedicated Flask-based service handles biometric authentication.
- **📱 QR Code Certificate Verification:** Quick validation through QR code scanning.
- **☁️ Secure File Storage on Firebase:** Original certificates are securely stored in the cloud.
- **🔄 Real-Time Verification for Recruiters:** Instant feedback on certificate authenticity.
- **🌐 Multi-Platform Support:** Runs on Android, iOS, Web, and Desktop.
- **📊 CSV-Based Bulk Registration:** Facilitates mass user onboarding.

---

## 2. VS Code & Android Studio Setup

### 📌 VS Code Configuration
1. **Install Plugins:**
   - Flutter & Dart
   - Solidity

2. **Settings:**
   Add the following to `settings.json` to ensure consistent formatting and quick access to Flutter dev tools:
   ```json
   {
       "editor.formatOnSave": true,
       "dart.previewFlutterUiGuides": true,
       "dart.openDevTools": "flutter"
   }
   ```

### 📌 Android Studio Configuration
1. **Install Plugins:**
   - Flutter & Dart SDKs

2. **Enable Developer Mode & USB Debugging:**
   - On a physical device, enable developer mode and USB debugging.

3. **Emulator Setup:**
   - Create an emulator via AVD Manager with appropriate API level and specs.

---

## 3. Frontend: Flutter & Dart Configuration

### 🔧 Install Flutter SDK (>=3.4.3)
- Follow the official [Flutter installation guide](https://flutter.dev/docs/get-started/install) for your operating system.

### 🔍 Run Commands:
Ensure your Flutter environment is properly set up by running:
```bash
flutter doctor
flutter pub get
flutter run
```

### Why Dart?
Dart is chosen for its:
- **Performance:** Compiles to native code for fast execution.
- **Productivity:** Hot reload feature for quick iterations.
- **Cross-Platform Support:** Single codebase for Android, iOS, Web, and Desktop.

---

## 4. Android & iOS Setup

### Android:
- **🛠️ Configure `android/app/build.gradle`:** Set up signing, version codes, and permissions.

### iOS:
- **💻 Run `pod install` in the `ios/` directory.**
- **📝 Configure Xcode with `GoogleService-Info.plist`.**
- **📱 Ensure devices/emulators are connected and properly configured.**

---

## 5. Pubspec.yaml Dependencies

### Authentication & Firebase:
- **`firebase_core`, `firebase_auth`:** Manages Firebase initialization and authentication.

### Security & Encryption:
- **`crypto`, `encrypt`, `pointycastle`:** Provides SHA-256 hashing and AES encryption functionalities.

### Blockchain Integration:
- **`web3dart`, `walletconnect_dart`:** Facilitates Ethereum blockchain interactions and wallet connections.

### Face Recognition & Camera:
- **`google_mlkit_face_detection`, `camera`:** Handles facial detection and image capture.

### Networking & File Handling:
- **`dio`, `http`, `file_picker`:** Used for API requests and file uploads.

### UI Enhancements:
- **`animate_do`, `cupertino_icons`:** Enhances animations and icon usage.

---


## 6. Major Screens & UI Implementations

### 📱 Feature Screenshots (Placeholder)
- **Login Screen:** Offers email/password login and face recognition options.
  - **Files:** `login.dart`, `face_recognition_screen.dart`
  - ![Login Screen](#) *(Placeholder for actual image)*

- **Student Dashboard:** Displays certificate statuses, upload options, and profile details.
  - **Files:** `student_dashboard.dart`, `home_screen.dart`, `profile_screen.dart`
  - ![Student Dashboard](#) *(Placeholder for actual image)*

- **QR Code Scanner:** Enables recruiters to scan a certificate's QR code for instant verification.
  - **Files:** `qr_code_scanner.dart`
  - ![QR Code Scanner](#) *(Placeholder for actual image)*

---

## 7. Blockchain & SHA-256 Hashing

### 🔒 SHA-256 Hash Generation:
Certificates are processed to generate a SHA-256 hash, creating a unique digital fingerprint.

**Example:**
```dart
class CertificateHasher {
  static Future<String> generateHash(File certificate) async {
    final bytes = await certificate.readAsBytes();
    final hash = sha256.convert(bytes);
    return hash.toString();
  }
}
```

### ⛓️ Blockchain Storage:
The generated hash is stored on the Ethereum blockchain using a smart contract.

**Solidity Example:**
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CertificateRegistry {
    struct Certificate {
        string studentId;
        string hash;
        uint256 timestamp;
    }

    mapping(string => Certificate) private certificates;

    function storeCertificateHash(string memory studentId, string memory hash) public {
        certificates[studentId] = Certificate(studentId, hash, block.timestamp);
    }

    function getCertificateHash(string memory studentId) public view returns (string memory) {
        return certificates[studentId].hash;
    }
}
```

### 📡 Blockchain Service:
The `blockchain_service.dart` file uses `web3dart` to interact with the deployed smart contract, sending transactions via Infura and signing with MetaMask.

---

## 8. Blockchain Technologies

### 🛠️ Remix IDE:
- **Purpose:** A browser-based IDE for developing, deploying, and testing smart contracts written in Solidity.
- **Usage:** Used to write and deploy the `certificate_registry.sol` smart contract.

### 🦊 MetaMask:
- **Purpose:** A browser extension and mobile app that allows users to interact with the Ethereum blockchain.
- **Usage:** Used for managing Ethereum accounts and signing transactions.

### 🌐 Sepolia Test Network:
- **Purpose:** A test network for Ethereum that allows developers to test smart contracts without using real Ether.
- **Usage:** Used for deploying and testing the smart contract in a safe environment.

### 🔗 Infura:
- **Purpose:** Provides scalable Ethereum infrastructure and APIs.
- **Usage:** Used to connect the app to the Ethereum network, enabling blockchain interactions.

### 💻 Solidity:
- **Purpose:** A programming language for writing smart contracts on Ethereum.
- **Usage:** Used to write the smart contract that stores certificate hashes.

---

## 9. Immutable Data & Blockchain Verification

### 🔒 Immutable Data:
Once a certificate hash is stored on the blockchain, it cannot be changed or deleted, ensuring data integrity.

### ✅ Verification Process:
- **Teachers verify certificates** by generating a fresh hash and comparing it with the blockchain-stored hash. A mismatch indicates tampering.
- **Recruiters scan QR codes** to retrieve the blockchain-stored hash and validate the certificate.

---

## 10. Firebase Backend Setup

### 🔥 Firestore Database:
- **Purpose:** Stores user data, certificate metadata, and verification statuses.
- **Collections:** `users`, `certificates`

### ☁️ Firebase Storage:
- **Purpose:** Secures the original certificate files.

### 🔑 Firebase Authentication:
- **Purpose:** Manages user sign-up, login, and authentication.

### 🚫 Firebase App Check:
- **Purpose:** Ensures that only verified app instances can access backend resources.

*(Include screenshots from the Firebase console for visual reference.)*

---


## 11. CSV-based User Registration

### 📄 Bulk Registration:
Users are imported in bulk using a CSV file, streamlining the onboarding process.

### 🛠️ Script:
The `import_users.js` file in the `firebase-admin-server/` directory reads the CSV, validates data, and registers users in Firebase Authentication and Firestore.

**Example CSV:**
```csv
email,uid,password,role,name,imagePath,department,branch,course,year,semester
student@example.com,UID123,pass123,student,Student Name,/path/to/image.jpg,CSE,Computer Science,BTECH,3,6
teacher@example.com,UID456,pass456,teacher,Teacher Name,,,,,,
company@example.com,UID789,pass789,company,Company HR,,,,,,
```

### Process:
1. **Read CSV File:** The script reads the CSV file containing user details.
2. **Validate Data:** Ensures all required fields are present and correctly formatted.
3. **Register Users:** Adds users to Firebase Authentication and Firestore.

---

## 12. Firebase Authentication & Storage

### 🔑 Firebase Authentication:
- **Supports:** Email/Password, Google Sign-In, and biometric login (facial recognition).
- **Security Rules:** Implemented to ensure that only authorized users can access or modify data.

### 🗄️ Firestore Database:
- **Purpose:** Stores user profiles, certificate data, and verification logs.

### ☁️ Firebase Storage:
- **Purpose:** Stores original certificate files securely.

### 🚫 Firebase App Check:
- **Purpose:** Ensures that only verified app instances can access backend resources.

*(Include placeholder images of the Firebase Authentication dashboard and Firestore collections.)*

---

## 13. Complete App Workflow

### 🤩 Student Registration & Login:
- **Process:** Students register and log in using Firebase Authentication; facial recognition is used as an additional security layer.

### 📤 Certificate Upload:
- **Process:** Students upload certificates, and a SHA-256 hash is generated from each file.

### ⛓️ Blockchain Storage:
- **Process:** The certificate hash is stored on the Ethereum blockchain via a smart contract.

### 👩‍🏫 Teacher Verification:
- **Process:** Teachers review and verify certificates; verified certificates update Firestore.

### 🏢 Company Verification:
- **Process:** Recruiters scan QR codes to retrieve the blockchain-stored hash and validate the certificate.

---

## 14. Verification Process & Tamper-Proof Certification

### 📲 QR Code Verification:
- **Process:** Recruiters scan the QR code linked to a certificate to retrieve the blockchain-stored hash.

### 🔎 Tamper-Proof Mechanism:
- **Mechanism:** The immutable nature of blockchain ensures that any alteration in the certificate changes the hash, flagging tampering.

### 👩‍🏫 Teacher’s Role:
- **Role:** Teachers verify the certificate manually before the hash is stored on-chain, ensuring authenticity.

---

## 15. Facial Recognition for Student Authentication

### 🤖 Face Recognition Service:
- **Implementation:** A separate Flask-based microservice using OpenCV.
- **Repository Link:** [Face Recognition Service Repository](#)

### 🔒 Purpose:
- **Security:** Ensures that only the genuine student can log in and upload certificates, preventing impersonation.

---

## 16. User Roles & Permissions

| Role     | Permissions                                                                 |
|----------|------------------------------------------------------------------------------|
| Student  | 📤 Upload certificates, 👁️ View own certificates, 🔄 Request verification     |
| Teacher  | ✅ Verify certificates, 📝 Approve/Reject uploads, 📊 Manage verification records |
| Company  | 🔍 Scan QR codes, ✔️ Validate certificate authenticity, 📄 Access verification history |

---


## 17. Project Structure Breakdown

Here's a detailed breakdown of the project structure for the CertifySecure app:

```
certify_secure_app/
├── .idea/                     # 🛠️ IntelliJ & Android Studio settings
├── .vscode/                   # 📝 VS Code workspace settings and recommended extensions
├── android/                   # 🤖 Android-specific configuration files
│   ├── gradle/                # 🔨 Gradle build scripts and configurations
│   ├── app/                   # 📱 Main Android application code, resources, manifests
│   ├── build.gradle           # 🛠️ Android Gradle configuration file
│   └── other Android config files
├── assets/                    # 🖼️ Static assets (images, icons, fonts)
│   └── images/                # 📷 Application images (logos, splash screens, etc.)
├── build/                     # ⚙️ Compiled build artifacts (auto-generated)
├── firebase-admin-server/     # 🔥 Firebase Admin SDK scripts for batch operations  
│   ├── node_modules/          # 📦 Node.js dependencies
│   ├── import_users.js        # 📄 CSV user import script
│   ├── package.json           # 📃 Node.js dependency definitions
│   └── package-lock.json      # 🔒 Locked dependency versions
├── ios/                       # 🍎 iOS-specific configuration files (Xcode projects, etc.)
├── lib/                       # 💻 Flutter application source code
│   ├── CertifySecure/         # 🎯 Main application folder
│   │   ├── contracts/         # 📜 Solidity smart contracts for blockchain integration
│   │   │   └── certificate_registry.sol  # 🔗 Smart contract for certificate hashing
│   │   ├── models/            # 🗄️ Data models
│   │   │   └── certificate_model.dart  # 📃 Dart model for certificate data
│   │   ├── Screen/            # 🎨 UI Screens (organized by role/function)
│   │   │   ├── common/        # 🔄 Shared UI components
│   │   │   ├── company/       # 🏢 Screens for recruiter/company users
│   │   │   ├── login/         # 🔑 Authentication screens
│   │   │   │   ├── face_recognition_screen.dart # 🤖 Face recognition login
│   │   │   │   └── login.dart # 📲 Standard login screen
│   │   │   ├── main/          # 🏠 Main entry/home screens
│   │   │   ├── student/       # 🎓 Student-specific screens
│   │   │   └── teacher/       # 👩‍🏫 Teacher-specific screens
│   │   ├── Services/          # 🔧 Backend services
│   │   │   ├── blockchain_service.dart # ⛓️ Blockchain interactions
│   │   │   └── storage_utils.dart # ☁️ Firebase Storage utility functions
│   │   ├── utils/             # 🛠️ Utility functions
│   │   └── Widgets/           # 🔷 Reusable UI components
│   └── main.dart              # 🚀 App entry point
├── test/                      # 🧪 Unit & widget tests
├── .gitignore                 # 🚫 Files/directories ignored by Git
├── analysis_options.yaml      # 🔍 Linting and code analysis rules
├── pubspec.lock               # 🔒 Locked dependency versions
├── pubspec.yaml               # 📃 Flutter dependency & asset declarations
└── README.md                  # 📖 Project documentation (this file)
```

---

## 18. Git Cloning & Usage

### 🚀 Clone the Repository:
To get started with the CertifySecure app, clone the repository and navigate to the project directory:

```bash
git clone https://github.com/your-org/certifysecure.git
cd certify_secure_app
```

### 📦 Install Dependencies:
Ensure all dependencies are installed by running:

```bash
flutter pub get
```

### ▶️ Run the App:
Launch the app on your preferred platform:

```bash
flutter run
```

---

## 19. Deployment Guide

### Flutter App Deployment:

#### 📱 Build for Android:
Generate an APK for Android devices:

```bash
flutter build apk
```

#### 🍎 Build for iOS:
Prepare the app for iOS deployment:

```bash
flutter build ios
```

#### ☁️ Deploy Web Version:
Deploy the web version using Firebase:

```bash
firebase deploy
```

### Smart Contract Deployment:

#### ⛓️ Deploy `certificate_registry.sol`:
Use Remix IDE to deploy the smart contract.

#### 📝 Update `blockchain_service.dart`:
Ensure the deployed contract address is updated in the service file.

### Backend Deployment on Render:

Create a `render.yaml` file for deployment:

```yaml
services:
  - type: web
    name: certifysecure-api
    env: python
    buildCommand: pip install -r requirements.txt
    startCommand: python main.py
```

---

## 20. Screenshots & Video Demo

### 🎥 Feature Screenshots (Placeholder)
- **Login Page:** ![Login Page](#)
- **Student Dashboard:** ![Student Dashboard](#)
- **Certificate Upload:** ![Certificate Upload](#)
- **QR Code Scanner:** ![QR Code Scanner](#)

### 📹 Video Demo:
- [Link to Demo Video](#)

---

## 21. Contact Details

For any inquiries or further information, please contact:

- **Project Lead:** [Your Name]
- **Email:** [your.email@example.com]
- **LinkedIn:** [Your LinkedIn Profile](https://www.linkedin.com/in/yourprofile)
- **GitHub:** [Your GitHub Profile](https://github.com/yourprofile)

---

## 22. Conference Presentation Details

### 🎤 Presentation Title:
"CertifySecure: Leveraging Blockchain for Tamper-Proof Student Certification"

### 🗓️ Conference:
- **Name:** [Conference Name]
- **Date:** [Conference Date]
- **Location:** [Conference Location]

### 📄 Abstract:
CertifySecure is a pioneering application that integrates blockchain technology, facial recognition, and Firebase authentication to create a secure and tamper-proof certification system for students. This presentation will explore the technical architecture, implementation challenges, and the future potential of blockchain in educational certification.

### 📈 Presentation Slides:
- [Link to Slides](#)

### 🎥 Video Recording:
- [Link to Video](#)

---
