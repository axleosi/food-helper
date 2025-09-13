import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:frontend/screens/room_screen.dart';
import 'package:frontend/screens/login.dart';
import 'package:frontend/screens/signup.dart';
import 'package:frontend/screens/welcome.dart';
import 'firebase_options.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
      ),
      initialRoute: "/",
      routes: {
        "/": (context) => const WelcomePage(),
        "/signup": (context) => const SignupPage(),
        "/login": (context) => const LoginPage(),
        "/home": (context) => const WelcomePage(),
        "/room": (context) => const RoomScreen(),
      },
    );
  }
}
