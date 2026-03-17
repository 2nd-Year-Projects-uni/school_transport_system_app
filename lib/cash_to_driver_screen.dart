import 'package:flutter/material.dart';

class CashToDriverScreen extends StatelessWidget {
  final String fee;
  final String month;

  const CashToDriverScreen({super.key, required this.fee, required this.month});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Cash to Driver"),
        backgroundColor: Color(0xff2B4CDB),
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.directions_bus, size: 80, color: Colors.blue),
            SizedBox(height: 20),

            Text(
              "Give Cash to Driver",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 10),

            Text(
              "Amount: Rs $fee\nMonth: $month",
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 30),

            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "After giving cash, the driver will confirm your payment.",
                textAlign: TextAlign.center,
              ),
            ),

            SizedBox(height: 30),

            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Waiting for driver confirmation...")),
                );
              },
              child: Text("I Have Given Cash"),
            ),
          ],
        ),
      ),
    );
  }
}