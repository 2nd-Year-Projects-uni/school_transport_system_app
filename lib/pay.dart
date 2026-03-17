import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'billing_history_screen.dart';

void main() {
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: HomeScreen()));
}

// ---------------- Home Screen ----------------
class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TextEditingController feeController = TextEditingController();
  String selectedMonth = "March";
  String greeting = "";
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _updateGreeting();
    timer = Timer.periodic(Duration(minutes: 1), (_) => _updateGreeting());
  }

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    String newGreeting;

    if (hour >= 5 && hour < 12) {
      newGreeting = "Good Morning";
    } else if (hour >= 12 && hour < 17) {
      newGreeting = "Good Afternoon";
    } else if (hour >= 17 && hour < 21) {
      newGreeting = "Good Evening";
    } else {
      newGreeting = "Good Night";
    }

    if (newGreeting != greeting) {
      setState(() {
        greeting = newGreeting;
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  bool validateFee() {
    if (feeController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Please enter a fee amount.")));
      return false;
    }
    final fee = double.tryParse(feeController.text);
    if (fee == null || fee <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a valid positive amount.")),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header (student name and service removed)
            Container(
              height: 140,
              width: double.infinity,
              padding: EdgeInsets.only(top: 0, left: 20, right: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xff3A7BFF), Color(0xff2B4CDB)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.notifications, color: Colors.white),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text(
                    "$greeting!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Welcome back",
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            // Fee Input Section
            Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Enter Transport Fee",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 15),
                  TextField(
                    controller: feeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: "Rs ",
                      hintText: "Enter amount",
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  DropdownButtonFormField(
                    value: selectedMonth,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items:
                        [
                          "January",
                          "February",
                          "March",
                          "April",
                          "May",
                          "June",
                          "July",
                          "August",
                          "September",
                          "October",
                          "November",
                          "December",
                        ].map((month) {
                          return DropdownMenuItem(
                            value: month,
                            child: Text(month),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedMonth = value!;
                      });
                    },
                  ),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Color(0xff2B4CDB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (validateFee()) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaymentOptionsScreen(
                                fee: feeController.text,
                                month: selectedMonth,
                              ),
                            ),
                          );
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payment),
                          SizedBox(width: 10),
                          Text(
                            "Pay Transport Fee",
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.history, color: Color(0xff2B4CDB)),
                      label: Text(
                        "View Billing History",
                        style: TextStyle(color: Color(0xff2B4CDB)),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Color(0xff2B4CDB), width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BillingHistoryScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
//pay 2 options

// ------------------ Payment Options Screen ----------------
class PaymentOptionsScreen extends StatefulWidget {
  final String fee;
  final String month;

  PaymentOptionsScreen({required this.fee, required this.month});

  @override
  State<PaymentOptionsScreen> createState() => _PaymentOptionsScreenState();
}

class _PaymentOptionsScreenState extends State<PaymentOptionsScreen> {
  String? selectedOption;

  List<Map<String, dynamic>> paymentOptions = [
    //paypal
    {
      "icon": Icons.payment,
      "title": "PayPal",
      "subtitle": "Secure online payment",
    },

    {
      "icon": Icons.upload_file,
      "title": "Deposit Slip",
      "subtitle": "Upload your bank slip",
    },
    {
      "icon": Icons.directions_bus,
      "title": "Driver Collection",
      "subtitle": "Pay cash directly to the driver",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Select Payment Method"),
        backgroundColor: Color(0xff2B4CDB),
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: paymentOptions.length,
                itemBuilder: (context, index) {
                  var option = paymentOptions[index];
                  bool isSelected = selectedOption == option['title'];

                  return Container(
                    margin: EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.shade50 : Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      onTap: () {
                        setState(() {
                          selectedOption = option['title'];
                        });
                      },
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade700,
                        child: Icon(option['icon'], color: Colors.white),
                      ),
                      title: Text(
                        option['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(option['subtitle']),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: Colors.blue)
                          : null,
                    ),
                  );
                },
              ),
            ),
            if (selectedOption != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Color(0xff2B4CDB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () {
                    if (selectedOption == "Deposit Slip") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DepositSlipUploadScreen(
                            fee: widget.fee,
                            month: widget.month,
                          ),
                        ),
                      );
                    } else if (selectedOption == "Driver Collection") {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Driver Collection selected for Rs ${widget.fee} (${widget.month})",
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(
                    "Proceed with $selectedOption",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

//deposite slip option file

// ---------------- Deposit Slip Upload Screen ----------------
class DepositSlipUploadScreen extends StatefulWidget {
  final String fee;
  final String month;

  DepositSlipUploadScreen({required this.fee, required this.month});

  @override
  State<DepositSlipUploadScreen> createState() =>
      _DepositSlipUploadScreenState();
}

class _DepositSlipUploadScreenState extends State<DepositSlipUploadScreen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();

  Future<void> pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  void showUploadOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text("Camera"),
              onTap: () {
                Navigator.pop(context);
                pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text("Gallery"),
              onTap: () {
                Navigator.pop(context);
                pickImage(ImageSource.gallery);
              },
            ),
          ],
        );
      },
    );
  }

  void removeImage() {
    setState(() {
      _image = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Upload Deposit Slip"),
        backgroundColor: Color(0xff2B4CDB),
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Bank Name", style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              "Bank of Ceylon",
              style: TextStyle(color: Colors.grey.shade700),
            ),
            SizedBox(height: 15),
            Text(
              "Reference Number",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "BOC${DateTime.now().millisecondsSinceEpoch}",
              style: TextStyle(color: Colors.grey.shade700),
            ),
            SizedBox(height: 15),
            Text(
              "Transfer Amount",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "Rs ${widget.fee}",
              style: TextStyle(color: Colors.grey.shade700),
            ),
            SizedBox(height: 20),
            GestureDetector(
              onTap: showUploadOptions,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: _image == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_file, color: Colors.blue, size: 40),
                          SizedBox(height: 10),
                          Text("Tap to upload deposit slip"),
                          Text(
                            "Choose Camera or Gallery",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      )
                    : Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(
                              _image!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 5,
                            right: 5,
                            child: GestureDetector(
                              onTap: removeImage,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 5,
                            right: 5,
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Note: Please upload a clear deposit slip before submitting.",
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _image != null
                      ? Color(0xff2B4CDB)
                      : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _image != null
                    ? () {
                        final time = DateTime.now().toLocal().toString();
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentStatusScreen(time: time),
                          ),
                        );
                      }
                    : null,
                child: Text("Submit Payment", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//--------------payment status screen ----------------------------------------------------------------------------------------------------
class PaymentStatusScreen extends StatefulWidget {
  final String time;

  PaymentStatusScreen({required this.time});

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  bool isApproved = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration(seconds: 5), () {
      setState(() {
        isApproved = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: Text("Payment Status"),
        backgroundColor: Color(0xff2B4CDB),
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isApproved
                    ? Colors.green.shade100
                    : Colors.orange.shade100,
              ),
              child: Icon(
                isApproved ? Icons.check_circle : Icons.hourglass_top,
                size: 60,
                color: isApproved ? Colors.green : Colors.orange,
              ),
            ),
            SizedBox(height: 20),
            Text(
              isApproved ? "Payment Confirmed" : "Payment Submitted",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              isApproved
                  ? "Your transport payment has been verified successfully."
                  : "Your payment is under review by the admin.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            SizedBox(height: 30),
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 10),
                      Expanded(child: Text("Slip Uploaded")),
                      Text(widget.time),
                    ],
                  ),
                  Divider(height: 30),
                  Row(
                    children: [
                      Icon(
                        isApproved ? Icons.check_circle : Icons.hourglass_empty,
                        color: isApproved ? Colors.green : Colors.orange,
                      ),
                      SizedBox(width: 10),
                      Expanded(child: Text("Admin Verification")),
                      Text(isApproved ? "Approved" : "Pending"),
                    ],
                  ),
                  Divider(height: 30),
                  Row(
                    children: [
                      Icon(
                        isApproved
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isApproved ? Colors.green : Colors.grey,
                      ),
                      SizedBox(width: 10),
                      Expanded(child: Text("Payment Confirmed")),
                      Text(isApproved ? "Completed" : "-"),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: isApproved
                    ? Colors.green.shade100
                    : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: isApproved ? Colors.green : Colors.orange,
                  ),
                  SizedBox(width: 10),
                  Text(
                    isApproved
                        ? "Payment Verified Successfully"
                        : "Awaiting Admin Approval",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(Icons.home),
                label: Text("Back to Home"),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Color(0xff2B4CDB), width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Billing History --------------------------------------------------------------------------------------------------------
class BillingHistoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Billing History"),
        backgroundColor: Color(0xff2B4CDB),
      ),
      body: Center(
        child: Text(
          "Billing history will be displayed here.",
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
