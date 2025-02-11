import 'dart:async';
import 'package:certify_secure_app/CertifySecure/Screen/main/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'firebase_options.dart';

// Global navigator key for use throughout the app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Crashlytics
    if (!kDebugMode) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
    }

    // Set orientation
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    
    // Initialize path provider
    await _initializePathProvider();

    // Configure system UI
    _configureSystemUI();

    runApp(const MyApp());
  }, (error, stackTrace) {
    debugPrint('Error caught by runZonedGuarded: $error');
    debugPrint('Stack trace: $stackTrace');
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
    }
  });
}

Future<void> _initializePathProvider() async {
  try {
    final tempDir = await getTemporaryDirectory();
    debugPrint('Temporary directory initialized at: ${tempDir.path}');
  } catch (e) {
    debugPrint('Error initializing path_provider: $e');
    rethrow;
  }
}

void _configureSystemUI() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _isOnline = true;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeConnectivity();
    _initializeApp();
  }

  Future<void> _initializeConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _updateConnectionStatus(result);
      
      _connectivitySubscription = Connectivity()
          .onConnectivityChanged
          .listen(_updateConnectionStatus);
    } catch (e) {
      debugPrint('Error initializing connectivity: $e');
    }
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    setState(() {
      _isOnline = result != ConnectivityResult.none;
    });

    if (!_isOnline) {
      _showOfflineSnackBar();
    }
  }

  void _showOfflineSnackBar() {
    if (navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        const SnackBar(
          content: Text('You are offline'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _initializeApp() async {
    try {
      // Add any additional initialization logic here
      debugPrint('App initialized successfully');
    } catch (e) {
      debugPrint('Error in app initialization: $e');
      ErrorHandler.handleError(e, StackTrace.current);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'CertifySecure',
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      onGenerateRoute: RouteGenerator.generateRoute,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
          child: Stack(
            children: [
              child ?? const SizedBox.shrink(),
              if (!_isOnline)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Material(
                    child: SafeArea(
                      child: ColoredBox(
                        color: Colors.red,
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            'No Internet Connection',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      primaryColor: Colors.white,
      primarySwatch: Colors.blue,
      appBarTheme: const AppBarTheme(
        color: Colors.blueAccent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.blueAccent,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey[300],
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSwatch(
        primarySwatch: Colors.blue,
      ).copyWith(
        secondary: Colors.blueAccent,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 16),
        bodyMedium: TextStyle(fontSize: 14),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blueAccent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData.dark().copyWith(
      primaryColor: Colors.black,
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: const AppBarTheme(
        color: Colors.black,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardTheme(
        color: Colors.grey[900],
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _initializeConnectivity();
    }
  }
}

class ErrorHandler {
  static void handleError(Object error, StackTrace stackTrace) {
    debugPrint('Error: $error');
    debugPrint('Stack trace: $stackTrace');
    
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
    }
  }
}

class RouteGenerator {
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    // Add your route cases here
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}