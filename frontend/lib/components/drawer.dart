import 'package:flutter/material.dart';
import 'package:frontend/screens/login.dart';
import 'package:frontend/services/auth_services.dart';

class AppDrawer extends StatelessWidget {
  final AuthService _authService = AuthService();

  AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = _authService.getCurrentUser();

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: const Text(""),
            accountEmail: Text(user?.email ?? ""),
            decoration: const BoxDecoration(color: Colors.deepOrange),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Colors.deepOrange),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text("Home"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/room');
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Logout"),
            onTap: () async {
              Navigator.pop(context);
              await _authService.logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
