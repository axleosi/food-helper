import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/components/drawer.dart';
import 'package:frontend/screens/home_screen.dart';
import 'package:frontend/services/auth_services.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final TextEditingController _roomController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage; // 👈 new field for UI errors

  @override
  void initState() {
    super.initState();

    // Redirect if not logged in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_authService.isLoggedIn) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  /// Generate a random alphanumeric room code (6 chars)
  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(
      6,
      (index) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  Future<String> _generateUniqueRoomCode() async {
    const int maxAttempts = 10;
    for (int i = 0; i < maxAttempts; i++) {
      final code = _generateRoomCode();
      final q = await _firestore
          .collection('rooms')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
      if (q.docs.isEmpty) return code;
    }
    throw Exception('Could not generate a unique room code.');
  }

  Future<void> createRoom() async {
    if (!_authService.isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final roomName = _roomController.text.trim();
    if (roomName.isEmpty) {
      setState(() => _errorMessage = "Room name cannot be empty");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _authService.getCurrentUser();
      if (user == null) throw Exception('User not logged in');

      final roomId = _firestore.collection('rooms').doc().id;
      final roomCode = await _generateUniqueRoomCode();

      await _firestore.collection('rooms').doc(roomId).set({
        'name': roomName,
        'code': roomCode,
        'createdBy': user.uid,
        'members': [user.uid],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Room Created'),
            content: Text('Share this code: $roomCode'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SimpleRoomScreen(roomId: roomId),
                    ),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = "Error creating room: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> joinRoom() async {
    if (!_authService.isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final rawInput = _roomController.text.trim();
    if (rawInput.isEmpty) {
      setState(() => _errorMessage = "Please enter a code to join");
      return;
    }

    final inputCode = rawInput.toUpperCase();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final query = await _firestore
          .collection('rooms')
          .where('code', isEqualTo: inputCode)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      if (query.docs.isEmpty) {
        setState(() => _errorMessage = "Room not found");
        return;
      }

      final roomDoc = query.docs.first;
      final user = _authService.getCurrentUser();
      if (user == null) {
        setState(() => _errorMessage = "User not logged in");
        return;
      }

      await roomDoc.reference.update({
        'members': FieldValue.arrayUnion([user.uid]),
      });

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SimpleRoomScreen(roomId: roomDoc.id)),
      );
    } on TimeoutException {
      setState(() => _errorMessage = "Firestore request timed out");
    } catch (e) {
      setState(() => _errorMessage = "Error joining room: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Stream of rooms the current user is a member of
  Stream<QuerySnapshot> _myRoomsStream(String userId) {
    return _firestore
        .collection('rooms')
        .where('members', arrayContains: userId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.getCurrentUser();
    final currentUserId = currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Your Rooms'),
        backgroundColor: Colors.deepOrange,
        elevation: 0,
      ),
      drawer: AppDrawer(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepOrange),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section: Join or Create Room
                  const Text(
                    "Join or Create a Room",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "Enter Room Name to create a room or a Code to join",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _roomController,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: "Enter Room name or code",
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                        prefixIcon: Icon(
                          Icons.meeting_room,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ),
                  ),

                  // 👇 Error message under the input
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: createRoom,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
                    ),
                    child: const Text(
                      "Create Room",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),

                  ElevatedButton(
                    onPressed: joinRoom,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.deepOrange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.deepOrange),
                      ),
                      elevation: 3,
                    ),
                    child: const Text(
                      "Join Room",
                      style: TextStyle(fontSize: 18),
                    ),
                  ),

                  // 👉 Only show this section if user has at least one room
                  currentUserId == null
                      ? const Center(child: Text("Not logged in"))
                      : StreamBuilder<QuerySnapshot>(
                          stream: _myRoomsStream(currentUserId),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.deepOrange,
                                ),
                              );
                            }

                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              // no rooms → render nothing
                              return const SizedBox.shrink();
                            }

                            final rooms = snapshot.data!.docs;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 30),
                                const Text(
                                  "Your Rooms",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                Column(
                                  children: rooms.map((room) {
                                    final data =
                                        room.data() as Map<String, dynamic>;
                                    final roomName =
                                        data['name'] ?? "Unnamed Room";
                                    final roomCode = data['code'] ?? "No Code";

                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: ListTile(
                                        title: Text(roomName),
                                        subtitle: Text("Code: $roomCode"),
                                        trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                        ),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => SimpleRoomScreen(
                                                roomId: room.id,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }
}
