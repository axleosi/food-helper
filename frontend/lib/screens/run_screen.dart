import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/components/drawer.dart';
import 'package:frontend/services/auth_services.dart';

class RunScreen extends StatefulWidget {
  final String runId;
  final String roomId;

  const RunScreen({super.key, required this.runId, required this.roomId});

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final TextEditingController _orderController = TextEditingController();

  bool _isSubmitting = false;
  String? _startedByUid;
  String? _place;
  String? _creatorName;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_authService.isLoggedIn) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });

    _loadRunDetails();
  }

  Future<void> _loadRunDetails() async {
    final runDoc = await _firestore.collection('runs').doc(widget.runId).get();
    final startedBy = runDoc['startedBy'];
    final place = runDoc['place'];

    // fetch creator name
    final userDoc = await _firestore.collection('users').doc(startedBy).get();
    final creatorName = userDoc.exists
        ? userDoc['fullName'] ?? "Someone"
        : "Someone";

    setState(() {
      _startedByUid = startedBy;
      _place = place;
      _creatorName = creatorName;
    });
  }

  Stream<QuerySnapshot> getOrders() {
    return _firestore
        .collection('orders')
        .where('runId', isEqualTo: widget.runId)
        .snapshots();
  }

  Future<void> addOrder() async {
    final user = _authService.getCurrentUser();
    if (user == null || _orderController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    String orderId = _firestore.collection('orders').doc().id;

    await _firestore.collection('orders').doc(orderId).set({
      'runId': widget.runId,
      'userId': user.uid,
      'request': _orderController.text.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    _orderController.clear();
    setState(() => _isSubmitting = false);
  }

  Future<void> markAsGotIt(String orderId) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': 'got_it',
    });
  }

  Future<void> completeRun() async {
    await _firestore.collection('runs').doc(widget.runId).update({
      'isActive': false,
    });
    Navigator.pop(context);
  }

  String _capitalize(String input) {
    if (input.isEmpty) return input;
    return input
        .split(" ")
        .map(
          (word) => word.isNotEmpty
              ? "${word[0].toUpperCase()}${word.substring(1)}"
              : "",
        )
        .join(" ");
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.getCurrentUser();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Food Run"),
        backgroundColor: Colors.deepOrange,
        actions: [
          if (user?.uid == _startedByUid)
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: completeRun,
              tooltip: "Complete Run",
            )
          else
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
              tooltip: "Back",
            ),
        ],
      ),

      drawer: AppDrawer(),
      body: Column(
        children: [
          // 👇 Modern banner with creator + place info
          if (_place != null && _place!.isNotEmpty && _creatorName != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Colors.deepOrange.shade50,
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.food_bank,
                        color: Colors.deepOrange,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          user?.uid == _startedByUid
                              ? "${_capitalize(_creatorName!)} is getting food from ${_capitalize(_place!)}"
                              : "${_capitalize(_creatorName!)} is getting food from ${_capitalize(_place!)} — place your orders!",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getOrders(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.deepOrange),
                  );
                }

                if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      user?.uid == _startedByUid
                          ? "No orders yet."
                          : "No orders yet. Add yours below!",
                      style: const TextStyle(fontSize: 16),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final isMine = data['userId'] == user?.uid;
                    final request = data['request'] ?? "";
                    final status = data['status'] ?? "pending";

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: FutureBuilder<DocumentSnapshot>(
                        future: _firestore
                            .collection('users')
                            .doc(data['userId'])
                            .get(),
                        builder: (context, userSnapshot) {
                          String orderBy = "Someone";
                          if (userSnapshot.hasData &&
                              userSnapshot.data!.exists) {
                            final userData =
                                userSnapshot.data!.data()
                                    as Map<String, dynamic>;
                            orderBy = _capitalize(
                              userData['fullName'] ?? "Someone",
                            );
                          }

                          return ListTile(
                            title: Text(request),
                            subtitle: Text(
                              isMine
                                  ? "Your order"
                                  : "Ordered by: $orderBy\nStatus: $status",
                            ),
                            trailing: status == "pending" && !isMine
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.check_circle,
                                      color: Colors.deepOrange,
                                    ),
                                    onPressed: () => markAsGotIt(doc.id),
                                  )
                                : status == "got_it"
                                ? const Icon(Icons.done, color: Colors.green)
                                : null,
                            isThreeLine: true,
                          );
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          // Order input (only if not the creator)
          if (user?.uid != _startedByUid)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _orderController,
                      decoration: InputDecoration(
                        hintText: "Enter your order",
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _isSubmitting
                      ? const CircularProgressIndicator(
                          color: Colors.deepOrange,
                        )
                      : ElevatedButton(
                          onPressed: addOrder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("Add"),
                        ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "You started this run! No need to add an order.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
