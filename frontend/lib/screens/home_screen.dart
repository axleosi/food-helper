import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/components/drawer.dart';
import 'package:frontend/screens/run_screen.dart';
import 'package:frontend/services/auth_services.dart';

class SimpleRoomScreen extends StatefulWidget {
  final String roomId;

  const SimpleRoomScreen({super.key, required this.roomId});

  @override
  State<SimpleRoomScreen> createState() => _SimpleRoomScreenState();
}

class _SimpleRoomScreenState extends State<SimpleRoomScreen> {
  late final FirebaseFirestore _firestore;
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _firestore = FirebaseFirestore.instance;
    _authService = AuthService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_authService.isLoggedIn) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  // Capitalize first letter of each word
  String _capitalize(String input) {
    if (input.isEmpty) return input;
    return input
        .split(" ")
        .map((word) =>
            word.isNotEmpty ? "${word[0].toUpperCase()}${word.substring(1)}" : "")
        .join(" ");
  }

  Future<String> _getUserName(FirebaseFirestore firestore, String userId) async {
    try {
      final userDoc = await firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final fullName = data['fullName'] ?? "Unknown User";
        return _capitalize(fullName);
      }
    } catch (_) {}
    return "Unknown User";
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.getCurrentUser();
    final currentUserId = currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Room Info"),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: "Back",
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      drawer: AppDrawer(),
      body: FutureBuilder<DocumentSnapshot>(
        future: _firestore.collection('rooms').doc(widget.roomId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.deepOrange),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Room not found"));
          }

          final roomData = snapshot.data!.data() as Map<String, dynamic>;
          final createdBy = roomData['createdBy'] as String;
          final roomName =
              roomData['name'] != null ? _capitalize(roomData['name']) : "Unnamed Room";
          final roomCode = roomData['code'] ?? widget.roomId;
          final members = List<String>.from(roomData['members'] ?? []);

          final isCreator = currentUserId == createdBy;
          final isMember = members.contains(currentUserId);

          return FutureBuilder<String>(
            future: _getUserName(_firestore, createdBy),
            builder: (context, createdBySnapshot) {
              final createdByName = createdBySnapshot.data ?? "Loading creator…";

              return StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('runs')
                    .where('roomId', isEqualTo: widget.roomId)
                    .where('isActive', isEqualTo: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, runSnapshot) {
                  bool runActive =
                      runSnapshot.hasData && runSnapshot.data!.docs.isNotEmpty;
                  String? activeRunId;
                  String? startedBy;
                  if (runActive) {
                    final runDoc = runSnapshot.data!.docs.first;
                    final runData = runDoc.data() as Map<String, dynamic>;
                    activeRunId = runDoc.id;
                    startedBy = runData['startedBy'];
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Room name
                        Row(
                          children: [
                            Text(
                              "Room name:",
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              roomName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Room code
                        Row(
                          children: [
                            Text(
                              "Room code:",
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              roomCode,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Creator
                        Row(
                          children: [
                            Text(
                              "Created By:",
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              createdByName,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Run / Start Run Button
                        SizedBox(
                          width: double.infinity,
                          child: runActive
                              ? ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => RunScreen(
                                          roomId: widget.roomId,
                                          runId: activeRunId!,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.fastfood),
                                  label: startedBy == currentUserId
                                      ? const Text(
                                          "You started this run! View orders",
                                        )
                                      : FutureBuilder<String>(
                                          future: _getUserName(_firestore, startedBy!),
                                          builder: (context, starterNameSnapshot) {
                                            final starterName =
                                                starterNameSnapshot.data ?? "Someone";
                                            return Text(
                                              "$starterName started a run. Place your order",
                                            );
                                          },
                                        ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepOrange,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () async {
                                    final user = _authService.getCurrentUser();
                                    if (user == null) return;

                                    // 🔹 Ask for place before creating run
                                    final placeController = TextEditingController();
                                    final place = await showDialog<String>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text("Where are you going?"),
                                        content: TextField(
                                          controller: placeController,
                                          decoration: const InputDecoration(
                                            hintText: "Enter restaurant/place name",
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, null),
                                            child: const Text("Cancel"),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(
                                                context,
                                                placeController.text.trim()),
                                            child: const Text("Start"),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (place == null || place.isEmpty) return;

                                    final runId = _firestore.collection('runs').doc().id;
                                    await _firestore.collection('runs').doc(runId).set({
                                      'roomId': widget.roomId,
                                      'startedBy': user.uid,
                                      'isActive': true,
                                      'place': place, // ✅ Save place
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => RunScreen(
                                          roomId: widget.roomId,
                                          runId: runId,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.directions_run),
                                  label: const Text("Start Run"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepOrange,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 24),

                        // Delete Room Button (only creator)
                        if (isCreator) ...[
                          ElevatedButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text("Delete Room?"),
                                  content: const Text(
                                      "Are you sure you want to delete this room?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text("Cancel"),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text(
                                        "Delete",
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;

                              await _firestore.collection('rooms').doc(widget.roomId).delete();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Room deleted")),
                                );
                                Navigator.pop(context);
                              }
                            },
                            icon: const Icon(Icons.delete),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text("Delete Room"),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 24,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Members list (visible to all members)
                        const Text(
                          "Members:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        StreamBuilder<DocumentSnapshot>(
                          stream: _firestore
                              .collection('rooms')
                              .doc(widget.roomId)
                              .snapshots(),
                          builder: (context, roomSnapshot) {
                            if (!roomSnapshot.hasData || !roomSnapshot.data!.exists) {
                              return const Text("Room not found");
                            }

                            final roomData =
                                roomSnapshot.data!.data() as Map<String, dynamic>;
                            final members = List<String>.from(roomData['members'] ?? []);

                            return Column(
                              children: members.map((memberId) {
                                return FutureBuilder<String>(
                                  future: _getUserName(_firestore, memberId),
                                  builder: (context, snapshot) {
                                    final name = snapshot.data ?? "Loading...";
                                    return ListTile(
                                      title: Text(name),
                                      trailing: (isCreator && memberId != createdBy)
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.remove_circle,
                                                color: Colors.red,
                                              ),
                                              onPressed: () async {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (_) => AlertDialog(
                                                    title: const Text("Remove Member?"),
                                                    content: const Text(
                                                        "Are you sure you want to remove this member from the room?"),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(context, false),
                                                        child: const Text("Cancel"),
                                                      ),
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(context, true),
                                                        child: const Text(
                                                          "Remove",
                                                          style: TextStyle(color: Colors.red),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );

                                                if (confirm != true) return;

                                                // Remove the member
                                                await _firestore
                                                    .collection('rooms')
                                                    .doc(widget.roomId)
                                                    .update({
                                                  'members': FieldValue.arrayRemove([memberId]),
                                                });

                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text("Member removed"),
                                                    ),
                                                  );
                                                }
                                              },
                                            )
                                          : null,
                                    );
                                  },
                                );
                              }).toList(),
                            );
                          },
                        ),

                        // Leave Room button (non-creators)
                        if (!isCreator && isMember) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text("Leave Room?"),
                                  content: const Text(
                                      "Are you sure you want to leave this room?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text("Cancel"),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text(
                                        "Leave",
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;

                              await _firestore.collection('rooms').doc(widget.roomId).update({
                                'members': FieldValue.arrayRemove([currentUserId]),
                              });

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("You left the room")),
                                );
                                Navigator.pop(context);
                              }
                            },
                            icon: const Icon(Icons.exit_to_app),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text("Leave Room"),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 24,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
