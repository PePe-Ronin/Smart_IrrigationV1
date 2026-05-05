import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:smart_irrigation/new_device.dart';

class IrrigationDashboard extends StatelessWidget {
  const IrrigationDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Smart Irrigation",
                style: TextStyle(color: Colors.black, fontSize: 18),
              ),
              Text(
                "Dashboard",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          iconTheme: const IconThemeData(color: Colors.black),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 15),
              child: Icon(Icons.notifications_none),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              /// STATUS CARDS
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("zones")
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var zones = snapshot.data!.docs;

                  int totalZones = zones.length;

                  int activeZones = zones.where((zone) {
                    return zone["status"].toString().toLowerCase() ==
                        "connected";
                  }).length;

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      StatusCard(
                        icon: Icons.power_settings_new,
                        title: "Active Zones",
                        value: "$activeZones / $totalZones",
                      ),
                      StatusCard(
                        icon: Icons.water_drop,
                        title: "Avg Moisture",
                        value: _calculateAverageMoisture(zones),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              /// IRRIGATION ZONES
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    const Icon(Icons.grass, color: Colors.green, size: 18),
                    const SizedBox(width: 6),
                    const Text(
                      "Irrigation Zones",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    //add new zone button
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, // Green background
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            // TextEditingControllers for the form fields
                            TextEditingController titleController =
                                TextEditingController();
                            TextEditingController deviceController =
                                TextEditingController();
                            TextEditingController sizeController =
                                TextEditingController();
                            TextEditingController soilController =
                                TextEditingController();
                            TextEditingController statusController =
                                TextEditingController();

                            return AlertDialog(
                              title: const Text(
                                'Add New Zone',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              content: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: titleController,
                                      decoration: const InputDecoration(
                                        labelText: 'Title',
                                      ),
                                    ),
                                    TextField(
                                      controller: titleController,
                                      decoration: const InputDecoration(
                                        labelText: 'Title',
                                      ),
                                    ),
                                    TextField(
                                      controller: deviceController,
                                      decoration: const InputDecoration(
                                        labelText: 'Device ID (e.g. esp32_001)',
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                    TextField(
                                      controller: statusController,
                                      decoration: const InputDecoration(
                                        labelText: 'Status',
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                WifiProvisionPage(),
                                          ),
                                        );
                                      },
                                      child: Text("Connect to Device"),
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop(); // Close dialog
                                  },
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                  onPressed: () async {
                                    String title = titleController.text;
                                    String size = sizeController.text;
                                    String deviceId = deviceController.text;
                                    String soil = soilController.text;
                                    String status = statusController.text;

                                    if (title.isEmpty ||
                                        size.isEmpty ||
                                        deviceId.isEmpty ||
                                        soil.isEmpty ||
                                        status.isEmpty) {
                                      // Optional: show error if fields are empty
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Please fill all fields",
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    try {
                                      // Save to Firestore
                                      await FirebaseFirestore.instance
                                          .collection("zones")
                                          .add({
                                            "title": title,
                                            "size": size,
                                            "device_id": deviceId,
                                            "moisture":
                                                double.tryParse(soil) ??
                                                0, // convert soil to double
                                            "status": status.isNotEmpty
                                                ? status[0].toUpperCase() +
                                                      status
                                                          .substring(1)
                                                          .toLowerCase()
                                                : status,
                                            "created_at":
                                                FieldValue.serverTimestamp(), // optional timestamp
                                          });

                                      Navigator.of(
                                        context,
                                      ).pop(); // Close the dialog

                                      // Optional: show confirmation
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Zone added successfully",
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      // Handle error
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Error saving zone: $e",
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text(
                                    'Save',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 30),
                          SizedBox(width: 5),
                          Text(
                            'Add new zone',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              /// FIREBASE DATA
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("zones")
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Text("No zones available");
                    }

                    var zones = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: zones.length,
                      itemBuilder: (context, index) {
                        var zone = zones[index];
                        final docId = zone.id;

                        return Slidable(
                          key: ValueKey(docId),

                          endActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            children: [
                              SlidableAction(
                                onPressed: (context) async {
                                  await FirebaseFirestore.instance
                                      .collection("zones")
                                      .doc(docId)
                                      .delete();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Zone deleted"),
                                    ),
                                  );
                                },
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                icon: Icons.delete,
                                label: 'Delete',
                              ),
                            ],
                          ),

                          startActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            children: [
                              SlidableAction(
                                onPressed: (context) {
                                  TextEditingController titleController =
                                      TextEditingController(
                                        text: zone["title"],
                                      );
                                  TextEditingController sizeController =
                                      TextEditingController(text: zone["size"]);
                                  TextEditingController soilController =
                                      TextEditingController(
                                        text: (zone["moisture"] * 100)
                                            .toString(),
                                      );
                                  TextEditingController statusController =
                                      TextEditingController(
                                        text: zone["status"],
                                      );

                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text("Edit Zone"),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextField(
                                              controller: titleController,
                                              decoration: const InputDecoration(
                                                labelText: 'Title',
                                              ),
                                            ),
                                            TextField(
                                              controller: sizeController,
                                              decoration: const InputDecoration(
                                                labelText: 'Size',
                                              ),
                                            ),
                                            TextField(
                                              controller: soilController,
                                              decoration: const InputDecoration(
                                                labelText: 'Soil Moisture (%)',
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
                                            ),
                                            TextField(
                                              controller: statusController,
                                              decoration: const InputDecoration(
                                                labelText: 'Device Status',
                                              ),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text("Cancel"),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                            ),
                                            onPressed: () async {
                                              await FirebaseFirestore.instance
                                                  .collection("zones")
                                                  .doc(docId)
                                                  .update({
                                                    "title":
                                                        titleController.text,
                                                    "size": sizeController.text,
                                                    "moisture":
                                                        (double.tryParse(
                                                              soilController
                                                                  .text,
                                                            ) ??
                                                            0) /
                                                        100,
                                                    "status":
                                                        statusController.text,
                                                  });

                                              Navigator.pop(context);
                                            },
                                            child: const Text(
                                              "Update",
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                icon: Icons.edit,
                                label: 'Edit',
                              ),
                            ],
                          ),

                          child: ZoneCard(
                            title: zone["title"],
                            size: zone["size"],
                            moisture: (zone["moisture"] as num).toDouble(),
                            status: zone["status"],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const StatusCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.green, size: 30),
          const Spacer(),
          Text(title, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class ZoneCard extends StatelessWidget {
  final String title;
  final String size;
  final double moisture;
  final String status;

  const ZoneCard({
    super.key,
    required this.title,
    required this.size,
    required this.moisture,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(size, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: moisture,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 6),
          Text("Soil Moisture ${(moisture * 100).toInt()}%"),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black, fontSize: 14),
              children: [
                const TextSpan(text: "Device Status: "),
                TextSpan(
                  text: status,
                  style: TextStyle(
                    color: status.toLowerCase() == "connected"
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _calculateAverageMoisture(List<QueryDocumentSnapshot> zones) {
  if (zones.isEmpty) return "0%";

  double total = 0;

  for (var zone in zones) {
    total += (zone["moisture"] as num).toDouble();
  }

  double avg = total / zones.length;

  return "${(avg * 100).toInt()}%";
}

BoxDecoration cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.grey.withOpacity(0.1),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );
}
