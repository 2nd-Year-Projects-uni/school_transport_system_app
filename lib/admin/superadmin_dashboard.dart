import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_admins_page.dart';

class SuperAdminDashboard extends StatefulWidget {
  @override
  _SuperAdminDashboardState createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  //  COLORS
  final Color navy = Color(0xFF001F3F);
  final Color blue = Color(0xFF005792);
  final Color teal = Color(0xFF00B894);
  final Color bg = Color(0xFFF6F9FC);

  //  DELETE ADMIN
  Future<void> deleteAdmin(String id) async {
    await FirebaseFirestore.instance.collection('admins').doc(id).delete();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Admin Deleted")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,

      appBar: AppBar(
        title: Text("Manage Admins", style: TextStyle(color: Colors.white)),
        backgroundColor: navy,
      ),

      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // 🔷 ADD ADMIN BUTTON
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddAdminsPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: teal,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: Text("Add Admin"),
                ),
              ],
            ),

            SizedBox(height: 20),

            // 🔷 ADMIN LIST
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('admins')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text("No admins yet"));
                  }

                  return ListView(
                    children: snapshot.data!.docs.map((doc) {
                      return Container(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        padding: EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: blue.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(doc['email'], style: TextStyle(fontSize: 16)),

                            //  DELETE BUTTON
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deleteAdmin(doc.id),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
